import SwiftUI

@main
struct Coast993App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var radio: RadioPlayer = RadioPlayer()
    @State private var artwork: ArtworkCache = ArtworkCache()
    @State private var router: AppRouter = AppRouter()
    @State private var push: PushManager = PushManager.shared

    init() {
        CoastFont.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(radio)
                .environment(artwork)
                .environment(router)
                .environment(push)
                .preferredColorScheme(.dark)
        }
    }
}
