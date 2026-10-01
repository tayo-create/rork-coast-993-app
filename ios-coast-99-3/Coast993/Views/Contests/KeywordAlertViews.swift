import SwiftUI

/// Contests-tab card for the latest announced keyword, or an opt-in prompt when alerts are off.
struct KeywordAlertCard: View {
    @Environment(PushManager.self) private var push
    @Environment(AppRouter.self) private var router
    @State private var pulse: Bool = false

    var body: some View {
        if let keyword = push.latestKeyword, keyword.isFresh {
            Button {
                router.presentedKeyword = keyword
            } label: {
                liveKeyword(keyword)
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        } else if !push.isReceivingAlerts {
            optIn
        }
    }

    private func liveKeyword(_ keyword: KeywordAlert) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(pulse ? 1.15 : 1)
                Image(systemName: "key.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                EyebrowText(text: "Keyword just dropped")
                Text(keyword.keyword)
                    .font(CoastFont.display(30))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(keyword.contestTitle ?? "Coast Cash Keyword")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            Text("ENTER")
                .font(CoastFont.condensed(16))
                .tracking(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Capsule().fill(Theme.orangeGradient))
        }
        .coastCard(cornerRadius: 22, padding: 14)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.orange.opacity(pulse ? 0.8 : 0.3), lineWidth: 1.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var optIn: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.orange)
                .symbolEffect(.wiggle, options: .repeat(2))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.orange.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Get keyword alerts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Be first to know when a contest keyword drops.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(push.permission == .denied ? "Settings" : "Turn On") {
                if push.permission == .denied {
                    push.openSystemSettings()
                } else if push.permission == .authorized {
                    push.alertsEnabled = true
                } else {
                    Task { await push.requestPermission() }
                }
            }
            .font(CoastFont.condensed(16))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Capsule().fill(Theme.orangeGradient))
            .buttonStyle(PressableStyle())
        }
        .coastCard(cornerRadius: 20, padding: 14)
    }
}

/// Full-screen-ish sheet shown when a listener taps a keyword push or card.
struct KeywordSheet: View {
    let alert: KeywordAlert
    @Environment(\.dismiss) private var dismiss
    @State private var safariURL: URL?
    @State private var copied: Int = 0
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            EyebrowText(text: alert.contestTitle ?? "Coast Cash Keyword")
                .padding(.top, 28)

            Text("TODAY'S KEYWORD")
                .font(CoastFont.condensed(18))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)

            Text(alert.keyword)
                .font(CoastFont.display(64))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)
                .shadow(color: Theme.orange.opacity(0.6), radius: appeared ? 24 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                .textSelection(.enabled)

            if let message = alert.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text("Announced \(alert.createdDate.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = alert.keyword
                    copied += 1
                    safariURL = alert.entryURL
                } label: {
                    PrimaryCapsuleLabel(title: "COPY & ENTER NOW", systemImage: "arrow.up.right", height: 58)
                }
                .buttonStyle(PressableStyle())

                Text("We copy the keyword for you — just paste it on the entry page.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(AppBackground())
        .sensoryFeedback(.success, trigger: copied)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) { appeared = true }
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
