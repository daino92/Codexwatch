import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isRegistered: Bool {
        status == .enabled || status == .requiresApproval
    }

    static var needsApproval: Bool { status == .requiresApproval }

    static var isInstalledInApplications: Bool {
        let appDirectory = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL.path

        return appDirectory == "/Applications" ||
            appDirectory == userApplications
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard isInstalledInApplications else {
                throw LaunchAtLoginError.applicationNotInstalled
            }

            if status == .notRegistered || status == .notFound {
                try SMAppService.mainApp.register()
            }
        } else {
            if isRegistered {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case applicationNotInstalled

    var errorDescription: String? {
        "Move CodexWatch to Applications before enabling Launch at Login."
    }
}
