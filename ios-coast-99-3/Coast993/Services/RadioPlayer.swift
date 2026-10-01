import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Streams the Coast 99.3 Icecast feed, polls now-playing metadata and drives lock-screen controls.
@Observable
final class RadioPlayer {
    enum Status: Equatable {
        case idle, connecting, playing, failed
    }

    private(set) var status: Status = .idle
    private(set) var nowPlaying: Track?
    private(set) var history: [Track] = []
    private(set) var listenerCount: Int?
    private(set) var isStationOnline: Bool = true

    var isPlaying: Bool { status == .playing || status == .connecting }

    /// Called every ~15s of actual listening so rewards can track Daily Listen.
    var onListenTick: ((Double) -> Void)?

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var pollTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var hasConfiguredRemote: Bool = false

    init() {
        if let logo = UIImage(named: "CoastLogo") {
            nowPlayingArtwork = MPMediaItemArtwork(boundsSize: logo.size) { _ in logo }
        }
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
                updateNowPlayingInfo()
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

    // MARK: - Playback

    func toggle() {
        isPlaying ? stop() : play()
    }

    func play() {
        configureSessionAndRemote()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[RadioPlayer] audio session activation failed")
        }

        // Live radio: always start fresh at the live edge.
        let item = AVPlayerItem(url: StationConfig.streamURL)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player
        status = .connecting

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let control = player.timeControlStatus
            let itemFailed = player.currentItem?.status == .failed
            Task { @MainActor in
                guard let self else { return }
                if itemFailed {
                    self.status = .failed
                    self.stopListenTimer()
                } else if control == .playing {
                    self.status = .playing
                    self.startListenTimer()
                } else if control == .waitingToPlayAtSpecifiedRate, self.status != .idle {
                    self.status = .connecting
                }
                self.updateNowPlayingInfo()
            }
        }
        player.play()
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        statusObservation = nil
        player = nil
        status = .idle
        stopListenTimer()
        updateNowPlayingInfo()
    }

    private func startListenTimer() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self, self.status == .playing else { continue }
                self.onListenTick?(15)
            }
        }
    }

    private func stopListenTimer() {
        listenTask?.cancel()
        listenTask = nil
    }

    // MARK: - System integration

    private func configureSessionAndRemote() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            print("[RadioPlayer] audio session category failed")
        }
        guard !hasConfiguredRemote else { return }
        hasConfiguredRemote = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    func updateNowPlayingInfo(artworkImage: UIImage? = nil) {
        if let artworkImage {
            nowPlayingArtwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying?.title ?? "Coast 99.3",
            MPMediaItemPropertyArtist: nowPlaying?.artist ?? "Savannah's Hip Hop, R&B & Throwbacks",
            MPMediaItemPropertyAlbumTitle: "Coast 99.3 Live",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0
        ]
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
