import Foundation

enum CodexStatusParser {
    static func parse(_ raw: String) -> UsageSnapshot {
        let clean = ANSI.strip(raw)
        let lines = clean.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var snapshot = UsageSnapshot(rawOutput: clean, fetchedAt: Date())
        var limits: [UsageLimit] = []

        for (index, line) in lines.enumerated() where !line.isEmpty {
            let lower = line.lowercased()
            if snapshot.model == nil, lower.hasPrefix("model:"), let value = valueAfterColon(line) {
                snapshot.model = value.components(separatedBy: " (").first
            }
            if snapshot.plan == nil, lower.hasPrefix("account:"), let value = valueAfterColon(line),
               let open = value.lastIndex(of: "("), let close = value.lastIndex(of: ")"), open < close {
                snapshot.plan = String(value[value.index(after: open)..<close])
            }
            if snapshot.credits == nil, lower.contains("credit"), let value = valueAfterColon(line) { snapshot.credits = value }
            if snapshot.context == nil, lower.hasPrefix("context window:"), let value = valueAfterColon(line) { snapshot.context = value }

            guard lower.contains("limit:"), let percent = firstPercent(in: line) else { continue }
            let remaining = lower.contains("left") || lower.contains("remaining") ? percent : 100 - percent
            var reset = extractReset(from: line)
            if reset == nil, index + 1 < lines.count {
                let next = lines[index + 1]
                if next.lowercased().contains("reset") { reset = extractReset(from: next) }
            }
            let name = displayName(from: line)
            let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
            if !limits.contains(where: { $0.id == id }) {
                limits.append(.init(id: id, name: name, remainingPercent: min(100, max(0, remaining)), resetText: reset))
            }
        }
        snapshot.limits = limits
        return snapshot
    }

    private static func firstPercent(in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,3}(?:\.\d+)?)\s*%"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }
    private static func valueAfterColon(_ line: String) -> String? {
        guard let idx = line.firstIndex(of: ":") else { return nil }
        let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
    private static func extractReset(from line: String) -> String? {
        let lower = line.lowercased()
        guard let range = lower.range(of: "reset") else { return nil }
        return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func displayName(from line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("luna reserve") { return "Luna Reserve Weekly" }
        if lower.contains("weekly") { return "Weekly" }
        if lower.contains("5h") || lower.contains("5-hour") || lower.contains("5 hour") { return "5-hour" }
        if let idx = line.firstIndex(of: ":") {
            let candidate = line[..<idx].trimmingCharacters(in: .whitespaces)
            if !candidate.isEmpty && candidate.count < 30 { return candidate }
        }
        return "Usage"
    }
}
