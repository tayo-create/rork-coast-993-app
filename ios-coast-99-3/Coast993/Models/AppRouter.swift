import SwiftUI
import UIKit

/// App-wide presentation state (account screens, keyword alerts) shared across tabs.
@Observable
final class AppRouter {
    enum AuthMode: Equatable {
        case signUp, logIn
    }

    var selectedTab: AppTab = .live
    var authMode: AuthMode?
    var isAccountPresented: Bool = false
    var presentedKeyword: KeywordAlert?

    /// Opens sign-up/login when signed out, or the account sheet when signed in.
    func openAccount(isSignedIn: Bool) {
        if isSignedIn {
            isAccountPresented = true
        } else {
            authMode = .signUp
        }
    }
}

extension UIApplication {
    /// Top safe-area inset of the key window, for headers that draw under the status bar.
    var keyWindowTopInset: CGFloat {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 47
    }
}
