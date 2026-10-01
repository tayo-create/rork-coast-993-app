import Foundation

nonisolated enum StationAPIError: LocalizedError {
    case badResponse

    var errorDescription: String? { "Couldn't reach Coast 99.3 right now." }
}

/// Network access for live metadata and iTunes previews/artwork.
nonisolated enum StationAPI {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static func snakeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func fetchNowPlaying() async throws -> AzuraNowPlayingResponse {
        let (data, response) = try await session.data(from: StationConfig.nowPlayingURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw StationAPIError.badResponse }
        return try snakeDecoder().decode(AzuraNowPlayingResponse.self, from: data)
    }

    static func searchITunes(term: String) async throws -> ITunesTrack? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "country", value: "us")
        ]
        guard let url = components?.url else { return nil }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ITunesResponse.self, from: data).results.first
    }

    static func lookupITunes(ids: [Int]) async throws -> [Int: ITunesTrack] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "country", value: "us")
        ]
        guard let url = components?.url else { return [:] }
        let (data, _) = try await session.data(from: url)
        let results = try JSONDecoder().decode(ITunesResponse.self, from: data).results
        var map: [Int: ITunesTrack] = [:]
        for item in results {
            if let id = item.trackId { map[id] = item }
        }
        return map
    }
}
