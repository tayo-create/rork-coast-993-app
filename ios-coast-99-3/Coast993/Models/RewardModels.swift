import Foundation

nonisolated struct RewardActivity: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    let title: String
    let points: Int
    let date: Date
    /// Identifies one-time awards (e.g. "listen:2026-09-30") so syncing never double-counts them.
    var dedupeKey: String?
}

nonisolated struct RewardClaim: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    let rewardName: String
    let cost: Int
    let code: String
    let date: Date
}

nonisolated struct RewardTier: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let cost: Int
    let icon: String

    static let catalog: [RewardTier] = [
        RewardTier(id: "reward5", name: "$5 Coast Reward", detail: "Our starter reward", cost: 500, icon: "gift.fill"),
        RewardTier(id: "reward10", name: "$10 Coast Reward", detail: "Double up", cost: 1000, icon: "giftcard.fill"),
        RewardTier(id: "reward25", name: "$25 Coast Reward", detail: "For the real Coast family", cost: 2500, icon: "crown.fill")
    ]
}

/// Persisted rewards state (small, JSON in UserDefaults).
nonisolated struct RewardsState: Codable, Sendable {
    var points: Int = 0
    var activity: [RewardActivity] = []
    var claims: [RewardClaim] = []
    var listenDay: String = ""
    var listenSecondsToday: Double = 0
    var lastDailyListenAwardDay: String = ""
    var lastMusicTestAwardDay: String = ""
    var enteredContestIDs: [String] = []

    var isEmpty: Bool { points == 0 && activity.isEmpty && claims.isEmpty && listenSecondsToday == 0 }
}

nonisolated enum RewardRules {
    static let musicTest = 50
    static let dailyListen = 10
    static let contestEntry = 5
    static let dailyListenSeconds: Double = 30 * 60
    static let pointsPerReward = 500
}
