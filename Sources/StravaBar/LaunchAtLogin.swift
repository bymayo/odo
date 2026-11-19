import Foundation

/// Launch-at-login via a per-user LaunchAgent. StravaBar runs as a bare executable
/// (not an .app bundle), so SMAppService isn't available.
enum LaunchAtLogin {
    private static let label = "uk.co.bymayo.stravabar"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
                throw NSError(domain: label, code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Couldn't find the StravaBar executable"])
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
                at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: plistURL, options: .atomic)
        } else if isEnabled {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
