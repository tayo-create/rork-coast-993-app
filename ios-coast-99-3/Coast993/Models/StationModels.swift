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

    /// Studio request line, digits only (e.g. "9125550993"). `nil` hides the Request a Song card.
    static let requestLineDigits: String? = nil
    /// Official social accounts. Empty hides the Follow row.
    static let socialLinks: [SocialLink] = []
}

/// An official Coast 99.3 social account shown on the Station tab.
nonisolated struct SocialLink: Identifiable, Hashable, Sendable {
    let name: String
    let systemImage: String
    let url: URL

    var id: String { name }
}
