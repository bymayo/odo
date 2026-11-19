import Foundation

/// One-time migration of settings, cache and launch-at-login from earlier builds:
/// - "StravaBar": the app's old name (bare executable, defaults domain "StravaBar")
/// - "Odo": the bare-executable dev build (defaults domain "Odo")
/// Odo.app's own domain is its bundle ID, so both are copied in, newest first.
enum LegacyMigration {
    private static let doneKey = "migrated_legacy_v2"
    private static let oldDomains = ["Odo", "StravaBar"]
    private static let oldAgentLabels = ["uk.co.bymayo.stravabar"]

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        let fm = FileManager.default

        // 1. Settings + Strava login: fill anything not already set
        for domain in oldDomains where domain != Bundle.main.bundleIdentifier {
            guard let old = defaults.persistentDomain(forName: domain) else { continue }
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        // 2. Activity cache folder (StravaBar -> Odo)
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let oldDir = support.appendingPathComponent("StravaBar", isDirectory: true)
            let newDir = support.appendingPathComponent("Odo", isDirectory: true)
            if fm.fileExists(atPath: oldDir.path) && !fm.fileExists(atPath: newDir.path) {
                try? fm.moveItem(at: oldDir, to: newDir)
            }
        }

        // 3. Launch at login: retire old LaunchAgents and re-enable the current way
        var wasEnabled = false
        let agentsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        for label in oldAgentLabels {
            let url = agentsDir.appendingPathComponent("\(label).plist")
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                wasEnabled = true
            }
        }
        // The dev build's agent, when we're now running as Odo.app
        if AppInfo.isBundled, fm.fileExists(atPath: LaunchAtLogin.agentURL.path) {
            try? fm.removeItem(at: LaunchAtLogin.agentURL)
            wasEnabled = true
        }
        if wasEnabled {
            try? LaunchAtLogin.setEnabled(true)
        }

        defaults.set(true, forKey: doneKey)
    }
}
