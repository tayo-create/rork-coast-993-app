import SwiftUI

struct ContentView: View {
    @Environment(RadioPlayer.self) private var radio
    @Environment(AppRouter.self) private var router
    @Environment(PushManager.self) private var push
    @Environment(\.scenePhase) private var scenePhase

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
        }
        .tint(Theme.orange)
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .sheet(item: $router.presentedKeyword) { alert in
            KeywordSheet(alert: alert)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: push.openedKeyword) { _, keyword in
            guard let keyword else { return }
            router.selectedTab = .contests
            router.presentedKeyword = keyword
            push.openedKeyword = nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await push.refreshPermission()
                await push.fetchKeywords()
            }
        }
        .task {
            radio.startPolling()
            await push.start()
        }
    }
}

#Preview {
    ContentView()
        .environment(RadioPlayer())
        .environment(ArtworkCache())
        .environment(AppRouter())
        .environment(PushManager.shared)
}
