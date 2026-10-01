import Foundation

@Observable
final class ContestsViewModel {
    enum LoadState: Equatable {
        case loading, loaded, failed
    }

    private(set) var contests: [Contest] = []
    private(set) var loadState: LoadState = .loading

    private static let localImages = ["vegas_strip_fireworks_plane", "cash_flying_stage_lights", "concert_crowd_raised_hands"]

    var featured: Contest? { contests.first }
    var others: [Contest] { Array(contests.dropFirst()) }

    func load() async {
        if contests.isEmpty { loadState = .loading }
        do {
            let dtos = try await StationAPI.fetchContests()
            let now = Date.now
            contests = dtos.enumerated().compactMap { index, dto in
                let ends = Self.parseDate(dto.endsAt)
                if let ends, ends < now { return nil }
                return Contest(
                    id: dto.id,
                    slug: dto.slug ?? dto.id,
                    title: dto.title,
                    prize: dto.prize ?? "",
                    description: dto.description ?? "",
                    rules: dto.rules ?? "",
                    remoteImageURL: Self.imageURL(dto.imageUrl),
                    localImageName: Self.localImage(for: dto, index: index),
                    endsAt: ends
                )
            }
            loadState = .loaded
        } catch {
            if contests.isEmpty { loadState = .failed }
        }
    }

    /// Station images are relative paths to the website's build and don't resolve, so only absolute URLs are used.
    private static func imageURL(_ raw: String?) -> URL? {
        guard let raw, raw.hasPrefix("http") else { return nil }
        return URL(string: raw)
    }

    private static func localImage(for dto: ContestDTO, index: Int) -> String {
        let text = "\(dto.title) \(dto.prize ?? "")".lowercased()
        if text.contains("vegas") || text.contains("trip") || text.contains("flyaway") { return localImages[0] }
        if text.contains("cash") || text.contains("$") { return localImages[1] }
        if text.contains("ticket") || text.contains("concert") || text.contains("jam") { return localImages[2] }
        return localImages[index % localImages.count]
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }
        return ISO8601DateFormatter().date(from: raw)
    }
}

extension Contest {
    var endsLabel: String {
        guard let endsAt else { return "Ongoing" }
        let days = Calendar.current.dateComponents([.day], from: .now, to: endsAt).day ?? 0
        if days <= 0 { return "Ends today" }
        if days == 1 { return "Ends tomorrow" }
        if days < 7 { return "Ends \(endsAt.formatted(.dateTime.weekday(.wide)))" }
        return "Ends \(endsAt.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
