import Foundation

/// Signed-in Coast listener (from Rork Auth).
nonisolated struct AccountUser: Codable, Hashable, Sendable {
    let id: String
    let email: String?
    let name: String?
    let picture: String?

    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let email, let handle = email.split(separator: "@").first { return String(handle) }
        return "Coast Listener"
    }

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "C" : letters.uppercased()
    }
}

/// A contest keyword announced by the station.
nonisolated struct KeywordAlert: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let keyword: String
    let contestSlug: String?
    let contestTitle: String?
    let message: String?
    /// Milliseconds since 1970 (server clock).
    let createdAt: Double

    var createdDate: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var isFresh: Bool { Date.now.timeIntervalSince(createdDate) < 60 * 60 }
    var entryURL: URL {
        URL(string: "https://coast993.com/contests/\(contestSlug ?? "coast-cash-keyword")") ?? StationConfig.websiteURL
    }

    /// Parses the custom keys of a keyword push payload.
    static func from(userInfo: [AnyHashable: Any]) -> KeywordAlert? {
        guard (userInfo["type"] as? String) == "keyword",
              let keyword = userInfo["keyword"] as? String else { return nil }
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        return KeywordAlert(
            id: (userInfo["announcementId"] as? String) ?? UUID().uuidString,
            keyword: keyword,
            contestSlug: userInfo["contestSlug"] as? String,
            contestTitle: userInfo["contestTitle"] as? String,
            message: alert?["body"] as? String,
            createdAt: Date.now.timeIntervalSince1970 * 1000
        )
    }
}

// MARK: - Backend DTOs

nonisolated struct MeResponse: Decodable, Sendable {
    let rewards: RewardsState?
}

nonisolated struct SyncResponse: Decodable, Sendable {
    let rewards: RewardsState
}

nonisolated struct KeywordsResponse: Decodable, Sendable {
    let keywords: [KeywordAlert]
}

nonisolated struct OKResponse: Decodable, Sendable {
    let ok: Bool?
}
