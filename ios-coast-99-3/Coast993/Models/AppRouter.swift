import SwiftUI

/// App-wide navigation state shared across tabs (selected tab, keyword alert sheet).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .live
    var presentedKeyword: KeywordAlert?
}
