import SwiftUI

struct ContentView: View {
    @Environment(RadioPlayer.self) private var radio
    @Environment(RewardsStore.self) private var rewards
    @Environment(AuthManager.self) private var auth
    @Environment(AppRouter.self) private var router
    @Environment(PushManager.self) private var push
    @Environment(\.scenePhase) private var scenePhase
    @State private var toast: RewardActivity?

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Live", systemImage: "dot.radiowaves.left.and.right", value: AppTab.live) {
                LiveView(selectedTab: $router.selectedTab)
            }
            Tab("Music Test", systemImage: "music.note", value: AppTab.musicTest) {
                MusicTestView(selectedTab: $router.selectedTab)
            }
            Tab("Contests", systemImage: "trophy.fill", value: AppTab.contests) {
                ContestsView()
            }
            Tab("Rewards", systemImage: "gift.fill", value: AppTab.rewards) {
                RewardsView(selectedTab: $router.selectedTab)
            }
        }
        .tint(Theme.orange)
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .overlay(alignment: .top) {
            if let toast {
                AwardToast(activity: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 6)
            }
        }
        .fullScreenCover(item: Binding(
            get: { router.authMode.map(AuthModeItem.init) },
            set: { router.authMode = $0?.mode }
        )) { item in
            AuthView(initialMode: item.mode)
        }
        .sheet(isPresented: $router.isAccountPresented) {
            AccountView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $router.presentedKeyword) { alert in
            KeywordSheet(alert: alert)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: rewards.lastAward) { _, award in
            guard let award else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { toast = award }
            Task {
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.easeInOut(duration: 0.3)) {
                    if toast?.id == award.id { toast = nil }
                }
                rewards.clearLastAward()
            }
        }
        .onChange(of: auth.user) { _, user in
            Task { await linkAccount(user) }
        }
        .onChange(of: push.openedKeyword) { _, keyword in
            guard let keyword else { return }
            router.selectedTab = .contests
            router.authMode = nil
            router.isAccountPresented = false
            router.presentedKeyword = keyword
            push.openedKeyword = nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await push.refreshPermission()
                await push.fetchKeywords()
                await rewards.syncNow()
            }
        }
        .task {
            radio.onListenTick = { [rewards] seconds in
                rewards.recordListening(seconds: seconds)
            }
            radio.startPolling()
            push.tokenProvider = { [auth] in await auth.validAccessToken() }
            await push.start()
        }
    }

    private func linkAccount(_ user: AccountUser?) async {
        if let user {
            await rewards.attach(accountID: user.id) { [auth] in await auth.validAccessToken() }
        } else if rewards.isSynced {
            rewards.detach()
        }
        await push.registerWithBackend()
    }
}

private struct AuthModeItem: Identifiable {
    let mode: AppRouter.AuthMode
    var id: String { mode == .signUp ? "signUp" : "logIn" }
}

private struct AwardToast: View {
    let activity: RewardActivity

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.orangeGradient))
            Text("+\(activity.points) pts")
                .font(CoastFont.display(20))
                .foregroundStyle(Theme.orange)
            Text(activity.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .sensoryFeedback(.success, trigger: activity.id)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
        .environment(RadioPlayer())
        .environment(RewardsStore())
        .environment(ArtworkCache())
        .environment(AuthManager())
        .environment(AppRouter())
        .environment(PushManager.shared)
}
