import Foundation

enum CodexRateLimitsParser {
    static func parse(_ result: [String: Any]) -> UsageSnapshot {
        var snapshot = UsageSnapshot(rawOutput: "app-server account/rateLimits/read", fetchedAt: Date())
        var buckets: [[String: Any]] = []
        if let byId = result["rateLimitsByLimitId"] as? [String: Any] {
            // Put ordinary Codex first, then reserve/model-specific buckets.
            if let codex = byId["codex"] as? [String: Any] { buckets.append(codex) }
            for key in byId.keys.sorted() where key != "codex" { if let b = byId[key] as? [String: Any] { buckets.append(b) } }
        } else if let aggregate = result["rateLimits"] as? [String: Any] { buckets = [aggregate] }

        var limits: [UsageLimit] = []
        for bucket in buckets {
            let id = (bucket["limitId"] as? String) ?? "codex"
            let limitName = bucket["limitName"] as? String
            let normalModel = bucket["normalModelSlug"] as? String
            if snapshot.plan == nil { snapshot.plan = bucket["planType"] as? String }
            if snapshot.credits == nil, let credits = bucket["credits"] as? [String: Any], let balance = credits["balance"] { snapshot.credits = String(describing: balance) }
            for key in ["primary", "secondary"] {
                guard let window = bucket[key] as? [String: Any], let used = number(window["usedPercent"]) else { continue }
                let mins = Int(number(window["windowDurationMins"]) ?? 0)
                let name = displayName(id: id, limitName: limitName, model: normalModel, minutes: mins, existing: limits)
                let resetAt = resetDate(window["resetsAt"])
                let reset = resetAt.map { "Resets " + $0.formatted(.dateTime.day().month(.abbreviated).hour().minute()) }
                let unique = "\(id)-\(mins)-\(key)"
                limits.append(UsageLimit(id: unique, name: name, remainingPercent: max(0, min(100, 100-used)), resetText: reset, resetAt: resetAt))
            }
        }
        snapshot.limits = limits
        return snapshot
    }

    private static func displayName(id: String, limitName: String?, model: String?, minutes: Int, existing: [UsageLimit]) -> String {
        let reserve = id.lowercased().contains("reserve") || id == "base_model_inference" || (limitName?.lowercased().contains("reserve") ?? false)
        if reserve { return model.map { "Luna Reserve (\($0))" } ?? "Luna Reserve" }
        if id == "codex" {
            if minutes == 300 { return "5-hour" }
            if minutes == 10080 { return "Weekly" }
            if existing.contains(where: { $0.name == "5-hour" }) { return "Weekly" }
            return minutes > 0 ? formatDuration(minutes) : "Codex"
        }
        return limitName ?? model ?? id
    }
    private static func formatDuration(_ minutes: Int) -> String { minutes == 10080 ? "Weekly" : minutes == 300 ? "5-hour" : "\(minutes) min" }
    private static func number(_ value: Any?) -> Double? { if let d = value as? Double { return d }; if let i = value as? Int { return Double(i) }; if let n = value as? NSNumber { return n.doubleValue }; return nil }
    private static func resetDate(_ value: Any?) -> Date? {
        guard let seconds = number(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
