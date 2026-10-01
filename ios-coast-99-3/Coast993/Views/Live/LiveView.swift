import SwiftUI

struct LiveView: View {
    @Binding var selectedTab: AppTab
    @Environment(RadioPlayer.self) private var radio
    @Environment(RewardsStore.self) private var rewards
    @Environment(ArtworkCache.self) private var artwork

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    CoastHeader(height: 270, logoWidth: 270, logoBottomPadding: 30)

                    VStack(spacing: 22) {
                        NowPlayingCard()
                            .padding(.top, -18)

                        PlayerControls()

                        recentlyPlayed

                        RewardsBanner(points: rewards.points) {
                            selectedTab = .musicTest
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await radio.refreshNowPlaying() }
            .navigationDestination(for: String.self) { _ in
                RecentlyPlayedView()
            }
        }
    }

    @ViewBuilder
    private var recentlyPlayed: some View {
        VStack(spacing: 12) {
            HStack {
                SectionTitle(title: "Recently Played")
                if radio.history.count > 3 {
                    NavigationLink(value: "history") {
                        HStack(spacing: 4) {
                            Text("See All")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blueSoft)
                        .fixedSize()
                    }
                }
            }

            if radio.history.isEmpty {
                Text("Songs will show up here as they air.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .coastCard(cornerRadius: 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(radio.history.prefix(3))) { track in
                        TrackRow(track: track)
                        if track.id != radio.history.prefix(3).last?.id {
                            Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 72)
                        }
                    }
                }
                .coastCard(cornerRadius: 18, padding: 6)
            }
        }
    }
}

private struct NowPlayingCard: View {
    @Environment(RadioPlayer.self) private var radio
    @Environment(ArtworkCache.self) private var artwork

    var body: some View {
        let track = radio.nowPlaying
        HStack(alignment: .center, spacing: 16) {
            ArtworkView(url: track.flatMap { artwork.url(for: $0) }, cornerRadius: 16)
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                EyebrowText(text: "Now Playing")
                Text(track?.title ?? "Coast 99.3")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                Text(track?.artist ?? "Savannah's Hip Hop, R&B & Throwbacks")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                HStack(alignment: .bottom) {
                    LiveBadge(isOnAir: radio.isStationOnline)
                    Spacer(minLength: 8)
                    EqualizerView(isActive: radio.status == .playing, barCount: 6, segments: 8)
                        .frame(width: 58, height: 36)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coastCard(cornerRadius: 24, padding: 14)
        .animation(.smooth, value: track?.id)
        .onChange(of: track?.searchTerm) { _, _ in
            if let track { artwork.resolve(track) }
        }
        .onAppear {
            if let track { artwork.resolve(track) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(track?.title ?? "Coast 99.3") by \(track?.artist ?? "Coast 99.3"), live")
    }
}

private struct PlayerControls: View {
    @Environment(RadioPlayer.self) private var radio
    @State private var tapCount: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                shareButton
                    .frame(maxWidth: .infinity)

                Button {
                    tapCount += 1
                    radio.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.orange.opacity(0.18))
                            .frame(width: 104, height: 104)
                            .scaleEffect(radio.status == .playing ? 1.08 : 0.9)
                            .animation(
                                radio.status == .playing
                                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                    : .default,
                                value: radio.status == .playing
                            )
                        Circle()
                            .fill(Theme.orangeGradient)
                            .frame(width: 84, height: 84)
                            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                            .shadow(color: Theme.orange.opacity(0.6), radius: 18, y: 6)
                        if radio.status == .connecting {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.large)
                        } else {
                            Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: radio.isPlaying ? 0 : 3)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 108, height: 108)
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
                .accessibilityLabel(radio.isPlaying ? "Pause live stream" : "Listen live")

                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("AirPlay")
            }

            Text(statusText)
                .font(CoastFont.condensedSemi(15))
                .tracking(1)
                .foregroundStyle(radio.status == .failed ? Theme.orange : Theme.textSecondary)
                .contentTransition(.opacity)
                .animation(.smooth, value: statusText)
        }
    }

    private var statusText: String {
        switch radio.status {
        case .idle: "TAP TO LISTEN LIVE"
        case .connecting: "TUNING IN…"
        case .playing:
            if let count = radio.listenerCount, count > 1 { "LIVE · \(count) LISTENING NOW" } else { "LIVE ON COAST 99.3" }
        case .failed: "STREAM UNAVAILABLE — TAP TO RETRY"
        }
    }

    private var shareButton: some View {
        let message: String = if let track = radio.nowPlaying {
            "I'm listening to \(track.title) by \(track.artist) on Coast 99.3 — Savannah's Hip Hop, R&B & Throwbacks"
        } else {
            "Listen to Coast 99.3 — Savannah's Hip Hop, R&B & Throwbacks"
        }
        return ShareLink(item: StationConfig.websiteURL, message: Text(message)) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.surfaceRaised.opacity(0.8)))
                .overlay(Circle().strokeBorder(Theme.border.opacity(0.6), lineWidth: 1))
        }
        .accessibilityLabel("Share what's playing")
    }
}

struct TrackRow: View {
    let track: Track
    @Environment(ArtworkCache.self) private var artwork

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: artwork.url(for: track), cornerRadius: 10)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let playedAt = track.playedAt {
                Text(playedAt, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .onAppear { artwork.resolve(track) }
        .accessibilityElement(children: .combine)
    }
}

private struct RewardsBanner: View {
    let points: Int
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.orange.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.orange)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(points) pts")
                    .font(CoastFont.display(24))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(points)))
                Text("Listen. Play. Get Rewarded.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            Button(action: action) {
                PrimaryCapsuleLabel(title: "Take the Music Test", height: 44)
                    .fixedSize()
            }
            .buttonStyle(PressableStyle())
        }
        .coastCard(cornerRadius: 20, padding: 12)
        .animation(.spring, value: points)
    }
}

struct RecentlyPlayedView: View {
    @Environment(RadioPlayer.self) private var radio

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(radio.history) { track in
                    TrackRow(track: track)
                    Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 72)
                }
            }
            .coastCard(cornerRadius: 18, padding: 6)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppBackground())
        .navigationTitle("Recently Played")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await radio.refreshNowPlaying() }
    }
}
