import AppKit
import Combine
import Sparkle

/// "Check for Updates" via Sparkle. Updates are signed with Recall's EdDSA key (SUPublicEDKey) and
/// Sparkle refuses anything not signed with it. Automatic checks are off until the user turns them on
/// in Settings → General, so Recall Free stays silent on the network unless asked.
@MainActor
final class Updates: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = Updates()

    private var controller: SPUStandardUpdaterController!
    @Published var automaticChecks = false {
        didSet { if updater.automaticallyChecksForUpdates != automaticChecks { updater.automaticallyChecksForUpdates = automaticChecks } }
    }

    private var updater: SPUUpdater { controller.updater }

    override private init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        automaticChecks = updater.automaticallyChecksForUpdates
    }

    func checkNow() {
        NSApp.activate(ignoringOtherApps: true) // menu-bar app: bring Sparkle's window to the front
        controller.checkForUpdates(nil)
    }

    var canCheck: Bool { updater.canCheckForUpdates }

    #if DEBUG
    /// Debug builds can point at a local test feed: `open --env RECALL_FEED_URL=http://127.0.0.1:8000/appcast.xml …`
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        ProcessInfo.processInfo.environment["RECALL_FEED_URL"]
    }

    func debugSilentUpdate() {
        updater.automaticallyChecksForUpdates = true
        updater.automaticallyDownloadsUpdates = true
        updater.checkForUpdatesInBackground()
    }
    #endif

    // Background app: let Sparkle show scheduled-update alerts without stealing focus.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
