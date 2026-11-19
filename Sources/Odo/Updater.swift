import Foundation
import Sparkle

/// Facts about how Odo is running
enum AppInfo {
    /// True when launched from Odo.app (Sparkle and SMAppService need a bundle);
    /// false for `swift run` / bare-executable dev builds
    static var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

/// Wrapper for Sparkle's SPUStandardUpdaterController (same shape as Cargo's SparkleUpdater).
/// Inert in dev builds, where there's no bundle, feed URL or public key.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    var isAvailable: Bool { controller != nil }

    private init() {
        guard AppInfo.isBundled else {
            controller = nil
            return
        }
        // startingUpdater: true begins scheduled checks per SUEnableAutomaticChecks
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastUpdateCheckDate)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            objectWillChange.send()
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set {
            objectWillChange.send()
            controller?.updater.automaticallyDownloadsUpdates = newValue
        }
    }
}
