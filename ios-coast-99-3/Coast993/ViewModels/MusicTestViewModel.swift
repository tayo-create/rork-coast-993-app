import Foundation
import AVFoundation

/// Drives the 10-song Coast Music Test: clip previews, answers, and completion.
@Observable
final class MusicTestViewModel {
    let songs: [MusicTestSong] = MusicTestCatalog.songs
    private(set) var index: Int = 0
    private(set) var answers: [Int: SongAnswer] = [:]
    private(set) var previews: [Int: ITunesTrack] = [:]
    private(set) var isClipPlaying: Bool = false
    private(set) var clipProgress: Double = 0
    private(set) var clipError: String?
    private(set) var isFinished: Bool = false
    private(set) var uploadState: UploadState = .idle

    enum UploadState: Equatable {
        case idle, sending, sent, failed
    }

    static let clipLength: Double = 15

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    /// Pauses the live stream when a clip starts.
    var onClipWillPlay: (() -> Void)?

    var current: MusicTestSong { songs[index] }
    var currentAnswer: SongAnswer { answers[current.id] ?? SongAnswer() }
    var submittedCount: Int { answers.values.filter(\.isSubmitted).count }
    var progress: Double { Double(submittedCount) / Double(songs.count) }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < songs.count - 1 }

    init() {
        answers = MusicTestService.loadAnswers()
        if submittedCount == songs.count {
            isFinished = true
        } else if let firstOpen = songs.indices.first(where: { answers[songs[$0].id]?.isSubmitted != true }) {
            index = firstOpen
        }
    }

    func artworkURL(for song: MusicTestSong) -> URL? { previews[song.id]?.largeArtworkURL }

    func loadPreviews() async {
        guard previews.isEmpty else { return }
        do {
            previews = try await StationAPI.lookupITunes(ids: songs.map(\.id))
        } catch {
            print("[MusicTest] preview lookup failed")
        }
    }

    // MARK: - Answers

    func setFeeling(_ value: SongFeeling) { update { $0.feeling = value } }
    func setFamiliarity(_ value: SongFamiliarity) { update { $0.familiarity = value } }
    func setFrequency(_ value: SongFrequency) { update { $0.frequency = value } }

    private func update(_ change: (inout SongAnswer) -> Void) {
        var answer = currentAnswer
        change(&answer)
        answers[current.id] = answer
    }

    /// Submits the current song's answers and advances. Returns true when the test is complete.
    @discardableResult
    func submit() -> Bool {
        guard currentAnswer.isComplete else { return false }
        update { $0.isSubmitted = true }
        MusicTestService.saveAnswers(answers)
        Task { await uploadAnswers() }
        if submittedCount == songs.count {
            stopClip()
            isFinished = true
            return true
        }
        if let next = songs.indices.first(where: { $0 > index && answers[songs[$0].id]?.isSubmitted != true })
            ?? songs.indices.first(where: { answers[songs[$0].id]?.isSubmitted != true }) {
            go(to: next)
        }
        return false
    }

    /// Sends all submitted answers to the station; safe to call repeatedly (server upserts).
    func uploadAnswers() async {
        uploadState = .sending
        do {
            try await MusicTestService.upload(answers, songs: songs)
            uploadState = .sent
        } catch {
            print("[MusicTest] upload failed: \(error.localizedDescription)")
            uploadState = .failed
        }
    }

    func next() { if canGoForward { go(to: index + 1) } }
    func previous() { if canGoBack { go(to: index - 1) } }

    private func go(to newIndex: Int) {
        stopClip()
        index = newIndex
    }

    func restart() {
        stopClip()
        answers = [:]
        MusicTestService.clearAnswers()
        index = 0
        isFinished = false
        uploadState = .idle
    }

    // MARK: - Clip playback

    func toggleClip() {
        isClipPlaying ? stopClip() : playClip()
    }

    private func playClip() {
        guard let raw = previews[current.id]?.previewUrl, let url = URL(string: raw) else {
            clipError = "Preview isn't available for this song."
            return
        }
        clipError = nil
        onClipWillPlay?()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[MusicTest] audio session failed")
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        clipProgress = 0
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor in
                guard let self else { return }
                self.clipProgress = min(seconds / Self.clipLength, 1)
                if seconds >= Self.clipLength { self.stopClip() }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopClip() }
        }
        player.play()
        isClipPlaying = true
    }

    func stopClip() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player?.pause()
        player = nil
        isClipPlaying = false
        clipProgress = 0
    }

    var clipElapsedLabel: String {
        let seconds = Int((clipProgress * Self.clipLength).rounded(.down))
        return "0:\(String(format: "%02d", seconds))"
    }
}
