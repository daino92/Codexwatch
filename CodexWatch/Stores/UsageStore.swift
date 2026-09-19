import Foundation
import SwiftUI
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot = UsageSnapshot.empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var launchAtLogin = LaunchAtLoginManager.isEnabled
    @Published var launchAtLoginError: String?
    @Published var notificationError: String?
    @AppStorage("refreshInterval") var refreshInterval: Double = 60
    @AppStorage("refreshOnOpen") var refreshOnOpen = true
    @AppStorage("menuDisplayMode") var menuDisplayMode = MenuDisplayMode.both.rawValue
    @AppStorage("quotaNotifications") var quotaNotifications = false

    private let service = CodexCLIService()
    private let notifications = UsageNotificationManager()
    private var timer: Timer?

    init() { configureTimer(); Task { await refresh() } }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            snapshot = try await service.fetchStatus()
            notifications.evaluate(snapshot.limits, enabled: quotaNotifications)
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func configureTimer() {
        timer?.invalidate(); timer = nil
        guard refreshInterval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func setNotifications(_ enabled: Bool) async {
        quotaNotifications = enabled
        notificationError = nil

        guard enabled else {
            notifications.resetState()
            return
        }

        do {
            guard try await notifications.requestAuthorization() else {
                quotaNotifications = false
                notificationError = "Notifications are disabled for CodexWatch in System Settings."
                return
            }
            notifications.evaluate(snapshot.limits, enabled: true)
        } catch {
            quotaNotifications = false
            notificationError = "Couldn’t enable notifications: \(error.localizedDescription)"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLogin = LaunchAtLoginManager.isEnabled
        } catch {
            launchAtLogin = LaunchAtLoginManager.isEnabled
            launchAtLoginError = error.localizedDescription
        }
    }

    var menuTitle: String {
        let fiveHour = snapshot.limits.first { $0.name.localizedCaseInsensitiveContains("5-hour") || $0.name.localizedCaseInsensitiveContains("5h") }
        let weekly = snapshot.limits.first { $0.name.localizedCaseInsensitiveContains("weekly") && !$0.name.localizedCaseInsensitiveContains("luna") }
        let mode = MenuDisplayMode(rawValue: menuDisplayMode) ?? .both
        switch mode {
        case .iconOnly: return "⌘"
        case .fiveHour: return fiveHour.map { "⌘ 5h \(Int($0.remainingPercent))%" } ?? "⌘ Codex"
        case .weekly: return weekly.map { "⌘ W \(Int($0.remainingPercent))%" } ?? "⌘ Codex"
        case .both:
            let parts = [fiveHour.map { "5h \(Int($0.remainingPercent))%" }, weekly.map { "W \(Int($0.remainingPercent))%" }].compactMap { $0 }
            return parts.isEmpty ? "⌘ Codex" : "⌘ " + parts.joined(separator: " · ")
        }
    }
}

enum MenuDisplayMode: String, CaseIterable, Identifiable {
    case both, fiveHour, weekly, iconOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .both: return "5-hour + Weekly"
        case .fiveHour: return "5-hour only"
        case .weekly: return "Weekly only"
        case .iconOnly: return "Icon only"
        }
    }
}
#Preview {
    let store: UsageStore = {
        let store = UsageStore()
        store.snapshot = UsageSnapshot(
            limits: [
                UsageLimit(
                    id: "five-hour",
                    name: "5-hour limit",
                    remainingPercent: 72,
                    resetAt: Date().addingTimeInterval(2 * 60 * 60)
                ),
                UsageLimit(
                    id: "weekly",
                    name: "Weekly limit",
                    remainingPercent: 18,
                    resetAt: Date().addingTimeInterval(3 * 24 * 60 * 60)
                )
            ],
            credits: "$12.40",
            model: "GPT-5",
            context: "64% available",
            plan: "Pro",
            fetchedAt: Date()
        )
        return store
    }()

    UsagePopoverView(store: store)
}

