import Foundation

nonisolated struct MusicTestSong: Identifiable, Hashable, Sendable {
    let id: Int
    let artist: String
    let title: String
}

nonisolated enum SongFeeling: String, CaseIterable, Identifiable, Codable, Sendable {
    case love, like, ok, dislike, never

    var id: String { rawValue }

    var label: String {
        switch self {
        case .love: "LOVE IT"
        case .like: "LIKE IT"
        case .ok: "IT'S OK"
        case .dislike: "DON'T LIKE IT"
        case .never: "NEVER PLAY IT"
        }
    }

    var icon: String {
        switch self {
        case .love: "heart.fill"
        case .like: "hand.thumbsup.fill"
        case .ok: "face.dashed"
        case .dislike: "hand.thumbsdown.fill"
        case .never: "nosign"
        }
    }
}

nonisolated enum SongFamiliarity: String, CaseIterable, Identifiable, Codable, Sendable {
    case veryWell, know, heard, dontKnow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .veryWell: "KNOW IT VERY WELL"
        case .know: "KNOW IT"
        case .heard: "HEARD IT BEFORE"
        case .dontKnow: "DON'T KNOW IT"
        }
    }

    var icon: String {
        switch self {
        case .veryWell: "person.3.fill"
        case .know: "person.fill"
        case .heard: "questionmark"
        case .dontKnow: "xmark"
        }
    }
}

nonisolated enum SongFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case aLot, sometimes, aLittle, rarely, never

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aLot: "PLAY IT A LOT"
        case .sometimes: "SOMETIMES"
        case .aLittle: "A LITTLE"
        case .rarely: "RARELY"
        case .never: "NEVER"
        }
    }

    var waves: Double {
        switch self {
        case .aLot: 1
        case .sometimes: 0.75
        case .aLittle: 0.5
        case .rarely: 0.25
        case .never: 0
        }
    }
}

nonisolated struct SongAnswer: Hashable, Sendable {
    var feeling: SongFeeling?
    var familiarity: SongFamiliarity?
    var frequency: SongFrequency?
    var isSubmitted: Bool = false

    var isComplete: Bool { feeling != nil && familiarity != nil && frequency != nil }
}

nonisolated enum MusicTestCatalog {
    /// This week's test — iTunes track IDs supply the preview clips and cover art.
    static let songs: [MusicTestSong] = [
        MusicTestSong(id: 386153478, artist: "Usher", title: "Yeah! (feat. Lil Jon & Ludacris)"),
        MusicTestSong(id: 1440817530, artist: "Mary J. Blige", title: "Family Affair"),
        MusicTestSong(id: 724665436, artist: "Frankie Beverly & Maze", title: "Before I Let Go"),
        MusicTestSong(id: 1532252603, artist: "Tems", title: "Free Mind"),
        MusicTestSong(id: 1658650499, artist: "SZA", title: "Snooze"),
        MusicTestSong(id: 1663412735, artist: "Coco Jones", title: "ICU"),
        MusicTestSong(id: 157465470, artist: "Ginuwine", title: "Pony"),
        MusicTestSong(id: 157517075, artist: "Jagged Edge", title: "Let's Get Married"),
        MusicTestSong(id: 266611666, artist: "Chaka Khan", title: "Ain't Nobody"),
        MusicTestSong(id: 201274644, artist: "Beyoncé", title: "Crazy in Love (feat. Jay-Z)")
    ]
}
