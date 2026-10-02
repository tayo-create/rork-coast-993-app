import Foundation
import AVFoundation
import MediaPlayer
import Network
import UIKit

/// Streams the Coast 99.3 Icecast feed, polls now-playing metadata and drives lock-screen controls.
///
/// Built to keep playing in the background: it recovers from dropped connections, stalls,
/// phone calls / Siri interruptions, network changes and media-server resets.
@Observable
final class RadioPlayer {
    enum Status: Equatable {
        case idle, connecting, playing, reconnecting, failed
    }

    private(set) var status: Status = .idle
    private(set) var nowPlaying: Track?
    private(set) var history: [Track] = []
    private(set) var listenerCount: Int?
    private(set) var isStationOnline: Bool = true
    private(set) var isNetworkAvailable: Bool = true

    var isPlaying: Bool { status == .playing || isBuffering }
    var isBuffering: Bool { status == .connecting || status == .reconnecting }

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeControlObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var sessionObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var stallWatchdog: Task<Void, Never>?
    @ObservationIgnored private let pathMonitor: NWPathMonitor = NWPathMonitor()
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private let logoArtwork: MPMediaItemArtwork?
    @ObservationIgnored private var nowPlayingArtwork: MPMediaItemArtwork?
    @ObservationIgnored private var hasConfiguredSystem: Bool = false

    /// The listener's intent. Stays true through drops so we keep reconnecting until they press pause.
    @ObservationIgnored private var wantsToPlay: Bool = false
    @ObservationIgnored private var wasInterrupted: Bool = false
    @ObservationIgnored private var reconnectAttempts: Int = 0

    private static let maxReconnectAttempts: Int = 10
    private static let stallTimeout: Duration = .seconds(12)

    init() {
        if let logo = UIImage(named: "CoastLogo") {
            logoArtwork = Self.makeArtwork(logo)
        } else {
            logoArtwork = nil
        }
        nowPlayingArtwork = logoArtwork
        startNetworkMonitor()
    }

    // MARK: - Metadata polling

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNowPlaying()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    func refreshNowPlaying() async {
        do {
            let response = try await StationAPI.fetchNowPlaying()
            apply(response)
        } catch {
            print("[RadioPlayer] now playing refresh failed")
        }
    }

    private func apply(_ response: AzuraNowPlayingResponse) {
        isStationOnline = response.isOnline ?? true
        listenerCount = response.listeners?.current
        if let np = response.nowPlaying, let track = Self.track(from: np.song, id: "np-\(np.shId ?? 0)", playedAt: np.playedAt) {
            if track.searchTerm != nowPlaying?.searchTerm {
                nowPlaying = track
                nowPlayingArtwork = logoArtwork
                updateNowPlayingInfo()
                loadLockScreenArtwork(for: track)
            }
        }
        let items = response.songHistory ?? []
        history = items.compactMap { Self.track(from: $0.song, id: "h-\($0.shId)", playedAt: $0.playedAt) }
    }

