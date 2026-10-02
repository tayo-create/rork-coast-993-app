import WidgetKit
import SwiftUI
import AppIntents

/// Coast 99.3 Live: Home Screen (small/medium) and Lock Screen (circular/rectangular/inline) widgets
/// with a play/pause button that controls the stream without opening the app.
struct Coast993Widget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RadioShared.widgetKind, provider: RadioTimelineProvider()) { entry in
            RadioWidgetView(entry: entry)
        }
        .configurationDisplayName("Coast 99.3 Live")
        .description("Play Savannah's Hip Hop, R&B & Throwbacks and see what's on air.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct RadioWidgetView: View {
    let entry: RadioEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            RectangularLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            InlineLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumHomeView(entry: entry)
                .containerBackground(for: .widget) { WidgetBridgeBackground(fade: 0.55) }
        default:
            SmallHomeView(entry: entry)
                .containerBackground(for: .widget) { WidgetBridgeBackground(fade: 0.35) }
        }
    }
}

// MARK: - Shared pieces

private extension RadioEntry {
    var displayTitle: String { title ?? "Coast 99.3" }
    var displayArtist: String { artist ?? "Savannah's Hip Hop, R&B & Throwbacks" }
    var playSymbol: String { isPlaying ? "pause.fill" : "play.fill" }
    var actionLabel: String { isPlaying ? "Pause Coast 99.3" : "Play Coast 99.3" }
}

/// The official Coast 99.3 logo, unaltered.
private struct CoastLogoImage: View {
    var body: some View {
        Image("CoastLogo")
            .resizable()
            .widgetAccentedRenderingMode(.desaturated)
            .scaledToFit()
            .accessibilityLabel("Coast 99.3")
    }
}

/// Talmadge bridge at night, darkened into the navy canvas like the in-app headers.
private struct WidgetBridgeBackground: View {
    let fade: Double

    var body: some View {
        ZStack {
            Theme.canvas
            Image("BridgeHero")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.9)
            LinearGradient(
                stops: [
                    .init(color: Theme.canvas.opacity(fade), location: 0),
                    .init(color: Theme.canvas.opacity(0.35), location: 0.45),
                    .init(color: Theme.canvas.opacity(0.95), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.orange.opacity(0.22), .clear],
                center: UnitPoint(x: 1, y: 1),
                startRadius: 4,
                endRadius: 160
            )
        }
    }
}

private struct OrangePlayButton: View {
    let entry: RadioEntry
    let size: CGFloat

    var body: some View {
        Button(intent: ToggleRadioIntent()) {
            ZStack {
                Circle()
                    .fill(Theme.orangeGradient)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: Theme.orange.opacity(0.55), radius: 8, y: 3)
                Image(systemName: entry.playSymbol)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: entry.isPlaying ? 0 : size * 0.04)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .widgetAccentable()
        .accessibilityLabel(entry.actionLabel)
    }
}

private struct LivePill: View {
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isPlaying ? Theme.red : Theme.blueSoft)
                .frame(width: 6, height: 6)
            Text(isPlaying ? "LIVE NOW" : "ON AIR")
                .font(CoastFont.condensed(11))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
}

/// Tiny LED meter echoing the logo's equalizer bars.
private struct MiniEqualizer: View {
    let isPlaying: Bool
    private let levels: [CGFloat] = [0.45, 0.85, 0.6, 1.0, 0.7]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Theme.red, Theme.orange, Theme.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 14 * (isPlaying ? level : 0.25 + CGFloat(index % 2) * 0.1))
            }
        }
        .frame(height: 14, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Home Screen

private struct SmallHomeView: View {
    let entry: RadioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoastLogoImage()
                .frame(maxWidth: .infinity, maxHeight: 74)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 3)

            Spacer(minLength: 4)

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    LivePill(isPlaying: entry.isPlaying)
                        .padding(.bottom, 2)
                    Text(entry.displayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                OrangePlayButton(entry: entry, size: 40)
            }
        }
    }
}

private struct MediumHomeView: View {
    let entry: RadioEntry

    var body: some View {
        HStack(spacing: 14) {
            CoastLogoImage()
                .frame(width: 138)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    LivePill(isPlaying: entry.isPlaying)
                    Spacer(minLength: 4)
                    MiniEqualizer(isPlaying: entry.isPlaying)
                }
                Spacer(minLength: 2)
                Text("NOW PLAYING")
                    .font(CoastFont.condensed(11))
                    .tracking(1.2)
                    .foregroundStyle(Theme.orange)
                Text(entry.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(entry.displayArtist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)

                Button(intent: ToggleRadioIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.playSymbol)
                            .font(.system(size: 12, weight: .bold))
                        Text(entry.isPlaying ? "PAUSE" : "LISTEN LIVE")
                            .font(CoastFont.condensed(14))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Capsule().fill(Theme.orangeGradient))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: Theme.orange.opacity(0.5), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .widgetAccentable()
                .accessibilityLabel(entry.actionLabel)
            }
        }
    }
}

// MARK: - Lock Screen

private struct CircularLockView: View {
    let entry: RadioEntry

    var body: some View {
        Button(intent: ToggleRadioIntent()) {
            VStack(spacing: 0) {
                Image(systemName: entry.playSymbol)
                    .font(.system(size: 20, weight: .bold))
                    .widgetAccentable()
                Text("99.3")
                    .font(CoastFont.display(13, relativeTo: .caption))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.actionLabel)
    }
}

private struct RectangularLockView: View {
    let entry: RadioEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                CoastLogoImage()
                    .frame(height: 24, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 1)
                Text(entry.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                Text(entry.displayArtist)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .opacity(0.75)
            }

            Button(intent: ToggleRadioIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                        .clipShape(Circle())
                    Image(systemName: entry.playSymbol)
                        .font(.system(size: 17, weight: .bold))
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.actionLabel)
        }
    }
}

private struct InlineLockView: View {
    let entry: RadioEntry

    var body: some View {
        if entry.isPlaying, let title = entry.title {
            Label("99.3 · \(title)", systemImage: "dot.radiowaves.left.and.right")
        } else {
            Label("Coast 99.3 Live", systemImage: "dot.radiowaves.left.and.right")
        }
    }
}

#Preview(as: .systemSmall) {
    Coast993Widget()
} timeline: {
    RadioEntry.sample
}

#Preview(as: .systemMedium) {
    Coast993Widget()
} timeline: {
    RadioEntry(date: .now, isPlaying: true, isBuffering: false, title: "Say It", artist: "Tory Lanez")
}
