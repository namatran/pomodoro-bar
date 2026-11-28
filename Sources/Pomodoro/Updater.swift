import AppKit
import Combine
import Sparkle

/// Checks for and installs new versions with Sparkle. Updates are trusted by their EdDSA signature,
/// since the app is only ad-hoc signed.
@MainActor
final class Updater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    /// Only Pomodoro.app has the feed URL and key in its Info.plist; `swift run`'s bare binary doesn't.
    static let isBundled = Bundle.main.bundleIdentifier != nil

    @Published private(set) var canCheck = false
    /// A scheduled check found an update while the app wasn't in front, so the menus say so
    /// instead of a window popping up behind other apps.
    @Published private(set) var isUpdateWaiting = false

    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: Self.isBundled,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .map { $0 && Self.isBundled }
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        // A menu bar app isn't in front, so Sparkle's window would open behind others.
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle shows the update itself only when it can come to the front; otherwise the menus flag it.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        Task { @MainActor in self.isUpdateWaiting = true }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in self.isUpdateWaiting = false }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.isUpdateWaiting = false }
    }
}
