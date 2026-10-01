import SwiftUI

/// Sign up / log in with Apple or Google, then an optional keyword-alerts opt-in step.
struct AuthView: View {
    let initialMode: AppRouter.AuthMode

    @Environment(AuthManager.self) private var auth
    @Environment(RewardsStore.self) private var rewards
    @Environment(PushManager.self) private var push
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AppRouter.AuthMode = .signUp
    @State private var step: Step = .credentials
    @State private var guestPoints: Int = 0
    @State private var successTrigger: Int = 0
    @State private var appeared: Bool = false

    private enum Step {
        case credentials, alerts
    }

    var body: some View {
        @Bindable var auth = auth
        ZStack(alignment: .topTrailing) {
            AppBackground()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    Group {
                        switch step {
                        case .credentials: credentials
                        case .alerts: alertsStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .padding(.trailing, 12)
            .accessibilityLabel(step == .alerts ? "Skip" : "Close")
        }
        .sensoryFeedback(.success, trigger: successTrigger)
        .alert("Couldn't sign in", isPresented: $auth.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage)
        }
        .onAppear {
            mode = initialMode
            guestPoints = rewards.points
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
        .onChange(of: auth.user) { _, user in
            guard user != nil, step == .credentials else { return }
            successTrigger += 1
            Task { await afterSignIn() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottom) {
            Theme.canvas
                .overlay {
                    Image("BridgeHero")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipped()
            LinearGradient(
                stops: [
                    .init(color: Theme.canvas.opacity(0.6), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: Theme.canvas.opacity(0.3), location: 0.62),
                    .init(color: Theme.canvas, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Image("CoastLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 6)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 18)
                .accessibilityLabel("Coast 99.3")
        }
        .frame(height: 270)
    }

    // MARK: - Step 1: credentials

    private var credentials: some View {
        VStack(spacing: 22) {
            ModeSwitcher(mode: $mode)

            VStack(spacing: 8) {
                Text(mode == .signUp ? "Join the Coast Family" : "Welcome Back")
                    .font(CoastFont.display(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Text(mode == .signUp
                     ? "Create a free account so your points, rewards and keyword alerts follow you everywhere."
                     : "Log in to pick up your Coast Rewards right where you left off.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(.easeInOut(duration: 0.2), value: mode)

            if mode == .signUp {
                perks
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if guestPoints > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.orange)
                    Text("Your **\(guestPoints) points** on this phone will move into your account.")
                        .font(.footnote)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
                .coastCard(cornerRadius: 16, padding: 12)
            }

            VStack(spacing: 12) {
                ProviderButton(provider: .apple, mode: mode, isLoading: auth.signingInWith == .apple, isDisabled: auth.isSigningIn) {
                    Task { await auth.signIn(provider: .apple) }
                }
                ProviderButton(provider: .google, mode: mode, isLoading: auth.signingInWith == .google, isDisabled: auth.isSigningIn) {
                    Task { await auth.signIn(provider: .google) }
                }
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    mode = mode == .signUp ? .logIn : .signUp
                }
            } label: {
                Text(mode == .signUp ? "Already have an account? **Log in**" : "New to Coast Rewards? **Sign up free**")
                    .font(.subheadline)
                    .foregroundStyle(Theme.blueSoft)
                    .frame(minHeight: 44)
            }

            Text("By continuing you agree to Coast 99.3's contest rules and privacy policy. We never post on your behalf.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
    }

    private var perks: some View {
        VStack(spacing: 0) {
            PerkRow(icon: "star.circle.fill", tint: Theme.orange, title: "Points that never get lost", subtitle: "Synced to your account, on every device")
            Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 56)
            PerkRow(icon: "bell.badge.fill", tint: Theme.blue, title: "Instant keyword alerts", subtitle: "Get the Coast Cash keyword the second it drops")
            Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 56)
            PerkRow(icon: "gift.fill", tint: Theme.orange, title: "Redeem real rewards", subtitle: "$5, $10 and $25 Coast Rewards")
        }
        .coastCard(cornerRadius: 20, padding: 8)
    }

    // MARK: - Step 2: keyword alerts

    private var alertsStep: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.14))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(Theme.orange.opacity(0.35), lineWidth: 1)
                    .frame(width: 150, height: 150)
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .symbolEffect(.wiggle, options: .repeat(3))
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                if let name = auth.user?.displayName {
                    EyebrowText(text: "You're in, \(name)")
                }
                Text("Never Miss a Keyword")
                    .font(CoastFont.display(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("We'll ping you the moment a contest keyword is announced on air — so you can enter before anyone else.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KeywordPreviewCard()

            Button {
                Task {
                    await push.requestPermission()
                    dismiss()
                }
            } label: {
                PrimaryCapsuleLabel(title: "TURN ON KEYWORD ALERTS", systemImage: "bell.fill", height: 58)
            }
            .buttonStyle(PressableStyle())

            Button("Not now") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(minHeight: 44)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private func afterSignIn() async {
        await push.refreshPermission()
        try? await Task.sleep(for: .milliseconds(450))
        if push.permission == .notDetermined {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { step = .alerts }
        } else {
            dismiss()
        }
    }
}

// MARK: - Pieces

private struct ModeSwitcher: View {
    @Binding var mode: AppRouter.AuthMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            segment("Sign Up", value: .signUp)
            segment("Log In", value: .logIn)
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.border.opacity(0.6), lineWidth: 1))
        .sensoryFeedback(.selection, trigger: mode)
    }

    private func segment(_ title: String, value: AppRouter.AuthMode) -> some View {
        let isSelected = mode == value
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { mode = value }
        } label: {
            Text(title.uppercased())
                .font(CoastFont.condensed(16))
                .tracking(0.8)
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Theme.orangeGradient)
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PerkRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}

private struct ProviderButton: View {
    let provider: AuthManager.Provider
    let mode: AppRouter.AuthMode
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var verb: String { mode == .signUp ? "Sign up" : "Continue" }
    private var title: String { provider == .apple ? "\(verb) with Apple" : "\(verb) with Google" }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(provider == .apple ? .black : .white)
                } else if provider == .apple {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .semibold))
                } else {
                    GoogleMark()
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(provider == .apple ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                Capsule().fill(provider == .apple ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.surfaceRaised))
            }
            .overlay {
                Capsule().strokeBorder(provider == .apple ? .clear : Theme.blue.opacity(0.5), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.5 : 1)
        .accessibilityLabel(title)
    }
}

/// Four-color Google "G" built from arcs (no bundled asset needed).
private struct GoogleMark: View {
    var body: some View {
        ZStack {
            arc(from: -0.02, to: 0.13, color: Color(hex: 0x4285F4))
            arc(from: 0.13, to: 0.37, color: Color(hex: 0x34A853))
            arc(from: 0.37, to: 0.62, color: Color(hex: 0xFBBC05))
            arc(from: 0.62, to: 0.87, color: Color(hex: 0xEA4335))
            GeometryReader { geo in
                Rectangle()
                    .fill(Color(hex: 0x4285F4))
                    .frame(width: geo.size.width * 0.46, height: geo.size.height * 0.18)
                    .position(x: geo.size.width * 0.72, y: geo.size.height * 0.5)
            }
        }
        .accessibilityHidden(true)
    }

    private func arc(from: CGFloat, to: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: 3.6))
            .padding(1.8)
    }
}

/// Mock lock-screen notification showing what a keyword alert looks like.
private struct KeywordPreviewCard: View {
    @State private var isShown: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Theme.canvas
                .frame(width: 38, height: 38)
                .overlay {
                    Image("CoastLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                }
                .clipShape(.rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("COAST 99.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("now")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Keyword Alert · Coast Cash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("The keyword is SAVANNAH. Enter it now for your shot at $1,000!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .offset(y: isShown ? 0 : -16)
        .opacity(isShown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35)) { isShown = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example alert: The keyword is SAVANNAH. Enter it now for your shot at 1,000 dollars.")
    }
}
