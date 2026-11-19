import Foundation

/// One-time migration from the app's old name (StravaBar) to Odo:
/// settings & Strava login, the activity cache, and the launch-at-login agent.
enum LegacyMigration {
    private static let oldName = "StravaBar"
    private static let oldAgentLabel = "uk.co.bymayo.stravabar"
    private static let doneKey = "migrated_from_stravabar"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }

        // 1. Settings + tokens: an unbundled executable's defaults domain is its name
        if let old = defaults.persistentDomain(forName: oldName) {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        // 2. Activity cache folder
        let fm = FileManager.default
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let oldDir = support.appendingPathComponent(oldName, isDirectory: true)
            let newDir = support.appendingPathComponent("Odo", isDirectory: true)
            if fm.fileExists(atPath: oldDir.path) && !fm.fileExists(atPath: newDir.path) {
                try? fm.moveItem(at: oldDir, to: newDir)
            }
        }

        // 3. Launch-at-login agent: replace the old one with one pointing at Odo
        let oldAgent = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(oldAgentLabel).plist")
        if fm.fileExists(atPath: oldAgent.path) {
            try? fm.removeItem(at: oldAgent)
            try? LaunchAtLogin.setEnabled(true)
        }

        defaults.set(true, forKey: doneKey)
    }
}
