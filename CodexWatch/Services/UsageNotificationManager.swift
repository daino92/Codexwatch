import Foundation
import UserNotifications

@MainActor
final class UsageNotificationManager {
    private var lastBand: [String: Int] = [:]

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func evaluate(_ limits: [UsageLimit], enabled: Bool) {
        guard enabled else { lastBand.removeAll(); return }
        for limit in limits {
            let band = limit.remainingPercent <= 5 ? 2 : (limit.remainingPercent <= 20 ? 1 : 0)
            let previous = lastBand[limit.id] ?? 0
            if band > previous && band > 0 { send(limit: limit, critical: band == 2) }
            lastBand[limit.id] = band
        }
    }

    private func send(limit: UsageLimit, critical: Bool) {
        let content = UNMutableNotificationContent()
        content.title = critical ? "Codex quota almost exhausted" : "Codex quota running low"
        content.body = "\(limit.name): \(Int(limit.remainingPercent))% remaining."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "codexwatch-\(limit.id)-\(critical ? 5 : 20)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
