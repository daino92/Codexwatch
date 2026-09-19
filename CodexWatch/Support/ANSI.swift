import Foundation

enum ANSI {
    static func strip(_ input: String) -> String {
        let pattern = #"\u{001B}(?:\[[0-?]*[ -/]*[@-~]|\][^\u{0007}]*(?:\u{0007}|\u{001B}\\))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
            .replacingOccurrences(of: "\r", with: "")
    }
}
