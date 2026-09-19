import Foundation

struct UsageLimit: Identifiable, Equatable {
    let id: String
    let name: String
    let remainingPercent: Double
    let resetText: String?
    let resetAt: Date?

    init(id: String, name: String, remainingPercent: Double, resetText: String? = nil, resetAt: Date? = nil) {
        self.id = id
        self.name = name
        self.remainingPercent = remainingPercent
        self.resetText = resetText
        self.resetAt = resetAt
    }

    var usedPercent: Double { max(0, 100 - remainingPercent) }
}

struct UsageSnapshot: Equatable {
    var limits: [UsageLimit] = []
    var credits: String?
    var model: String?
    var context: String?
    var plan: String?
    var rawOutput: String = ""
    var fetchedAt = Date()
    static let empty = UsageSnapshot()
}
