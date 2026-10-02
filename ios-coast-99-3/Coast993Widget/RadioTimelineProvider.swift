import WidgetKit
import Foundation

nonisolated struct RadioEntry: TimelineEntry {
    let date: Date
    let isPlaying: Bool
    let isBuffering: Bool
    let title: String?
    let artist: String?

    static let sample = RadioEntry(
        date: .now,
        isPlaying: false,
        isBuffering: false,
        title: "Savannah's Hip Hop",
        artist: "R&B & Throwbacks"
    )
}

nonisolated struct RadioTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RadioEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (RadioEntry) -> Void) {
        let state = RadioShared.load()
        if context.isPreview && state.title == nil {
            completion(.sample)
        } else {
            completion(Self.entry(from: state, fetched: nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RadioEntry>) -> Void) {
        Task {
            let state = RadioShared.load()
            // While the app is streaming it keeps the song fresh; otherwise ask the station directly.
            let fetched: WidgetNowPlaying? = state.isPlaying ? nil : await WidgetNowPlayingAPI.fetch()
            let entry = Self.entry(from: state, fetched: fetched)
            let next = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private static func entry(from state: RadioWidgetState, fetched: WidgetNowPlaying?) -> RadioEntry {
        RadioEntry(
            date: .now,
            isPlaying: state.isPlaying,
            isBuffering: state.isBuffering,
            title: fetched?.title ?? state.title,
            artist: fetched?.artist ?? state.artist
        )
    }
}

nonisolated struct WidgetNowPlaying: Sendable {
    let title: String
    let artist: String
}

/// Minimal AzuraCast now-playing fetch for when the app isn't running.
nonisolated enum WidgetNowPlayingAPI {
    private static let url = URL(string: "https://a6.asurahosting.com/api/nowplaying/coast993")!

    static func fetch() async -> WidgetNowPlaying? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let song = try decoder.decode(WidgetAzuraResponse.self, from: data).nowPlaying?.song
            let title = (song?.title ?? "").trimmingCharacters(in: .whitespaces)
            let artist = (song?.artist ?? "").trimmingCharacters(in: .whitespaces)
            // Station IDs / liners have no artist; keep the brand line instead.
            guard !title.isEmpty, !artist.isEmpty else { return nil }
            return WidgetNowPlaying(title: title, artist: artist)
        } catch {
            return nil
        }
    }
}

nonisolated struct WidgetAzuraResponse: Decodable, Sendable {
    let nowPlaying: WidgetAzuraNowPlaying?
}

nonisolated struct WidgetAzuraNowPlaying: Decodable, Sendable {
    let song: WidgetAzuraSong
}

nonisolated struct WidgetAzuraSong: Decodable, Sendable {
    let title: String?
    let artist: String?
}
