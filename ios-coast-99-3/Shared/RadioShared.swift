import Foundation
import WidgetKit

/// Snapshot of the player the app hands to its widgets and Control Center control.
nonisolated struct RadioWidgetState: Codable, Sendable {
    var isPlaying: Bool
    var isBuffering: Bool
    var title: String?
    var artist: String?
    var updatedAt: Date

    static let idle = RadioWidgetState(isPlaying: false, isBuffering: false, title: nil, artist: nil, updatedAt: .distantPast)

    func hasSameContent(as other: RadioWidgetState) -> Bool {
        isPlaying == other.isPlaying
            && isBuffering == other.isBuffering
            && title == other.title
            && artist == other.artist
    }
}

/// App Group storage shared by the app and the widget extension.
nonisolated enum RadioShared {
    static let appGroup: String = "group.app.rork.3yg97ylru9najufvpglu9"
    static let widgetKind: String = "Coast993Widget"
    static let controlKind: String = "Coast993PlayControl"
    private static let stateKey: String = "coast.radio.widgetState"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> RadioWidgetState {
        guard let data = defaults?.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(RadioWidgetState.self, from: data)
        else { return .idle }
        return state
    }

    static func save(_ state: RadioWidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: stateKey)
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        ControlCenter.shared.reloadControls(ofKind: controlKind)
    }
}
