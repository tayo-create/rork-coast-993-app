import SwiftUI

/// Deep night backdrop with soft bridge-light glows.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.canvas
            RadialGradient(
                colors: [Theme.blue.opacity(0.20), .clear],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 10,
                endRadius: 440
            )
            RadialGradient(
                colors: [Theme.orange.opacity(0.10), .clear],
                center: UnitPoint(x: 0.95, y: 1.0),
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

/// Savannah bridge at night with the official Coast 99.3 logo. Stretches on pull-down.
struct CoastHeader: View {
    var height: CGFloat = 250
    var logoWidth: CGFloat = 250
    var logoBottomPadding: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let stretch = max(geo.frame(in: .global).minY, 0)
            ZStack(alignment: .bottom) {
                Image("BridgeHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: height + stretch)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: Theme.canvas.opacity(0.65), location: 0),
                        .init(color: .clear, location: 0.28),
                        .init(color: Theme.canvas.opacity(0.15), location: 0.6),
                        .init(color: Theme.canvas, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image("CoastLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(logoWidth, geo.size.width * 0.8))
                    .shadow(color: .black.opacity(0.65), radius: 14, y: 6)
                    .padding(.bottom, logoBottomPadding)
            }
            .frame(width: geo.size.width, height: height + stretch)
            .offset(y: -stretch)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coast 99.3, Savannah's Hip Hop, R&B and Throwbacks")
            .accessibilityAddTraits(.isHeader)
        }
        .frame(height: height)
    }
}

struct CoastCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surfaceRaised.opacity(0.9), Theme.surface.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.blue.opacity(0.5), Theme.border.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }
}

extension View {
    func coastCard(cornerRadius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(CoastCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

/// Springy press feedback for every tappable surface.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Glowing orange capsule used for the primary action on each screen.
struct PrimaryCapsuleLabel: View {
    let title: String
    var systemImage: String? = "chevron.right"
    var height: CGFloat = 54
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(CoastFont.condensed(19))
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(Capsule().fill(Theme.orangeGradient))
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        .shadow(color: Theme.orange.opacity(isEnabled ? 0.45 : 0), radius: 14, y: 6)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Album art with branded placeholder; sized by the caller's frame.
struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 14

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    LinearGradient(
                        colors: [Theme.surfaceRaised, Theme.canvas],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image("CoastLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .opacity(0.9)
                }
            }
            .overlay {
                if let url {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// Uppercase orange eyebrow label.
struct EyebrowText: View {
    let text: String
    var color: Color = Theme.orange

    var body: some View {
        Text(text.uppercased())
            .font(CoastFont.condensed(15, relativeTo: .caption))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Pulsing LIVE pill.
struct LiveBadge: View {
    let isOnAir: Bool
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 12, weight: .bold))
                .symbolEffect(.variableColor.iterative, isActive: isOnAir)
            Text("LIVE")
                .font(CoastFont.condensed(15, relativeTo: .caption))
                .tracking(1)
        }
        .foregroundStyle(Theme.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.orange.opacity(0.16)))
        .overlay(Capsule().strokeBorder(Theme.orange.opacity(pulse && isOnAir ? 0.9 : 0.35), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Simple status card for loading, empty and error states.
struct StatusCard: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.orange)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    PrimaryCapsuleLabel(title: actionTitle, systemImage: "arrow.clockwise", height: 44)
                        .frame(maxWidth: 220)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .coastCard()
    }
}
