import SwiftUI

struct MusicTestView: View {
    @Binding var selectedTab: AppTab
    @Environment(RadioPlayer.self) private var radio
    @State private var viewModel: MusicTestViewModel = MusicTestViewModel()
    @State private var selectionTrigger: Int = 0
    @State private var submitTrigger: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CoastHeader(height: 210, logoWidth: 230, logoBottomPadding: 16)

                VStack(spacing: 14) {
                    if viewModel.isFinished {
                        MusicTestCompleteCard(
                            uploadState: viewModel.uploadState,
                            onRetry: { Task { await viewModel.uploadAnswers() } },
                            onKeepListening: { selectedTab = .live },
                            onRetake: { withAnimation(.smooth) { viewModel.restart() } }
                        )
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        progressCard
                        SongPreviewCard(viewModel: viewModel)
                        questions
                        actions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, -6)
                .padding(.bottom, 28)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(AppBackground())
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sensoryFeedback(.success, trigger: submitTrigger)
        .task {
            viewModel.onClipWillPlay = { [radio] in
                if radio.isPlaying { radio.stop() }
            }
            await viewModel.loadPreviews()
        }
        .onDisappear { viewModel.stopClip() }
        .onChange(of: radio.isPlaying) { _, isPlaying in
            if isPlaying { viewModel.stopClip() }
        }
    }

