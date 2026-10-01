import Foundation

/// Resolves album art for aired songs via iTunes search, memoized per song.
@Observable
final class ArtworkCache {
    private(set) var urls: [String: URL] = [:]
    private var inFlight: Set<String> = []
    private var misses: Set<String> = []

    func url(for track: Track) -> URL? {
        urls[track.searchTerm]
    }

    func resolve(_ track: Track) {
        let key = track.searchTerm
        guard urls[key] == nil, !inFlight.contains(key), !misses.contains(key), !track.artist.isEmpty else { return }
        inFlight.insert(key)
        Task {
            defer { inFlight.remove(key) }
            do {
                if let url = try await StationAPI.searchITunes(term: key)?.largeArtworkURL {
                    urls[key] = url
                } else {
                    misses.insert(key)
                }
            } catch {
                misses.insert(key)
            }
        }
    }
}
