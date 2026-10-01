import SwiftUI
import AuthenticationServices
import CryptoKit

/// Rork Auth (Sign in with Apple / Google) session for Coast accounts.
@Observable
final class AuthManager {
    enum Provider: String {
        case apple, google
    }

    private(set) var user: AccountUser?
    private(set) var isLoading: Bool = true
    private(set) var signingInWith: Provider?
    var showError: Bool = false
    var errorMessage: String = ""

    var isSignedIn: Bool { user != nil }
    var isSigningIn: Bool { signingInWith != nil }

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    private let appKey = Config.EXPO_PUBLIC_RORK_APP_KEY
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?
    private var accessToken: String?
    private var refreshTask: Task<String?, Never>?

    /// Injected by Rork into UserDefaults on its cloud simulator only. Read on every access.
    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    init() {
        Task { await checkAuth() }
    }

    // MARK: - Session

    func checkAuth() async {
        defer { isLoading = false }
        if let token = TokenStore.get("access_token"), let decoded = Self.userFromToken(token) {
            accessToken = token
            user = decoded
            return
        }
        if TokenStore.refreshToken() != nil {
            _ = await refreshAccessToken()
        }
    }

    /// Returns a non-expired access token, refreshing it if needed. Nil when signed out.
    func validAccessToken() async -> String? {
        guard user != nil else { return nil }
        if let accessToken, Self.userFromToken(accessToken) != nil { return accessToken }
        if let refreshTask { return await refreshTask.value }
        let task = Task { await refreshAccessToken() }
        refreshTask = task
        let token = await task.value
        refreshTask = nil
        return token
    }

    func signIn(provider: Provider) async {
        guard signingInWith == nil else { return }
        signingInWith = provider
        defer { signingInWith = nil }
        do {
            let verifier = Self.generateCodeVerifier()
            codeVerifier = verifier

            guard let url = URL(string: "\(authURL)/oauth/initiate") else {
                setError("Sign in isn't available right now.")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: String] = [
                "app_key": appKey,
                "provider": provider.rawValue,
                "code_challenge": Self.codeChallenge(for: verifier),
                "target": "swift",
                "env": authEnv
            ]
            if authEnv == "simulator", let hint = developerHint {
                body["developer_hint"] = hint
            }
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let message = (try? JSONDecoder().decode(AuthErrorResponse.self, from: data))?.error
                setError(message ?? "Sign in failed. Please try again.")
                return
            }
            let initiate = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiate.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiate.state)
                } catch AuthError.cancelledByUser {
                    code = try await runWebAuthSession(authURL: initiate.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiate.auth_url)
            }
            await exchangeCode(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            setError(error.localizedDescription)
        }
    }

    func signOut() {
        TokenStore.delete("access_token")
        TokenStore.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        accessToken = nil
        user = nil
    }

    // MARK: - OAuth plumbing

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else { throw AuthError.invalidURL }
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }
            if poll.status == "cancelled" { throw AuthError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw AuthError.popupTimeout
    }

    private func runWebAuthSession(authURL authURLString: String) async throws -> String {
        let callbackScheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: authURLString) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                self?.webAuthSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }
            webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier, let url = URL(string: "\(authURL)/oauth/token") else { return }
        codeVerifier = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["app_key": appKey, "code": code, "code_verifier": verifier])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let message = (try? JSONDecoder().decode(AuthErrorResponse.self, from: data))?.error
                setError(message ?? "Sign in failed. Please try again.")
                return
            }
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            TokenStore.set("access_token", value: token.access_token)
            TokenStore.set("refresh_token", value: token.refresh_token)
            accessToken = token.access_token
            user = Self.userFromToken(token.access_token) ?? token.user
        } catch {
            setError("Sign in failed. Please check your connection.")
        }
    }

    private func refreshAccessToken() async -> String? {
        guard let refresh = TokenStore.refreshToken(),
              let url = URL(string: "\(authURL)/oauth/refresh") else {
            signOut()
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["app_key": appKey, "refresh_token": refresh])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                // Only a definitive rejection ends the session; network blips keep the user signed in.
                if status == 400 || status == 401 || status == 403 { signOut() }
                return nil
            }
            let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
            TokenStore.set("access_token", value: refreshed.access_token)
            accessToken = refreshed.access_token
            user = Self.userFromToken(refreshed.access_token) ?? user
            return refreshed.access_token
        } catch {
            return nil
        }
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Helpers

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes the JWT payload (signature was verified by Rork when issued). Nil if expired.
    private static func userFromToken(_ token: String) -> AccountUser? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date().addingTimeInterval(30) { return nil }
        return AccountUser(id: payload.sub, email: payload.email, name: payload.name, picture: payload.picture)
    }
}

/// Keychain-backed token storage, with a UserDefaults fallback on simulators without keychain entitlements.
private nonisolated enum TokenStore {
    static func set(_ key: String, value: String) {
        if KeychainHelper.set(key, value: value) { return }
        #if targetEnvironment(simulator)
        UserDefaults.standard.set(value, forKey: "coast.sim.\(key)")
        #endif
    }

    static func get(_ key: String) -> String? {
        if let value = KeychainHelper.get(key) { return value }
        #if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: "coast.sim.\(key)")
        #else
        return nil
        #endif
    }

    static func delete(_ key: String) {
        KeychainHelper.delete(key)
        UserDefaults.standard.removeObject(forKey: "coast.sim.\(key)")
    }

    static func refreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") { return injected }
        #endif
        return get("refresh_token")
    }
}

// MARK: - Response types

private nonisolated struct JWTPayload: Decodable, Sendable {
    let sub: String
    let email: String?
    let name: String?
    let picture: String?
    let exp: TimeInterval?
}

private nonisolated struct InitiateResponse: Decodable, Sendable {
    let auth_url: String
    let state: String
    let flow: String?
}

private nonisolated struct PollCodeResponse: Decodable, Sendable {
    let status: String
    let code: String?
}

private nonisolated struct TokenResponse: Decodable, Sendable {
    let access_token: String
    let refresh_token: String
    let user: AccountUser
}

private nonisolated struct RefreshResponse: Decodable, Sendable {
    let access_token: String
}

private nonisolated struct AuthErrorResponse: Decodable, Sendable {
    let error: String
}

nonisolated enum AuthError: LocalizedError {
    case noCode, invalidURL, popupTimeout, cancelledByUser

    var errorDescription: String? {
        switch self {
        case .noCode: return "No authorization code received."
        case .invalidURL: return "Sign in isn't available right now."
        case .popupTimeout: return "Sign-in timed out — please try again."
        case .cancelledByUser: return "Sign-in cancelled."
        }
    }
}

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
