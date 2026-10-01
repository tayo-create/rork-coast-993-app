import Foundation

/// A song that aired (or is airing) on Coast 99.3.
nonisolated struct Track: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let playedAt: Date?
    var artworkURL: URL?

    var searchTerm: String { "\(artist) \(title)" }
}

// MARK: - AzuraCast now-playing API DTOs

nonisolated struct AzuraNowPlayingResponse: Decodable, Sendable {
    let nowPlaying: AzuraNowPlaying?
    let songHistory: [AzuraHistoryItem]?
    let listeners: AzuraListeners?
    let isOnline: Bool?
}

nonisolated struct AzuraNowPlaying: Decodable, Sendable {
    let shId: Int?
    let playedAt: Int?
    let song: AzuraSong
}

nonisolated struct AzuraHistoryItem: Decodable, Sendable {
    let shId: Int
    let playedAt: Int?
    let song: AzuraSong
}

nonisolated struct AzuraSong: Decodable, Sendable {
    let id: String?
    let text: String?
    let artist: String?
    let title: String?
}

nonisolated struct AzuraListeners: Decodable, Sendable {
    let current: Int?
}

// MARK: - Contests (coast993.com)

nonisolated struct ContestDTO: Decodable, Sendable {
    let id: String
    let slug: String?
    let title: String
    let prize: String?
    let description: String?
    let rules: String?
    let imageUrl: String?
    let startsAt: String?
    let endsAt: String?
}

nonisolated struct Contest: Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let title: String
    let prize: String
    let description: String
    let rules: String
    let remoteImageURL: URL?
    let localImageName: String
    let endsAt: Date?

    var entryURL: URL {
        URL(string: "https://coast993.com/contests/\(slug)") ?? StationConfig.websiteURL
    }

    /// Title-cased display title (the station stores titles in all caps).
    var displayTitle: String { title.capitalized(with: Locale(identifier: "en_US")) }
}

// MARK: - iTunes

nonisolated struct ITunesResponse: Decodable, Sendable {
    let results: [ITunesTrack]
}

nonisolated struct ITunesTrack: Decodable, Sendable {
    let trackId: Int?
    let artistName: String?
    let trackName: String?
    let previewUrl: String?
    let artworkUrl100: String?

    var largeArtworkURL: URL? {
        guard let artworkUrl100 else { return nil }
        return URL(string: artworkUrl100.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
    }
}

nonisolated enum StationConfig {
    static let streamURL = URL(string: "https://a6.asurahosting.com:8260/radio.mp3")!
    static let nowPlayingURL = URL(string: "https://a6.asurahosting.com/api/nowplaying/coast993")!
    static let websiteURL = URL(string: "https://coast993.com")!
    static let contestsBaseURL = "https://lmnezbqryggcdmcnmhro.supabase.co/rest/v1/contests"
    /// Publishable (client-safe) key used by coast993.com for public, read-only content.
    static let publishableKey = "sb_publishable_-so2FL7om0tUKyGA_JkV2g_R45mSxHm"
}
