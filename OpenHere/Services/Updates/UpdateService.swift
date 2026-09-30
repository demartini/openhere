import AppKit
import Observation
import Sparkle

/// Thin wrapper around Sparkle. Updates are described by an appcast on GitHub Pages, the archives
/// are DMGs on GitHub Releases, and every archive is verified with the EdDSA key in Info.plist
/// (`SUPublicEDKey`) – no Apple Developer ID or notarization is involved.
///
/// OpenHere is a background (menu bar) app, so scheduled checks use Sparkle's *gentle reminders*:
/// instead of popping a window nobody notices, the menu bar icon changes and the menu offers
/// "Update available".
@MainActor
@Observable
final class UpdateService {
  private(set) var canCheckForUpdates = false
  /// Version string of an update found by a scheduled check that has not been shown yet.
  private(set) var pendingUpdateVersion: String?

  var automaticallyChecksForUpdates: Bool {
    didSet {
      guard automaticallyChecksForUpdates != oldValue else { return }
      controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }
  }

  @ObservationIgnored private var controller: SPUStandardUpdaterController!
  @ObservationIgnored private let userDriver = GentleReminderDelegate()
  @ObservationIgnored private var observation: NSKeyValueObservation?

  init() {
    automaticallyChecksForUpdates = false
    userDriver.owner = self
    controller = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: nil, userDriverDelegate: userDriver)
    automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    canCheckForUpdates = controller.updater.canCheckForUpdates
    observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
      let value = change.newValue ?? false
      Task { @MainActor in self?.canCheckForUpdates = value }
    }
  }

  func checkForUpdates() {
    // A user-initiated check always shows Sparkle's window in front.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    controller.checkForUpdates(nil)
  }

  fileprivate func setPending(_ version: String?) { pendingUpdateVersion = version }

  fileprivate func sessionFinished() {
    pendingUpdateVersion = nil
    AppEnvironment.shared.windows.restoreAgentModeIfIdle()
  }
}

/// Sparkle calls these on the main thread.
private final class GentleReminderDelegate: NSObject, SPUStandardUserDriverDelegate {
  weak var owner: UpdateService?

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    // Only interrupt when the user is already looking at OpenHere; otherwise remind gently.
    immediateFocus
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
  ) {
    MainActor.assumeIsolated {
      if handleShowingUpdate {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
      } else {
        owner?.setPending(update.displayVersionString)
      }
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    MainActor.assumeIsolated { owner?.setPending(nil) }
  }

  func standardUserDriverWillFinishUpdateSession() {
    MainActor.assumeIsolated { owner?.sessionFinished() }
  }
}
