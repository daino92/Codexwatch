import Foundation
import UserNotifications

@MainActor
final class UsageNotificationManager {
    private let defaults = UserDefaults.standard

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func evaluate(_ limits: [UsageLimit], enabled: Bool) {
        guard enabled else { return }

        for limit in limits {
            evaluate(limit)
        }
    }

    func resetState() {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("notificationBand.") {
            defaults.removeObject(forKey: key)
        }
    }

    private func evaluate(_ limit: UsageLimit) {
        let currentBand = band(for: limit.remainingPercent)
        let key = storageKey(for: limit)
        let previousBand = defaults.integer(forKey: key)

        // Quota has reset/recovered. Allow future warnings again.
        if currentBand < previousBand {
            defaults.set(currentBand, forKey: key)
            return
        }

        guard currentBand > previousBand else {
            return
        }

        if currentBand == 1 {
            send(
                limit: limit,
                threshold: 20,
                critical: false
            )
        } else if currentBand == 2 {
            send(
                limit: limit,
                threshold: 5,
                critical: true
            )
        }

        defaults.set(currentBand, forKey: key)
    }

    private func band(for remaining: Double) -> Int {
        if remaining <= 5 {
            return 2
        }

        if remaining <= 20 {
            return 1
        }

        return 0
    }

    private func storageKey(for limit: UsageLimit) -> String {
        "notificationBand.\(limit.id)"
    }

    private func send(
        limit: UsageLimit,
        threshold: Int,
        critical: Bool
    ) {
        let content = UNMutableNotificationContent()

        content.title = critical
            ? "Codex quota almost exhausted"
            : "Codex quota running low"

        content.body =
            "\(limit.name): \(Int(limit.remainingPercent))% remaining."

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codexwatch-\(limit.id)-\(threshold)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
