import SwiftUI

/// Signed-in account sheet: profile, sync status, keyword alert settings, sign out / delete.
struct AccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(RewardsStore.self) private var rewards
    @Environment(PushManager.self) private var push
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var isConfirmingSignOut: Bool = false
    @State private var isConfirmingDelete: Bool = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    alertsCard
                    accountActions
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("My Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.orange)
                }
            }
            .task { await push.refreshPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await push.refreshPermission() } }
            }
            .confirmationDialog("Sign out of Coast Rewards?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your points stay safe in your account. Log back in anytime to see them.")
            }
            .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Account & Points", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases your points, reward codes and history. This can't be undone.")
            }
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Text(auth.user?.initials ?? "C")
                    .font(CoastFont.display(26))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.orangeGradient))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: Theme.orange.opacity(0.4), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.user?.displayName ?? "Coast Listener")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let email = auth.user?.email, !email.isEmpty {
                        Text(email)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            Divider().overlay(Theme.border.opacity(0.4))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowText(text: "Coast Rewards")
                    Text("\(rewards.points) pts")
                        .font(CoastFont.display(34))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(rewards.points)))
                }
                Spacer()
                SyncBadge(status: rewards.syncStatus) {
                    Task { await rewards.syncNow() }
                }
            }
        }
        .coastCard(cornerRadius: 24)
        .animation(.spring, value: rewards.points)
    }

    // MARK: - Alerts

    private var alertsCard: some View {
        @Bindable var push = push
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.orange.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyword Alerts")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(alertsSubtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                switch push.permission {
                case .authorized:
                    Toggle("Keyword Alerts", isOn: $push.alertsEnabled)
                        .labelsHidden()
                        .tint(Theme.orange)
                case .denied:
                    Button("Settings") { push.openSystemSettings() }
                        .font(CoastFont.condensed(16))
                        .foregroundStyle(Theme.orange)
                        .frame(minHeight: 44)
                case .notDetermined, .unknown:
                    Button("Turn On") {
                        Task { await push.requestPermission() }
                    }
                    .font(CoastFont.condensed(16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Capsule().fill(Theme.orangeGradient))
                    .buttonStyle(PressableStyle())
                }
            }

            if let latest = push.latestKeyword {
                HStack {
                    Text("Last keyword")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(latest.keyword)
                        .font(CoastFont.condensed(17))
                        .tracking(1)
                        .foregroundStyle(Theme.orange)
                    Text(latest.createdDate, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .coastCard(cornerRadius: 20)
    }

    private var alertsSubtitle: String {
        switch push.permission {
        case .authorized:
            return push.alertsEnabled ? "You'll get every contest keyword the moment it's announced." : "Alerts are paused on this phone."
        case .denied:
            return "Notifications are off for Coast 99.3. Turn them on in Settings."
        case .notDetermined, .unknown:
            return "Get pinged the second a contest keyword drops."
        }
    }

    // MARK: - Actions

    private var accountActions: some View {
        VStack(spacing: 0) {
            Button {
                isConfirmingSignOut = true
            } label: {
                actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", color: .white)
            }
            .buttonStyle(PressableStyle(scale: 0.98))

            Divider().overlay(Theme.border.opacity(0.4)).padding(.leading, 52)

            Button {
                isConfirmingDelete = true
            } label: {
                actionRow(icon: "trash", title: isDeleting ? "Deleting…" : "Delete Account", color: Theme.red)
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .disabled(isDeleting)
        }
        .coastCard(cornerRadius: 20, padding: 6)
    }

    private func actionRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func signOut() {
        rewards.detach()
        auth.signOut()
        Task { await push.registerWithBackend() }
        dismiss()
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            let token = await auth.validAccessToken()
            _ = try await BackendClient.send("account", method: "DELETE", token: token, as: OKResponse.self)
            signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SyncBadge: View {
    let status: RewardsStore.SyncStatus
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            HStack(spacing: 6) {
                icon
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Capsule().fill(color.opacity(0.14)))
        }
        .buttonStyle(PressableStyle())
        .disabled(status == .syncing)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .syncing:
            ProgressView().controlSize(.mini).tint(color)
        case .failed:
            Image(systemName: "arrow.clockwise")
        default:
            Image(systemName: "checkmark.icloud.fill")
        }
    }

    private var label: String {
        switch status {
        case .syncing: return "Syncing"
        case .failed: return "Tap to retry"
        case .synced: return "Synced"
        case .localOnly: return "On this phone"
        }
    }

    private var color: Color {
        switch status {
        case .failed: return Theme.orange
        case .synced: return Theme.blueSoft
        default: return Theme.textSecondary
        }
    }
}