    private var progressCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SONG \(viewModel.index + 1) OF \(viewModel.songs.count)")
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(viewModel.progress * 100))% COMPLETE")
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }
            .font(CoastFont.condensed(16))
            .tracking(0.8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.orangeGradient)
                        .frame(width: max(geo.size.width * max(viewModel.progress, 0.04), 10))
                        .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                }
            }
            .frame(height: 10)
        }
        .coastCard(cornerRadius: 18, padding: 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.progress)
        .accessibilityElement(children: .combine)
    }

    private var questions: some View {
        let answer = viewModel.currentAnswer
        return VStack(spacing: 14) {
            QuestionGroup(number: 1, prompt: "How do you feel about this song?") {
                HStack(spacing: 6) {
                    ForEach(SongFeeling.allCases) { option in
                        OptionTile(
                            label: option.label,
                            isSelected: answer.feeling == option,
                            tint: option == .love ? Theme.orange : Theme.blueSoft
                        ) {
                            Image(systemName: option.icon)
                        } action: {
                            selectionTrigger += 1
                            viewModel.setFeeling(option)
                        }
                    }
                }
            }

            QuestionGroup(number: 2, prompt: "How familiar are you with this song?") {
                HStack(spacing: 6) {
                    ForEach(SongFamiliarity.allCases) { option in
                        OptionTile(label: option.label, isSelected: answer.familiarity == option, tint: Theme.blueSoft) {
                            Image(systemName: option.icon)
                        } action: {
                            selectionTrigger += 1
                            viewModel.setFamiliarity(option)
                        }
                    }
                }
            }

            QuestionGroup(number: 3, prompt: "How often should Coast play it?") {
                HStack(spacing: 6) {
                    ForEach(SongFrequency.allCases) { option in
                        OptionTile(label: option.label, isSelected: answer.frequency == option, tint: Theme.blueSoft) {
                            Image(systemName: option == .never ? "speaker.slash.fill" : "dot.radiowaves.left.and.right", variableValue: option.waves)
                        } action: {
                            selectionTrigger += 1
                            viewModel.setFrequency(option)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: answer)
    }

    private var actions: some View {
        let isComplete = viewModel.currentAnswer.isComplete
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.smooth) { viewModel.previous() }
                } label: {
                    NavCapsuleLabel(title: "BACK", systemImage: "chevron.left", leading: true)
                }
                .buttonStyle(PressableStyle())
                .disabled(!viewModel.canGoBack)
                .opacity(viewModel.canGoBack ? 1 : 0.4)
                .accessibilityLabel("Previous song")

                Button {
                    submitTrigger += 1
                    withAnimation(.smooth) {
                        viewModel.submit()
                    }
                } label: {
                    PrimaryCapsuleLabel(title: "SUBMIT MY ANSWERS", systemImage: nil, height: 52, isEnabled: isComplete)
                }
                .buttonStyle(PressableStyle())
                .disabled(!isComplete)

                Button {
                    withAnimation(.smooth) { viewModel.next() }
                } label: {
                    NavCapsuleLabel(title: "NEXT", systemImage: "chevron.right", leading: false)
                }
                .buttonStyle(PressableStyle())
                .disabled(!viewModel.canGoForward)
                .opacity(viewModel.canGoForward ? 1 : 0.4)
                .accessibilityLabel("Next song")
            }

            Text(viewModel.currentAnswer.isSubmitted ? "Answers saved — update and resubmit anytime." : isComplete ? "Ready when you are." : "Answer all 3 questions to submit.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }
}

private struct NavCapsuleLabel: View {
    let title: String
    let systemImage: String
    let leading: Bool

    var body: some View {
        HStack(spacing: 4) {
            if leading { Image(systemName: systemImage).font(.system(size: 13, weight: .bold)) }
            Text(title)
                .font(CoastFont.condensed(17))
            if !leading { Image(systemName: systemImage).font(.system(size: 13, weight: .bold)) }
        }
        .foregroundStyle(.white)
        .frame(width: 84, height: 52)
        .background(Capsule().fill(Theme.surfaceRaised))
        .overlay(Capsule().strokeBorder(Theme.blue.opacity(0.5), lineWidth: 1))
    }
}

private struct SongPreviewCard: View {
    let viewModel: MusicTestViewModel

    var body: some View {
        let song = viewModel.current
        HStack(alignment: .top, spacing: 14) {
            ArtworkView(url: viewModel.artworkURL(for: song), cornerRadius: 14)
                .frame(width: 118, height: 118)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                .id(song.id)

            VStack(alignment: .leading, spacing: 4) {
                EyebrowText(text: song.artist, color: Theme.textSecondary)
                Text(song.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(viewModel.clipError ?? "Preview a 15-Second Clip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.orange)

                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleClip()
                    } label: {
                        Image(systemName: viewModel.isClipPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: viewModel.isClipPlaying ? 0 : 2)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Theme.orangeGradient))
                            .shadow(color: Theme.orange.opacity(0.5), radius: 8, y: 3)
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                    .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isClipPlaying)
                    .accessibilityLabel(viewModel.isClipPlaying ? "Pause clip" : "Play 15 second clip")

                    VStack(spacing: 4) {
                        WaveformView(progress: viewModel.clipProgress, barCount: 30)
                            .frame(height: 24)
                        HStack {
                            Text(viewModel.clipElapsedLabel)
                            Spacer()
                            Text("0:15")
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .coastCard(cornerRadius: 22, padding: 14)
        .animation(.smooth, value: song.id)
    }
}

private struct QuestionGroup<Content: View>: View {
    let number: Int
    let prompt: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(CoastFont.condensed(15))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.blue))
                Text(prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

private struct OptionTile<Icon: View>: View {
    let label: String
    let isSelected: Bool
    let tint: Color
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(isSelected ? AnyShapeStyle(Theme.orangeGradient) : AnyShapeStyle(Theme.blue.opacity(0.16)))
                    )
                    .scaleEffect(isSelected ? 1.08 : 1)
                Text(label)
                    .font(CoastFont.condensed(13, relativeTo: .caption))
                    .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.orange.opacity(0.14) : Theme.surface.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.orange : Theme.border.opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Theme.orange.opacity(0.3) : .clear, radius: 10)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(label.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MusicTestCompleteCard: View {
    let uploadState: MusicTestViewModel.UploadState
    let onRetry: () -> Void
    let onKeepListening: () -> Void
    let onRetake: () -> Void
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.16))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.6)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.orangeGradient)
                    .symbolEffect(.bounce, value: appeared)
            }

            Text("TEST COMPLETE!")
                .font(CoastFont.display(34))
                .foregroundStyle(.white)

            Text("Thanks for helping decide what plays on Coast 99.3.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            uploadStatus

            Button(action: onKeepListening) {
                PrimaryCapsuleLabel(title: "KEEP LISTENING LIVE")
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)

            Button("Retake the Music Test", action: onRetake)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.blueSoft)
                .frame(minHeight: 44)
        }
        .padding(.vertical, 12)
        .coastCard(cornerRadius: 26, padding: 20)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }

    @ViewBuilder
    private var uploadStatus: some View {
        switch uploadState {
        case .sending:
            Label("Sending your answers to Coast 99.3…", systemImage: "arrow.up.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        case .failed:
            Button(action: onRetry) {
                Label("Couldn't send your answers. Tap to retry.", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.orange)
                    .frame(minHeight: 44)
            }
        case .idle, .sent:
            Label("Your answers were sent to the station.", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.blueSoft)
        }
    }
}
