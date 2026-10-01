import SwiftUI

/// Contests are launching soon; this tab teases them and offers keyword alerts.
struct ContestsView: View {
    @State private var glow: Bool = false
    @State private var safariURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CoastHeader(height: 210, logoWidth: 230, logoBottomPadding: 16)

                VStack(spacing: 18) {
                    comingSoonCard
                    KeywordAlertCard()
                    websiteRow
                }
                .padding(.horizontal, 16)
                .padding(.top, -6)
                .padding(.bottom, 28)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AppBackground())
        .refreshable { await PushManager.shared.fetchKeywords() }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    private var comingSoonCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.16))
                    .frame(width: 112, height: 112)
                    .scaleEffect(glow ? 1.1 : 0.94)
                Circle()
                    .strokeBorder(Theme.orange.opacity(glow ? 0.7 : 0.25), lineWidth: 1.5)
                    .frame(width: 132, height: 132)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Theme.orangeGradient)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 12)
            }
            .padding(.top, 6)

            EyebrowText(text: "Contests")

            Text("COMING SOON")
                .font(CoastFont.display(44))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("Cash, concert tickets and trips — Coast 99.3 contests are landing in the app soon. Keep it locked!")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .coastCard(cornerRadius: 26, padding: 20)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private var websiteRow: some View {
        Button {
            safariURL = StationConfig.websiteURL
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.blueSoft)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.blue.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Visit coast993.com")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("News, events and station updates.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .coastCard(cornerRadius: 20, padding: 14)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
