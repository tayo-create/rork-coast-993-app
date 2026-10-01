import SwiftUI

/// LED-segment equalizer echoing the bars in the Coast logo. Animates while live audio plays.
struct EqualizerView: View {
    let isActive: Bool
    var barCount: Int = 7
    var segments: Int = 9

    private static let restLevels: [Double] = [0.3, 0.55, 0.4, 0.7, 0.45, 0.6, 0.35, 0.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 14.0, paused: !isActive)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let gap: CGFloat = 3
                let segGap: CGFloat = 2
                let barWidth = (size.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
                let segHeight = (size.height - segGap * CGFloat(segments - 1)) / CGFloat(segments)

                for bar in 0..<barCount {
                    let p = Double(bar)
                    let level: Double
                    if isActive {
                        let wave = 0.5
                            + 0.28 * sin(time * (3.1 + p * 0.7) + p * 1.3)
                            + 0.2 * sin(time * (5.3 + p * 0.37) + p)
                        level = min(max(wave, 0.12), 1)
                    } else {
                        level = Self.restLevels[bar % Self.restLevels.count] * 0.55
                    }
                    let lit = Int((level * Double(segments)).rounded())
                    let x = CGFloat(bar) * (barWidth + gap)

                    for seg in 0..<segments {
                        let y = size.height - CGFloat(seg + 1) * segHeight - CGFloat(seg) * segGap
                        let rect = CGRect(x: x, y: y, width: barWidth, height: segHeight)
                        let color = Self.segmentColor(seg, of: segments)
                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: 1.5),
                            with: .color(seg < lit ? color : color.opacity(0.1))
                        )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static func segmentColor(_ seg: Int, of total: Int) -> Color {
        let f = Double(seg) / Double(max(total - 1, 1))
        if f < 0.5 { return Theme.blue }
        if f < 0.8 { return Theme.orange }
        return Theme.red
    }
}

/// Clip waveform with orange playback fill.
struct WaveformView: View {
    let progress: Double
    var barCount: Int = 44

    var body: some View {
        Canvas { ctx, size in
            let gap: CGFloat = 2
            let barWidth = max((size.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount), 1)
            for i in 0..<barCount {
                let seed = Double(i)
                let h = 0.25 + 0.75 * abs(sin(seed * 1.7) * cos(seed * 0.45 + 0.8))
                let barHeight = max(size.height * h, 3)
                let rect = CGRect(
                    x: CGFloat(i) * (barWidth + gap),
                    y: (size.height - barHeight) / 2,
                    width: barWidth,
                    height: barHeight
                )
                let played = Double(i) / Double(barCount) < progress
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(played ? Theme.orange : Theme.blueSoft.opacity(0.35))
                )
            }
        }
        .accessibilityHidden(true)
    }
}
