import SwiftUI

/// Station hub: keyword alerts, request line, socials, contests teaser and website.
struct StationView: View {
    @Environment(PushManager.self) private var push
    @State private var safariURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CoastHeader(height: 210, logoWidth: 230, logoBottomPadding: 16)

                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        SectionTitle(title: "Keyword Alerts")
                        KeywordAlertCard()
                    }

                    if let digits = StationConfig.requestLineDigits {
                        RequestLineCard(digits: digits)
                    }

                    if !StationConfig.socialLinks.isEmpty {
                        socialRow
                    }

                    VStack(spacing: 12) {
                        SectionTitle(title: "More from Coast")
                        ContestsSoonRow()
                        websiteRow
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, -6)
                .padding(.bottom, 28)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AppBackground())
        .refreshable { await push.fetchKeywords() }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    private var socialRow: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Follow Coast")
            HStack(spacing: 14) {
                ForEach(StationConfig.socialLinks) { link in
                    Button {
                        safariURL = link.url
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: link.systemImage)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 58, height: 58)
                                .background(Circle().fill(Theme.surfaceRaised))
                                .overlay(Circle().strokeBorder(Theme.blue.opacity(0.5), lineWidth: 1))
                            Text(link.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                    .accessibilityLabel("Open Coast 99.3 on \(link.name)")
                }
                Spacer(minLength: 0)
            }
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

/// Call / text the studio. Only shown when a real request line is configured.
private struct RequestLineCard: View {
    let digits: String
    @Environment(\.openURL) private var openURL
    @State private var tapCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "music.mic")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.orange.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowText(text: "Request a song")
                    Text(formatted)
                        .font(CoastFont.display(28))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 10) {
                Button {
                    open("tel:")
                } label: {
                    PrimaryCapsuleLabel(title: "CALL", systemImage: "phone.fill", height: 48)
                }
                .buttonStyle(PressableStyle())

                Button {
                    open("sms:")
                } label: {
                    HStack(spacing: 8) {
                        Text("TEXT")
                            .font(CoastFont.condensed(19))
                            .tracking(0.6)
                        Image(systemName: "message.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Theme.blue))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: Theme.blue.opacity(0.45), radius: 14, y: 6)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .coastCard(cornerRadius: 22, padding: 16)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    private var formatted: String {
        guard digits.count == 10 else { return digits }
        let chars = Array(digits)
        return "(\(String(chars[0..<3]))) \(String(chars[3..<6]))-\(String(chars[6..<10]))"
    }

    private func open(_ scheme: String) {
        guard let url = URL(string: "\(scheme)\(digits)") else { return }
        tapCount += 1
        openURL(url)
    }
}

/// Compact teaser for upcoming contests.
private struct ContestsSoonRow: View {
    @State private var glow: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.16))
                    .scaleEffect(glow ? 1.08 : 0.92)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.orangeGradient)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Contests landing soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Cash, concert tickets and trips. Turn on alerts to hear first.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("SOON")
                .font(CoastFont.condensed(14, relativeTo: .caption))
                .tracking(1)
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.orange.opacity(0.16)))
        }
        .coastCard(cornerRadius: 20, padding: 14)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

#Preview {
    StationView()
        .environment(PushManager.shared)
        .environment(AppRouter())
}
