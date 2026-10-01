import SwiftUI

struct RewardsCatalogView: View {
    @Environment(RewardsStore.self) private var rewards
    @Environment(\.dismiss) private var dismiss
    @State private var pendingTier: RewardTier?
    @State private var revealedClaim: RewardClaim?
    @State private var redeemTrigger: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    balance

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Redeem")
                        ForEach(RewardTier.catalog) { tier in
                            TierCard(tier: tier, points: rewards.points) {
                                pendingTier = tier
                            }
                        }
                    }

                    if !rewards.claims.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "My Rewards")
                            VStack(spacing: 0) {
                                ForEach(rewards.claims) { claim in
                                    ClaimRow(claim: claim)
                                    if claim.id != rewards.claims.last?.id {
                                        Divider().overlay(Theme.border.opacity(0.4))
                                    }
                                }
                            }
                            .coastCard(cornerRadius: 18, padding: 12)
                            Text("Show your code at any Coast 99.3 event or contact the station to claim.")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Activity")
                        if rewards.activity.isEmpty {
                            Text("Take the Music Test, listen live and enter contests to start earning.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .coastCard(cornerRadius: 18)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(rewards.activity) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Text(item.points > 0 ? "+\(item.points)" : "\(item.points)")
                                            .font(CoastFont.display(20))
                                            .foregroundStyle(item.points > 0 ? Theme.orange : Theme.blueSoft)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                            .coastCard(cornerRadius: 18, padding: 12)
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Coast Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.orange)
                }
            }
            .sensoryFeedback(.success, trigger: redeemTrigger)
            .confirmationDialog(
                "Redeem \(pendingTier?.name ?? "")?",
                isPresented: Binding(get: { pendingTier != nil }, set: { if !$0 { pendingTier = nil } }),
                titleVisibility: .visible,
                presenting: pendingTier
            ) { tier in
                Button("Redeem for \(tier.cost) points") {
                    if let claim = rewards.redeem(tier) {
                        redeemTrigger += 1
                        revealedClaim = claim
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { tier in
                Text("\(tier.cost) points will be deducted from your balance.")
            }
            .alert(
                "Reward unlocked!",
                isPresented: Binding(get: { revealedClaim != nil }, set: { if !$0 { revealedClaim = nil } }),
                presenting: revealedClaim
            ) { _ in
                Button("Nice!", role: .cancel) {}
            } message: { claim in
                Text("Your \(claim.rewardName) code is \(claim.code). Find it anytime under My Rewards.")
            }
        }
    }

    private var balance: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                EyebrowText(text: "Your Balance")
                Text("\(rewards.points) pts")
                    .font(CoastFont.display(40))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(rewards.points)))
            }
            Spacer()
            Image("CoastLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 110)
                .accessibilityHidden(true)
        }
        .coastCard(cornerRadius: 22)
        .animation(.spring, value: rewards.points)
    }
}

private struct TierCard: View {
    let tier: RewardTier
    let points: Int
    let onRedeem: () -> Void

    var body: some View {
        let canRedeem = points >= tier.cost
        let progress = min(Double(points) / Double(tier.cost), 1)
        HStack(spacing: 14) {
            Image(systemName: tier.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(canRedeem ? .white : Theme.orange)
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(canRedeem ? AnyShapeStyle(Theme.orangeGradient) : AnyShapeStyle(Theme.orange.opacity(0.15)))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(canRedeem ? tier.detail : "\(tier.cost - points) more points to go")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(Theme.orange).frame(width: max(geo.size.width * progress, 4))
                    }
                }
                .frame(height: 4)
            }
            Spacer(minLength: 8)
            Button(action: onRedeem) {
                Text(canRedeem ? "Redeem" : "\(tier.cost)")
                    .font(CoastFont.condensed(16))
                    .foregroundStyle(canRedeem ? .white : Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 76, minHeight: 40)
                    .background(Capsule().fill(canRedeem ? AnyShapeStyle(Theme.orangeGradient) : AnyShapeStyle(Theme.surfaceRaised)))
            }
            .buttonStyle(PressableStyle())
            .disabled(!canRedeem)
            .accessibilityLabel(canRedeem ? "Redeem \(tier.name)" : "\(tier.cost) points needed")
        }
        .coastCard(cornerRadius: 20, padding: 14)
    }
}

private struct ClaimRow: View {
    let claim: RewardClaim

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(claim.rewardName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(claim.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(claim.code)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(Theme.orange)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }
}
