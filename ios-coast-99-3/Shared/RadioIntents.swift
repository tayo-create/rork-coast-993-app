import AppIntents

/// Anything that can start/stop the live stream. The app registers its player at launch.
@MainActor
protocol RadioRemoteControllable: AnyObject {
    func play()
    func stop()
    func toggle()
}

/// Routes widget / Control Center taps to the app's player.
///
/// Audio playback intents are compiled into both the app and the widget, so iOS runs them
/// inside the app process (launching it in the background if needed), where `handler` is set.
@MainActor
enum RadioRemote {
    enum Command: Sendable { case play, stop, toggle }

    static var handler: (any RadioRemoteControllable)?

    static func perform(_ command: Command) {
        guard let handler else { return }
        switch command {
        case .play: handler.play()
        case .stop: handler.stop()
        case .toggle: handler.toggle()
        }
    }
}

/// Play/pause button on the Home Screen and Lock Screen widgets.
nonisolated struct ToggleRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Coast 99.3"
    static var description: IntentDescription { IntentDescription("Starts or stops the Coast 99.3 live stream.") }

    init() {}

    func perform() async throws -> some IntentResult {
        await RadioRemote.perform(.toggle)
        return .result()
    }
}

/// Backs the Control Center / Lock Screen / Action button toggle.
nonisolated struct SetRadioPlayingIntent: SetValueIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Listen to Coast 99.3"
    static var description: IntentDescription { IntentDescription("Turns the Coast 99.3 live stream on or off.") }

    @Parameter(title: "Playing")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        let shouldPlay = value
        await RadioRemote.perform(shouldPlay ? .play : .stop)
        return .result()
    }
}
