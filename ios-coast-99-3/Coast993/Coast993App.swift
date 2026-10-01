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
        Self.removeLegacyMusicTestData()
    }

    /// The Music Test was retired; wipe any answers or ids it left in UserDefaults.
    private static func removeLegacyMusicTestData() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("coast.musictest.") {
            defaults.removeObject(forKey: key)
        }
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
