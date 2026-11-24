import Foundation
import ServiceManagement

/// Launch at login. Odo.app uses SMAppService (shows under Login Items in
/// System Settings); dev builds run as a bare executable, so they fall back
/// to a per-user LaunchAgent.
enum LaunchAtLogin {
    static let label = "uk.co.bymayo.odo"

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        if AppInfo.isPreview { return false }
        if AppInfo.isBundled {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if AppInfo.isPreview {
            throw NSError(domain: label, code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Launch at login is set in the installed Odo, not the preview build"])
        }
        if AppInfo.isBundled {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }

        if enabled {
            guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
                throw NSError(domain: label, code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Couldn't find the Odo executable"])
            }
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive",
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: agentURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }
}
