import WidgetKit
import SwiftUI
import AppIntents

/// Control Center / Lock Screen / Action button toggle for the live stream (iOS 18+).
struct Coast993PlayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: RadioShared.controlKind, provider: RadioControlValueProvider()) { isPlaying in
            ControlWidgetToggle(
                "Coast 99.3",
                isOn: isPlaying,
                action: SetRadioPlayingIntent()
            ) { isOn in
                Label(isOn ? "Live" : "Listen Live", systemImage: isOn ? "pause.fill" : "dot.radiowaves.left.and.right")
            }
            .tint(Theme.orange)
        }
        .displayName("Coast 99.3 Live")
        .description("Start or stop the Coast 99.3 live stream.")
    }
}

nonisolated struct RadioControlValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        RadioShared.load().isPlaying
    }
}
