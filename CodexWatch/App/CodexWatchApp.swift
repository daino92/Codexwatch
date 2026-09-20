import SwiftUI

@main
struct CodexWatchApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        menuText
            .accessibilityLabel(store.menuTitle)
    }

    private var menuText: Text {
        let fiveHour = store.snapshot.limits.first {
            $0.name.localizedCaseInsensitiveContains("5-hour") ||
                $0.name.localizedCaseInsensitiveContains("5h")
        }

        let weekly = store.snapshot.limits.first {
            $0.name.localizedCaseInsensitiveContains("weekly") &&
                !$0.name.localizedCaseInsensitiveContains("luna")
        }

        let lunaReserve = store.snapshot.limits.first {
            $0.name.localizedCaseInsensitiveContains("luna")
        }

        let mode = MenuDisplayMode(rawValue: store.menuDisplayMode) ?? .both
        let icon = Text("⌘ ").foregroundColor(.white)

        // When regular weekly is exhausted and Luna Reserve is available,
        // show Luna instead of the exhausted weekly quota.
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
            return Text("⌘").foregroundColor(.white)

        case .fiveHour:
            return icon +
                (fiveHour.map { quotaText(prefix: "5h", limit: $0) } ?? fallbackText)

        case .weekly:
            return icon +
                (activeWeeklyLimit.map {
                    quotaText(prefix: activeWeeklyPrefix, limit: $0)
                } ?? fallbackText)

        case .both:
            guard fiveHour != nil || activeWeeklyLimit != nil else {
                return icon + fallbackText
            }

            var text = icon

            if let fiveHour {
                text = text + quotaText(prefix: "5h", limit: fiveHour)
            }

            if fiveHour != nil && activeWeeklyLimit != nil {
                text = text + Text(" · ").foregroundColor(.white)
            }

            if let activeWeeklyLimit {
                text = text + quotaText(
                    prefix: activeWeeklyPrefix,
                    limit: activeWeeklyLimit
                )
            }

            return text
        }
    }

    private var fallbackText: Text {
        Text("Codex").foregroundColor(.white)
    }

    private func quotaText(prefix: String, limit: UsageLimit) -> Text {
        Text(prefix)
            .foregroundColor(.white) +
            Text(" \(Int(limit.remainingPercent))%")
                .foregroundColor(color(for: limit.remainingPercent))
    }

    private func color(for remaining: Double) -> Color {
        if remaining <= 5 { return .red }
        if remaining <= 20 { return .orange }
        return .white
    }
}
