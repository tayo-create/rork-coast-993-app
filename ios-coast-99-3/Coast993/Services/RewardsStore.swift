import Foundation

/// Coast Rewards points ledger. Stored on-device for guests; mirrored to the listener's
/// account on the Coast backend when signed in (last server state is cached for offline use).
@Observable
final class RewardsStore {
    enum SyncStatus: Equatable {
        case localOnly, syncing, synced(Date), failed
    }

    private(set) var state: RewardsState
    private(set) var syncStatus: SyncStatus = .localOnly
    private(set) var accountID: String?

    /// Most recent points award, used for a celebratory toast.
    private(set) var lastAward: RewardActivity?

    private static let guestKey = "coast.rewards.v1"
    private var tokenProvider: (() async -> String?)?
    private var syncTask: Task<Void, Never>?
    private var version: Int = 0

    init() {
        state = Self.load(key: Self.guestKey) ?? RewardsState()
    }

    var points: Int { state.points }
    var activity: [RewardActivity] { state.activity }
    var claims: [RewardClaim] { state.claims }
    var isSynced: Bool { accountID != nil }

    var listenProgress: Double {
        guard state.listenDay == Self.today else { return 0 }
        return min(state.listenSecondsToday / RewardRules.dailyListenSeconds, 1)
    }

    var listenMinutesToday: Int {
        guard state.listenDay == Self.today else { return 0 }
        return Int(state.listenSecondsToday / 60)
    }

    var hasEarnedDailyListenToday: Bool { state.lastDailyListenAwardDay == Self.today }
    var hasEarnedMusicTestToday: Bool { state.lastMusicTestAwardDay == Self.today }

    func hasEntered(_ contestID: String) -> Bool {
        state.enteredContestIDs.contains(contestID)
    }

    // MARK: - Account linking

    /// Switches to the signed-in account and merges any guest progress into it.
    func attach(accountID newID: String, tokenProvider: @escaping () async -> String?) async {
        guard accountID != newID else { return }
        self.tokenProvider = tokenProvider
        let guest = Self.load(key: Self.guestKey) ?? RewardsState()
        accountID = newID
        let cached = Self.load(key: accountKey(newID))
        state = cached ?? guest
        await syncNow(sending: Self.merging(guest, into: cached), clearGuestOnSuccess: !guest.isEmpty)
    }

    /// Returns to a fresh guest ledger (the account copy stays safely on the server).
    func detach() {
        syncTask?.cancel()
        if let accountID { UserDefaults.standard.removeObject(forKey: accountKey(accountID)) }
        accountID = nil
        tokenProvider = nil
        state = Self.load(key: Self.guestKey) ?? RewardsState()
        syncStatus = .localOnly
    }

    /// Pushes the local ledger and pulls the merged account ledger.
    func syncNow() async {
        await syncNow(sending: state, clearGuestOnSuccess: false)
    }

    private func syncNow(sending payload: RewardsState, clearGuestOnSuccess: Bool) async {
        guard accountID != nil, let tokenProvider else { return }
        let sentVersion = version
        syncStatus = .syncing
        guard let token = await tokenProvider() else {
            syncStatus = .failed
            return
        }
        do {
            let response = try await BackendClient.send(
                "rewards/sync", method: "POST", body: payload, token: token, as: SyncResponse.self
            )
            if clearGuestOnSuccess { UserDefaults.standard.removeObject(forKey: Self.guestKey) }
            if version == sentVersion {
                state = response.rewards
                save()
            } else {
                // Local changes landed mid-flight; send them too (server merge is idempotent).
                scheduleSync(delay: .milliseconds(300))
            }
            syncStatus = .synced(.now)
        } catch {
            print("[Rewards] sync failed: \(error.localizedDescription)")
            syncStatus = .failed
        }
    }

    private func scheduleSync(delay: Duration = .seconds(2)) {
        guard accountID != nil else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: - Earning

    func recordListening(seconds: Double) {
        if state.listenDay != Self.today {
            state.listenDay = Self.today
            state.listenSecondsToday = 0
        }
        state.listenSecondsToday += seconds
        if state.listenSecondsToday >= RewardRules.dailyListenSeconds, !hasEarnedDailyListenToday {
            state.lastDailyListenAwardDay = Self.today
            award("Daily Listen", points: RewardRules.dailyListen, dedupeKey: "listen:\(Self.today)")
        } else {
            save()
        }
    }

    /// Awards Music Test points once per day; returns points granted.
    @discardableResult
    func completeMusicTest() -> Int {
        guard !hasEarnedMusicTestToday else { return 0 }
        state.lastMusicTestAwardDay = Self.today
        award("Music Test", points: RewardRules.musicTest, dedupeKey: "musictest:\(Self.today)")
        return RewardRules.musicTest
    }

    func recordContestEntry(_ contest: Contest) {
        guard !hasEntered(contest.id) else { return }
        state.enteredContestIDs.append(contest.id)
        award("Entered \(contest.displayTitle)", points: RewardRules.contestEntry, dedupeKey: "contest:\(contest.id)")
    }

    // MARK: - Redeeming

    func canRedeem(_ tier: RewardTier) -> Bool { state.points >= tier.cost }

    func redeem(_ tier: RewardTier) -> RewardClaim? {
        guard canRedeem(tier) else { return nil }
        let code = "COAST-" + String(UUID().uuidString.prefix(6)).uppercased()
        let claim = RewardClaim(rewardName: tier.name, cost: tier.cost, code: code, date: .now)
        state.points -= tier.cost
        state.claims.insert(claim, at: 0)
        state.activity.insert(
            RewardActivity(title: "Redeemed \(tier.name)", points: -tier.cost, date: .now, dedupeKey: "redeem:\(claim.id.uuidString)"),
            at: 0
        )
        commit()
        return claim
    }

    func clearLastAward() { lastAward = nil }

    private func award(_ title: String, points: Int, dedupeKey: String) {
        let entry = RewardActivity(title: title, points: points, date: .now, dedupeKey: dedupeKey)
        state.points += points
        state.activity.insert(entry, at: 0)
        if state.activity.count > 50 { state.activity.removeLast(state.activity.count - 50) }
        lastAward = entry
        commit()
    }

    private func commit() {
        version += 1
        save()
        scheduleSync()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: accountID.map(accountKey) ?? Self.guestKey)
    }

    private func accountKey(_ id: String) -> String { "coast.rewards.account.\(id)" }

    private static func load(key: String) -> RewardsState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RewardsState.self, from: data)
    }

    /// Guest ledger entries layered onto the cached account copy for the first sync after sign-in.
    private static func merging(_ guest: RewardsState, into cached: RewardsState?) -> RewardsState {
        guard var merged = cached else { return guest }
        let known = Set(merged.activity.map(\.id))
        merged.activity = guest.activity.filter { !known.contains($0.id) } + merged.activity
        merged.claims = guest.claims + merged.claims
        merged.enteredContestIDs = Array(Set(merged.enteredContestIDs + guest.enteredContestIDs))
        merged.lastMusicTestAwardDay = max(merged.lastMusicTestAwardDay, guest.lastMusicTestAwardDay)
        merged.lastDailyListenAwardDay = max(merged.lastDailyListenAwardDay, guest.lastDailyListenAwardDay)
        if guest.listenDay >= merged.listenDay {
            merged.listenSecondsToday = guest.listenDay == merged.listenDay
                ? max(merged.listenSecondsToday, guest.listenSecondsToday)
                : guest.listenSecondsToday
            merged.listenDay = guest.listenDay
        }
        return merged
    }

    private static var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
