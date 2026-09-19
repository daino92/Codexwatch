import Foundation

enum CodexCLIError: LocalizedError {
    case notFound, empty, timedOut
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .notFound: return "Codex CLI was not found."
        case .empty: return "Codex app-server returned no usage data."
        case .timedOut: return "Codex app-server timed out."
        case .failed(let text): return "Codex status failed: \(text)"
        }
    }
}

actor CodexCLIService {
    func fetchStatus() async throws -> UsageSnapshot {
        guard let codex = findCodex() else { throw CodexCLIError.notFound }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process(); let input = Pipe(); let output = Pipe(); let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: codex)

            // GUI apps launched from Finder/Login Items do not inherit the user's
            // interactive shell PATH. Codex installed through NVM uses `env node`,
            // so make the directory containing codex/node available explicitly.
            var environment = ProcessInfo.processInfo.environment
            let codexBin = URL(fileURLWithPath: codex).deletingLastPathComponent().path
            let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            environment["PATH"] = codexBin + ":" + existingPath
            process.environment = environment

            process.arguments = ["app-server", "--stdio"]
            process.standardInput = input; process.standardOutput = output; process.standardError = errors

            let lock = NSLock(); var finished = false
            func finish(_ result: Result<UsageSnapshot, Error>) {
                lock.lock(); defer { lock.unlock() }; guard !finished else { return }; finished = true
                if process.isRunning { process.terminate() }
                continuation.resume(with: result)
            }
            do { try process.run() } catch { finish(.failure(CodexCLIError.failed(error.localizedDescription))); return }

            let initialize = #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"codexwatch","title":"CodexWatch","version":"0.6.0"},"capabilities":{"experimentalApi":true}}}"#
            let initialized = #"{"method":"initialized","params":{}}"#
            let rateLimits = #"{"method":"account/rateLimits/read","id":2,"params":{"supportsLunaReserve":true}}"#
            let payload = initialize + "\n" + initialized + "\n" + rateLimits + "\n"
            input.fileHandleForWriting.write(Data(payload.utf8))

            DispatchQueue.global(qos: .userInitiated).async {
                var buffer = Data()
                let handle = output.fileHandleForReading
                while process.isRunning {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    while let newline = buffer.firstIndex(of: 0x0A) {
                        let lineData = buffer.prefix(upTo: newline); buffer.removeSubrange(...newline)
                        guard let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                              let id = object["id"] as? Int, id == 2 else { continue }
                        if let error = object["error"] { finish(.failure(CodexCLIError.failed(String(describing: error)))); return }
                        guard let result = object["result"] as? [String: Any] else { finish(.failure(CodexCLIError.empty)); return }
                        let snapshot = CodexRateLimitsParser.parse(result)
                        if snapshot.limits.isEmpty { finish(.failure(CodexCLIError.failed("No rate-limit windows were returned."))) }
                        else { finish(.success(snapshot)) }
                        return
                    }
                }
                if !finished {
                    let err = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    finish(.failure(CodexCLIError.failed(err.isEmpty ? "app-server exited before replying." : err)))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { if !finished { finish(.failure(CodexCLIError.timedOut)) } }
        }
    }

    private func findCodex() -> String? {
        let fm = FileManager.default, home = fm.homeDirectoryForCurrentUser.path
        var candidates = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex", "\(home)/.npm-global/bin/codex", "\(home)/.volta/bin/codex", "\(home)/.codex/packages/standalone/current/bin/codex"]
        if let path = ProcessInfo.processInfo.environment["PATH"] { candidates += path.split(separator: ":").map { "\($0)/codex" } }
        let nvm = "\(home)/.nvm/versions/node"
        if let versions = try? fm.contentsOfDirectory(atPath: nvm) { candidates.insert(contentsOf: versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }.map { "\(nvm)/\($0)/bin/codex" }, at: 0) }
        return candidates.first(where: fm.isExecutableFile(atPath:))
    }
}
