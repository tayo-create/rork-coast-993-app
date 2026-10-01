import Foundation
import UIKit
import UserNotifications

/// Keyword alert push notifications: permission, APNs token registration and in-app keyword feed.
@Observable
final class PushManager {
    enum Permission: Equatable {
        case unknown, notDetermined, denied, authorized
    }

    static let shared = PushManager()

    private(set) var permission: Permission = .unknown
    private(set) var deviceToken: String?
    private(set) var latestKeyword: KeywordAlert?
    private(set) var isRegisteredWithBackend: Bool = false

    /// Set when the listener taps a keyword push; the root view routes to Contests.
    var openedKeyword: KeywordAlert?

    /// Listener's in-app preference (separate from the iOS permission).
    var alertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(alertsEnabled, forKey: Self.alertsKey)
            Task { await registerWithBackend() }
        }
    }

    /// Supplies the signed-in user's bearer token so devices link to accounts.
    var tokenProvider: (() async -> String?)?

    var isReceivingAlerts: Bool { permission == .authorized && alertsEnabled }

    private static let alertsKey = "coast.push.alertsEnabled"
    private var keywordTask: Task<Void, Never>?

    private init() {
        alertsEnabled = UserDefaults.standard.object(forKey: Self.alertsKey) as? Bool ?? true
    }

    private var pushEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    // MARK: - Permission

    func start() async {
        await refreshPermission()
        if permission == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
        await fetchKeywords()
    }

    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: permission = .notDetermined
        case .denied: permission = .denied
        case .authorized, .provisional, .ephemeral: permission = .authorized
        @unknown default: permission = .unknown
        }
    }

    /// Asks for notification permission (once) and registers with APNs. Returns true if allowed.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                alertsEnabled = true
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[Push] authorization failed: \(error.localizedDescription)")
        }
        await refreshPermission()
        return permission == .authorized
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - APNs token

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await registerWithBackend() }
    }

    func didFailToRegister(_ error: Error) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    /// Upserts this device with the backend; links it to the signed-in account when available.
    func registerWithBackend() async {
        guard let deviceToken else { return }
        let token = await tokenProvider?()
        let body = RegisterBody(token: deviceToken, environment: pushEnvironment, alertsEnabled: alertsEnabled)
        do {
            _ = try await BackendClient.send("push/register", method: "POST", body: body, token: token, as: OKResponse.self)
            isRegisteredWithBackend = true
        } catch {
            print("[Push] backend registration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Keywords

    func fetchKeywords() async {
        do {
            let response = try await BackendClient.send("keywords", as: KeywordsResponse.self)
            if let latest = response.keywords.first {
                latestKeyword = latest
            }
        } catch {
            print("[Push] keyword fetch failed: \(error.localizedDescription)")
        }
    }

    /// Called from the notification delegate for foreground delivery or a tap.
    func handle(_ alert: KeywordAlert, opened: Bool) {
        latestKeyword = alert
        if opened { openedKeyword = alert }
    }
}

private nonisolated struct RegisterBody: Encodable, Sendable {
    let token: String
    let environment: String
    let alertsEnabled: Bool
}
