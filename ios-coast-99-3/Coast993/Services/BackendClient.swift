import Foundation

nonisolated enum BackendError: LocalizedError {
    case notConfigured
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The Coast backend isn't configured."
        case .server(_, let message): return message ?? "Something went wrong. Please try again."
        }
    }
}

/// JSON client for the Coast 99.3 Cloudflare backend (keyword alerts).
nonisolated enum BackendClient {
    private static let fallbackURL = "https://coast993-app-backend.rork.app"

    static var baseURL: URL? {
        let configured = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: configured.isEmpty ? fallbackURL : configured)
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }()

    static func send<Response: Decodable & Sendable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable & Sendable)? = nil,
        as type: Response.Type
    ) async throws -> Response {
        guard let baseURL else { throw BackendError.notConfigured }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ServerMessage.self, from: data))?.error
            throw BackendError.server(status: status, message: message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private nonisolated struct ServerMessage: Decodable, Sendable {
    let error: String?
}
