import SwiftUI

struct ContestDetailView: View {
    let contest: Contest
    @Environment(RewardsStore.self) private var rewards
    @State private var safariURL: URL?
    @State private var entryTrigger: Int = 0

    var body: some View {
        let hasEntered = rewards.hasEntered(contest.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ContestImage(contest: contest)
                    .frame(height: 300)
                    .overlay {
                        LinearGradient(
                            colors: [Theme.canvas.opacity(0.5), .clear, Theme.canvas],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(alignment: .leading, spacing: 16) {
                    EyebrowText(text: contest.endsLabel)
                    Text(contest.displayTitle)
                        .font(CoastFont.display(34))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.orange)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.orange.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("THE PRIZE")
                                .font(CoastFont.condensed(13))
                                .tracking(1)
                                .foregroundStyle(Theme.textSecondary)
                            Text(contest.prize)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .coastCard(cornerRadius: 18, padding: 14)

                    if !contest.description.isEmpty {
                        Text(contest.description)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !contest.rules.isEmpty {
                        DisclosureGroup {
                            Text(contest.rules)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } label: {
                            Label("Official Rules", systemImage: "doc.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .tint(Theme.blueSoft)
                        .coastCard(cornerRadius: 18, padding: 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, -30)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    entryTrigger += 1
                    rewards.recordContestEntry(contest)
                    safariURL = contest.entryURL
                } label: {
                    PrimaryCapsuleLabel(
                        title: hasEntered ? "Open Contest Page" : "Enter Now · +\(RewardRules.contestEntry) pts",
                        systemImage: "arrow.up.right"
                    )
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.success, trigger: entryTrigger)

                Text(hasEntered ? "You've entered — good luck!" : "Complete your entry on coast993.com")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
