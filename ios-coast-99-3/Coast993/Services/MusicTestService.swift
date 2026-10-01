import Foundation

/// Persists Music Test answers on-device and sends them anonymously to the station.
nonisolated enum MusicTestService {
    private static let answersKey = "coast.musictest.answers.\(MusicTestCatalog.testID)"
    private static let submissionKey = "coast.musictest.submissionID"

    /// Random, anonymous id so a listener's resubmissions replace (not duplicate) their answers.
    static var submissionID: String {
        if let existing = UserDefaults.standard.string(forKey: submissionKey) { return existing }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: submissionKey)
        return id
    }

    static func loadAnswers() -> [Int: SongAnswer] {
        guard let data = UserDefaults.standard.data(forKey: answersKey),
              let decoded = try? JSONDecoder().decode([Int: SongAnswer].self, from: data) else { return [:] }
        return decoded
    }

    static func saveAnswers(_ answers: [Int: SongAnswer]) {
        guard let data = try? JSONEncoder().encode(answers) else { return }
        UserDefaults.standard.set(data, forKey: answersKey)
    }

    static func clearAnswers() {
        UserDefaults.standard.removeObject(forKey: answersKey)
    }

    /// Uploads every submitted answer. Throws so the caller can show a retry state.
    static func upload(_ answers: [Int: SongAnswer], songs: [MusicTestSong]) async throws {
        let payload = songs.compactMap { song -> MusicTestAnswerBody? in
            guard let answer = answers[song.id], answer.isSubmitted,
                  let feeling = answer.feeling, let familiarity = answer.familiarity, let frequency = answer.frequency
            else { return nil }
            return MusicTestAnswerBody(
                songId: song.id,
                artist: song.artist,
                title: song.title,
                feeling: feeling.rawValue,
                familiarity: familiarity.rawValue,
                frequency: frequency.rawValue
            )
        }
        guard !payload.isEmpty else { return }
        let body = MusicTestSubmissionBody(submissionId: submissionID, testId: MusicTestCatalog.testID, answers: payload)
        _ = try await BackendClient.send("music-test", method: "POST", body: body, as: OKResponse.self)
    }
}

private nonisolated struct MusicTestSubmissionBody: Encodable, Sendable {
    let submissionId: String
    let testId: String
    let answers: [MusicTestAnswerBody]
}

private nonisolated struct MusicTestAnswerBody: Encodable, Sendable {
    let songId: Int
    let artist: String
    let title: String
    let feeling: String
    let familiarity: String
    let frequency: String
}
