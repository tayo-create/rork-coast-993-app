import SwiftUI

struct ContestsView: View {
    @State private var viewModel: ContestsViewModel = ContestsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    CoastHeader(height: 210, logoWidth: 230, logoBottomPadding: 16)

                    VStack(spacing: 18) {
                        KeywordAlertCard()
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, -6)
                    .padding(.bottom, 28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Contest.self) { contest in
                ContestDetailView(contest: contest)
            }
            .task { await viewModel.load() }
            .refreshable {
                async let contests: Void = viewModel.load()
                async let keywords: Void = PushManager.shared.fetchKeywords()
                _ = await (contests, keywords)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading where viewModel.contests.isEmpty:
            ProgressView()
                .tint(Theme.orange)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 220)
        case .failed:
            StatusCard(
                icon: "wifi.exclamationmark",
                title: "Couldn't load contests",
                message: "Check your connection and try again.",
                actionTitle: "Try Again"
            ) {
                Task { await viewModel.load() }
            }
        default:
            if let featured = viewModel.featured {
                NavigationLink(value: featured) {
                    FeaturedContestCard(contest: featured)
                }
                .buttonStyle(PressableStyle(scale: 0.98))

                if !viewModel.others.isEmpty {
                    SectionTitle(title: "More Contests")
                        .padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(viewModel.others) { contest in
                            NavigationLink(value: contest) {
                                ContestRow(contest: contest)
                            }
                            .buttonStyle(PressableStyle(scale: 0.98))
                            if contest.id != viewModel.others.last?.id {
                                Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 90)
                            }
                        }
                    }
                    .coastCard(cornerRadius: 20, padding: 6)
                }

                howToWin
            } else {
                StatusCard(
                    icon: "trophy",
                    title: "No contests right now",
                    message: "New giveaways drop all the time. Keep it locked to Coast 99.3!"
                )
            }
        }
    }

    private var howToWin: some View {
        HStack(spacing: 14) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(RewardRules.contestEntry) points for every entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Enter contests to stack up Coast Rewards.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .coastCard(cornerRadius: 18, padding: 14)
    }
}

/// Contest photo using the Color-anchor + overlay pattern so fill images never break layout.
struct ContestImage: View {
    let contest: Contest

    var body: some View {
        Theme.surfaceRaised
            .overlay {
                Image(contest.localImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay {
                if let url = contest.remoteImageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct FeaturedContestCard: View {
    let contest: Contest

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ContestImage(contest: contest)
                .frame(width: 150, height: 196)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(Theme.orange))
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 8) {
                EyebrowText(text: "Featured Contest")
                Text(contest.displayTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text(contest.prize)
                    .font(.subheadline)
                    .foregroundStyle(Theme.blueSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(contest.endsLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                PrimaryCapsuleLabel(title: "Enter Now", height: 44)
            }
            .frame(maxHeight: 196)
        }
        .coastCard(cornerRadius: 24, padding: 12)
    }
}

private struct ContestRow: View {
    let contest: Contest
    @Environment(RewardsStore.self) private var rewards

    var body: some View {
        HStack(spacing: 14) {
            ContestImage(contest: contest)
                .frame(width: 68, height: 68)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(contest.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(contest.prize)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if rewards.hasEntered(contest.id) {
                    Label("Entered", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.orange)
                } else {
                    Text(contest.endsLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(8)
        .contentShape(Rectangle())
    }
}
