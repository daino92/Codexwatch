import Foundation
import UserNotifications

@MainActor
final class UsageNotificationManager {
    private struct UsageSample {
        let remainingPercent: Double
        let date: Date
    }

    private let defaults = UserDefaults.standard
    private var sampleHistory: [String: [UsageSample]] = [:]

    private let rapidMinimumDropPercent = 2.0
    private let rapidMinimumRatePerMinute = 0.25
    private let rapidMultiplier = 2.0
    private let rapidCooldown: TimeInterval = 30 * 60
    private let historyWindow: TimeInterval = 15 * 60

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func evaluate(
        _ limits: [UsageLimit],
        enabled: Bool,
        rapidUsageEnabled: Bool
    ) {
        guard enabled else { return }

        for limit in limits {
            evaluateThresholds(for: limit)

            if rapidUsageEnabled {
                evaluateRapidUsage(for: limit)
            } else {
                sampleHistory[limit.id] = nil
            }
        }
    }

    func resetState() {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("notificationBand.") ||
            key.hasPrefix("rapidUsageNotification.") {
            defaults.removeObject(forKey: key)
        }

        sampleHistory.removeAll()
    }

    func resetRapidUsageState() {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("rapidUsageNotification.") {
            defaults.removeObject(forKey: key)
        }

        sampleHistory.removeAll()
    }

    private func evaluateThresholds(for limit: UsageLimit) {
        let currentBand = band(for: limit.remainingPercent)
        let key = "notificationBand.\(limit.id)"
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

    private func evaluateRapidUsage(for limit: UsageLimit) {
        let now = Date()
        var samples = sampleHistory[limit.id] ?? []

        if let previous = samples.last,
           limit.remainingPercent > previous.remainingPercent + 1 {
            samples.removeAll()
            clearRapidCooldown(for: limit)
        }

        samples.append(
            UsageSample(
                remainingPercent: limit.remainingPercent,
                date: now
            )
        )

        samples = samples.filter {
            now.timeIntervalSince($0.date) <= historyWindow
        }
        sampleHistory[limit.id] = samples

        guard samples.count >= 4,
              let latest = samples.last,
              let previous = samples.dropLast().last
        else {
            return
        }

        let currentDrop = previous.remainingPercent - latest.remainingPercent
        let elapsedMinutes = latest.date
            .timeIntervalSince(previous.date) / 60

        guard currentDrop >= rapidMinimumDropPercent,
              elapsedMinutes > 0
        else {
            return
        }

        let currentRate = currentDrop / elapsedMinutes
        let priorRates = zip(samples.dropLast(2), samples.dropFirst())
            .compactMap { earlier, later -> Double? in
                let drop = earlier.remainingPercent - later.remainingPercent
                let minutes = later.date
                    .timeIntervalSince(earlier.date) / 60

                guard drop > 0, minutes > 0 else {
                    return nil
                }

                return drop / minutes
            }

        guard let baselineRate = priorRates.average,
              currentRate >= rapidMinimumRatePerMinute,
              currentRate >= baselineRate * rapidMultiplier,
              rapidCooldownExpired(for: limit)
        else {
            return
        }

        let minutesToExhaustion = max(
            1,
            latest.remainingPercent / currentRate
        )

        sendRapidUsageNotification(
            limit: limit,
            dropPercent: currentDrop,
            minutesToExhaustion: minutesToExhaustion
        )
        defaults.set(
            Date().timeIntervalSince1970,
            forKey: rapidCooldownKey(for: limit)
        )
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

    private func rapidCooldownExpired(for limit: UsageLimit) -> Bool {
        let lastSent = defaults.double(
            forKey: rapidCooldownKey(for: limit)
        )

        return lastSent == 0 ||
            Date().timeIntervalSince1970 - lastSent >= rapidCooldown
    }

    private func clearRapidCooldown(for limit: UsageLimit) {
        defaults.removeObject(forKey: rapidCooldownKey(for: limit))
    }

    private func rapidCooldownKey(for limit: UsageLimit) -> String {
        "rapidUsageNotification.\(limit.id)"
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

    private func sendRapidUsageNotification(
        limit: UsageLimit,
        dropPercent: Double,
        minutesToExhaustion: Double
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Codex usage is accelerating"

        let roundedDrop = max(1, Int(dropPercent.rounded()))
        let roundedMinutes = max(1, Int(minutesToExhaustion.rounded()))

        content.body =
            "\(limit.name) used \(roundedDrop)% recently. " +
            "At this pace, the quota may run out in \(durationText(minutes: roundedMinutes))."

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codexwatch-rapid-\(limit.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func durationText(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return "\(hours)h"
            }

            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(minutes)m"
    }
}

private extension Collection where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