    /// Filters station IDs/liners ("We'll be back soon...") that have no artist.
    private static func track(from song: AzuraSong, id: String, playedAt: Int?) -> Track? {
        let artist = (song.artist ?? "").trimmingCharacters(in: .whitespaces)
        let title = (song.title ?? song.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !artist.isEmpty, !title.isEmpty else { return nil }
        return Track(
            id: id,
            title: title,
            artist: artist,
            playedAt: playedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            artworkURL: nil
        )
    }

    /// Puts the current song's album art on the Lock Screen / Control Center (falls back to the logo).
    private func loadLockScreenArtwork(for track: Track) {
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let url = try? await StationAPI.searchITunes(term: track.searchTerm)?.largeArtworkURL,
                  let result = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: result.0),
                  !Task.isCancelled,
                  let self,
                  self.nowPlaying?.searchTerm == track.searchTerm
            else { return }
            self.nowPlayingArtwork = Self.makeArtwork(image)
            self.updateNowPlayingInfo()
        }
    }

    /// Built outside the main actor: MediaPlayer calls the handler on a background queue.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    // MARK: - Playback

    func toggle() {
        isPlaying ? stop() : play()
    }

    func play() {
        configureSystemIntegration()
        wantsToPlay = true
        wasInterrupted = false
        reconnectAttempts = 0
        cancelReconnect()
        status = .connecting
        activateSession()
        startFreshStream()
    }

    func stop() {
        wantsToPlay = false
        wasInterrupted = false
        cancelReconnect()
        stallWatchdog?.cancel()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeItemObservers()
        status = .idle
        endBackgroundTask()
        updateNowPlayingInfo()
    }

    /// Called when the app returns to the foreground; resumes a stream that dropped while suspended.
    func appDidBecomeActive() {
        guard wantsToPlay, status != .playing, reconnectTask == nil else { return }
        reconnectNow()
    }

    /// Live radio: always load a new item so playback starts at the live edge, never stale buffer.
    private func startFreshStream() {
        let item = AVPlayerItem(url: StationConfig.streamURL)
        observe(item)
        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            observeTimeControl(of: newPlayer)
            player = newPlayer
        }
        player?.play()
        armStallWatchdog()
        updateNowPlayingInfo()
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[RadioPlayer] audio session activation failed")
        }
    }

    // MARK: - Player observation

    private func observeTimeControl(of player: AVPlayer) {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let control = player.timeControlStatus
            Task { @MainActor in self?.handleTimeControl(control) }
        }
    }

    private func handleTimeControl(_ control: AVPlayer.TimeControlStatus) {
        guard wantsToPlay else { return }
        switch control {
        case .playing:
            status = .playing
            reconnectAttempts = 0
            stallWatchdog?.cancel()
            endBackgroundTask()
        case .waitingToPlayAtSpecifiedRate:
            if status == .playing { status = .connecting }
            armStallWatchdog()
        case .paused:
            break
        @unknown default:
            break
        }
        updateNowPlayingInfo()
    }

    private func observe(_ item: AVPlayerItem) {
        removeItemObservers()
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            guard failed else { return }
            Task { @MainActor in self?.scheduleReconnect(reason: "item failed") }
        }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .AVPlayerItemFailedToPlayToEndTime,
            .AVPlayerItemDidPlayToEndTime,
            .AVPlayerItemPlaybackStalled
        ]
        itemObservers = names.map { name in
            center.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleItemEvent(name) }
            }
        }
    }

    private func handleItemEvent(_ name: Notification.Name) {
        guard wantsToPlay else { return }
        if name == .AVPlayerItemPlaybackStalled {
            // AVPlayer often recovers on its own; the watchdog steps in if it doesn't.
            armStallWatchdog()
        } else {
            // A live stream never "ends": the server or network dropped the connection.
            scheduleReconnect(reason: name == .AVPlayerItemDidPlayToEndTime ? "stream ended" : "stream failed")
        }
    }

    private func removeItemObservers() {
        itemStatusObservation = nil
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }
        itemObservers = []
    }

    private func armStallWatchdog() {
        stallWatchdog?.cancel()
        stallWatchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.stallTimeout)
            guard !Task.isCancelled, let self, self.wantsToPlay, self.status != .playing else { return }
            self.scheduleReconnect(reason: "stalled")
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect(reason: String) {
        guard wantsToPlay, reconnectTask == nil else { return }
        stallWatchdog?.cancel()
        guard reconnectAttempts < Self.maxReconnectAttempts else {
            giveUp()
            return
        }
        reconnectAttempts += 1
        status = .reconnecting
        beginBackgroundTaskIfNeeded()
        updateNowPlayingInfo()

        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 10)
        print("[RadioPlayer] reconnecting (\(reason)), attempt \(reconnectAttempts) in \(delay)s")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.reconnectTask = nil
            guard self.wantsToPlay else { return }
            // Offline: wait for the network monitor instead of burning attempts.
            guard self.isNetworkAvailable else { return }
            self.activateSession()
            self.startFreshStream()
        }
    }

    private func reconnectNow() {
        cancelReconnect()
        reconnectAttempts = 0
        status = .reconnecting
        beginBackgroundTaskIfNeeded()
        activateSession()
        startFreshStream()
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    private func giveUp() {
        print("[RadioPlayer] giving up after \(reconnectAttempts) attempts")
        wantsToPlay = false
        cancelReconnect()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeItemObservers()
        status = .failed
        endBackgroundTask()
        updateNowPlayingInfo()
    }

    /// Buys ~30s of runtime so a reconnect can finish even if iOS would otherwise suspend the app.
    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "coast.radio.reconnect") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Network

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "coast.radio.network"))
    }

    private func networkChanged(online: Bool) {
        let cameBack = online && !isNetworkAvailable
        isNetworkAvailable = online
        if cameBack, wantsToPlay, status != .playing {
            print("[RadioPlayer] network back, reconnecting")
            reconnectNow()
        }
        updateNowPlayingInfo()
    }

    // MARK: - System integration

    private func configureSystemIntegration() {
        configureSessionCategory()
        guard !hasConfiguredSystem else { return }
        hasConfiguredSystem = true
        configureRemoteCommands()
        observeAudioSession()
    }

    private func configureSessionCategory() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            print("[RadioPlayer] audio session category failed")
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        let interruption = center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw) }
        }

        let routeChange = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self?.handleRouteChange(reasonRaw: reasonRaw) }
        }

        let reset = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleMediaServicesReset() }
        }

        sessionObservers = [interruption, routeChange, reset]
    }

    /// Phone calls, Siri, alarms: pause, then resume at the live edge when iOS says it's okay.
    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            guard wantsToPlay else { return }
            wasInterrupted = true
            wantsToPlay = false
            cancelReconnect()
            stallWatchdog?.cancel()
            player?.pause()
            status = .idle
            updateNowPlayingInfo()
        case .ended:
            guard wasInterrupted else { return }
            wasInterrupted = false
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    /// Headphones/Bluetooth disconnected: pause instead of blasting through the speaker (Apple HIG).
    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw,
              AVAudioSession.RouteChangeReason(rawValue: reasonRaw) == .oldDeviceUnavailable,
              wantsToPlay else { return }
        stop()
    }

    /// The system audio daemon restarted: every audio object is invalid, rebuild from scratch.
    private func handleMediaServicesReset() {
        let shouldResume = wantsToPlay
        timeControlObservation = nil
        removeItemObservers()
        player = nil
        configureSessionCategory()
        if shouldResume {
            play()
        } else {
            status = .idle
            updateNowPlayingInfo()
        }
    }

    private func updateNowPlayingInfo() {
        let subtitle: String = switch status {
        case .reconnecting: isNetworkAvailable ? "Reconnecting…" : "Waiting for connection…"
        default: nowPlaying?.artist ?? "Savannah's Hip Hop, R&B & Throwbacks"
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying?.title ?? "Coast 99.3",
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyAlbumTitle: "Coast 99.3 Live",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0
        ]
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
