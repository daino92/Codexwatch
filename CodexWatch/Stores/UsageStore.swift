import Foundation
import SwiftUI
import Combine

enum CodexConnectionStatus {
    case checking
    case connected
    case authenticationRequired
    case cliUnavailable
    case error

    var title: String {
        switch self {
        case .checking:
            return "Checking…"

        case .connected:
            return "Connected"

        case .authenticationRequired:
            return "Authentication required"

        case .cliUnavailable:
            return "Codex CLI unavailable"

        case .error:
            return "Connection error"
        }
    }

    var systemImage: String {
        switch self {
        case .checking:
            return "circle.dotted"

        case .connected:
            return "checkmark.circle.fill"

        case .authenticationRequired:
            return "person.crop.circle.badge.exclamationmark"

        case .cliUnavailable:
            return "terminal.fill"

        case .error:
            return "exclamationmark.circle.fill"
        }
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot = UsageSnapshot.empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var connectionStatus: CodexConnectionStatus = .checking

    @Published var launchAtLogin =
        LaunchAtLoginManager.isEnabled

    @Published var launchAtLoginError: String?
    @Published var notificationError: String?

    @AppStorage("refreshInterval")
    var refreshInterval: Double = 60

    @AppStorage("refreshOnOpen")
    var refreshOnOpen = true

    @AppStorage("menuDisplayMode")
    var menuDisplayMode =
        MenuDisplayMode.both.rawValue

    @AppStorage("quotaNotifications")
    var quotaNotifications = false

    private let service = CodexCLIService()
    private let notifications =
        UsageNotificationManager()

    private var timer: Timer?

    init() {
        configureTimer()

        Task {
            await refresh()
        }
    }

    func refresh() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        if snapshot.limits.isEmpty {
            connectionStatus = .checking
        }

        defer {
            isLoading = false
        }

        do {
            snapshot =
                try await service.fetchStatus()

            connectionStatus = .connected

            notifications.evaluate(
                snapshot.limits,
                enabled: quotaNotifications
            )
        } catch CodexCLIError.notFound {
            connectionStatus = .cliUnavailable
            errorMessage =
                CodexCLIError.notFound
                    .localizedDescription

        } catch CodexCLIError.authenticationRequired {
            connectionStatus =
                .authenticationRequired

            errorMessage =
                CodexCLIError
                    .authenticationRequired
                    .localizedDescription

        } catch {
            connectionStatus = .error
            errorMessage =
                error.localizedDescription
        }
    }

    func configureTimer() {
        timer?.invalidate()
        timer = nil

        guard refreshInterval > 0 else {
            return
        }

        timer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func setNotifications(
        _ enabled: Bool
    ) async {
        quotaNotifications = enabled
        notificationError = nil

        guard enabled else {
            notifications.resetState()
            return
        }

        do {
            guard
                try await notifications
                    .requestAuthorization()
            else {
                quotaNotifications = false
                notificationError =
                    "Notifications are disabled for CodexWatch in System Settings."
                return
            }

            notifications.evaluate(
                snapshot.limits,
                enabled: true
            )
        } catch {
            quotaNotifications = false
            notificationError =
                "Couldn’t enable notifications: \(error.localizedDescription)"
        }
    }

    func setLaunchAtLogin(
        _ enabled: Bool
    ) {
        launchAtLoginError = nil

        do {
            try LaunchAtLoginManager
                .setEnabled(enabled)

            launchAtLogin =
                LaunchAtLoginManager.isEnabled
        } catch {
            launchAtLogin =
                LaunchAtLoginManager.isEnabled

            launchAtLoginError =
                error.localizedDescription
        }
    }

    var menuTitle: String {
        let fiveHour =
            snapshot.limits.first {
                $0.name
                    .localizedCaseInsensitiveContains(
                        "5-hour"
                    ) ||
                $0.name
                    .localizedCaseInsensitiveContains(
                        "5h"
                    )
            }

        let weekly =
            snapshot.limits.first {
                $0.name
                    .localizedCaseInsensitiveContains(
                        "weekly"
                    ) &&
                !$0.name
                    .localizedCaseInsensitiveContains(
                        "luna"
                    )
            }

        let lunaReserve =
            snapshot.limits.first {
                $0.name
                    .localizedCaseInsensitiveContains(
                        "luna"
                    )
            }

        let mode =
            MenuDisplayMode(
                rawValue: menuDisplayMode
            ) ?? .both

        let activeWeeklyLimit: UsageLimit?
        let activeWeeklyPrefix: String

        if let weekly,
           weekly.remainingPercent <= 0,
           let lunaReserve,
           lunaReserve.remainingPercent > 0 {

            activeWeeklyLimit = lunaReserve
            activeWeeklyPrefix = "🌙 L"
        } else {
            activeWeeklyLimit = weekly
            activeWeeklyPrefix = "W"
        }

        switch mode {
        case .iconOnly:
            return "⌘"

        case .fiveHour:
            return fiveHour.map {
                "⌘ 5h \(Int($0.remainingPercent))%"
            } ?? "⌘ Codex"

        case .weekly:
            return activeWeeklyLimit.map {
                "⌘ \(activeWeeklyPrefix) \(Int($0.remainingPercent))%"
            } ?? "⌘ Codex"

        case .both:
            let parts = [
                fiveHour.map {
                    "5h \(Int($0.remainingPercent))%"
                },
                activeWeeklyLimit.map {
                    "\(activeWeeklyPrefix) \(Int($0.remainingPercent))%"
                }
            ]
            .compactMap { $0 }

            return parts.isEmpty
                ? "⌘ Codex"
                : "⌘ " +
                    parts.joined(
                        separator: " · "
                    )
        }
    }
}

enum MenuDisplayMode:
    String,
    CaseIterable,
    Identifiable {

    case both
    case fiveHour
    case weekly
    case iconOnly

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .both:
            return "5-hour + Weekly"

        case .fiveHour:
            return "5-hour only"

        case .weekly:
            return "Weekly only"

        case .iconOnly:
            return "Icon only"
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
                    resetAt: Date()
                        .addingTimeInterval(
                            2 * 60 * 60
                        )
                ),
                UsageLimit(
                    id: "weekly",
                    name: "Weekly limit",
                    remainingPercent: 18,
                    resetAt: Date()
                        .addingTimeInterval(
                            3 * 24 * 60 * 60
                        )
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
