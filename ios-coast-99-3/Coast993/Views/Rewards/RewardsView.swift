import SwiftUI

struct RewardsView: View {
    @Binding var selectedTab: AppTab
    @Environment(RewardsStore.self) private var rewards
    @State private var isCatalogPresented: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CoastHeader(height: 200, logoWidth: 220, logoBottomPadding: 14)

                VStack(spacing: 22) {
                    PointsGauge(points: rewards.points)
                        .padding(.top, -24)

                    VStack(spacing: 12) {
                        SectionTitle(title: "Ways to Earn Points")
                        VStack(spacing: 0) {
                            EarnRow(
                                icon: "music.note",
                                tint: Theme.orange,
                                title: "Music Test",
                                subtitle: rewards.hasEarnedMusicTestToday ? "Earned today — back tomorrow" : "Rate 10 songs, shape the playlist",
                                points: RewardRules.musicTest,
                                isDone: rewards.hasEarnedMusicTestToday
                            ) { selectedTab = .musicTest }

                            rowDivider

                            EarnRow(
                                icon: "headphones",
                                tint: Theme.blue,
                                title: "Daily Listen",
                                subtitle: rewards.hasEarnedDailyListenToday
                                    ? "Earned today — thanks for listening"
                                    : "\(rewards.listenMinutesToday) of 30 minutes today",
                                points: RewardRules.dailyListen,
                                isDone: rewards.hasEarnedDailyListenToday,
                                progress: rewards.hasEarnedDailyListenToday ? nil : rewards.listenProgress
                            ) { selectedTab = .live }

                            rowDivider

                            EarnRow(
                                icon: "trophy.fill",
                                tint: Theme.orange,
                                title: "Enter a Contest",
                                subtitle: "Participate for a chance to win",
                                points: RewardRules.contestEntry,
                                isDone: false
                            ) { selectedTab = .contests }
                        }
                        .coastCard(cornerRadius: 20, padding: 6)
                    }

                    Button {
                        isCatalogPresented = true
                    } label: {
                        PrimaryCapsuleLabel(title: "VIEW REWARDS", height: 58)
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AppBackground())
        .sheet(isPresented: $isCatalogPresented) {
            RewardsCatalogView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var rowDivider: some View {
        Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 72)
    }
}

private struct PointsGauge: View {
    let points: Int
    @State private var animatedProgress: Double = 0

    private let arcSpan: Double = 0.75
    private var progress: Double {
        min(Double(points) / Double(RewardRules.pointsPerReward), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.surface.opacity(0.95), Theme.canvas.opacity(0.9)], center: .center, startRadius: 10, endRadius: 150))
                .padding(10)

            Circle()
                .trim(from: 0, to: arcSpan)
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: arcSpan * max(animatedProgress, 0.01))
                .stroke(
                    LinearGradient(colors: [Theme.orangeDeep, Theme.orange, Color(hex: 0xFFB35C)], startPoint: .bottomLeading, endPoint: .topTrailing),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: Theme.orange.opacity(0.6), radius: 12)

            VStack(spacing: 2) {
                Text("\(points)")
                    .font(CoastFont.display(72))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(points)))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("points")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.blueSoft)
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 150, height: 1)
                    .padding(.vertical, 8)
                Text(points >= RewardRules.pointsPerReward ? "Reward ready to redeem!" : "\(RewardRules.pointsPerReward) points = $5 reward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(points >= RewardRules.pointsPerReward ? Theme.orange : Theme.textSecondary)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 280, height: 280)
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.15)) { animatedProgress = progress }
        }
        .onChange(of: points) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { animatedProgress = progress }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(points) points. \(RewardRules.pointsPerReward) points equals a 5 dollar reward.")
    }
}

private struct EarnRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let points: Int
    let isDone: Bool
    var progress: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(tint.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.08))
                                Capsule().fill(Theme.blue).frame(width: max(geo.size.width * progress, 4))
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Text("+\(points)")
                    .font(CoastFont.display(28))
                    .foregroundStyle(isDone ? Theme.textTertiary : Theme.orange)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
