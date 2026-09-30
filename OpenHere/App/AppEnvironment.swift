import AppKit
import OpenHereCore
import SwiftUI

/// Composition root: builds and wires the services once.
@MainActor
final class AppEnvironment {
  static let shared = AppEnvironment()

  let store: FileSettingsStore
  let settings: SettingsModel
  let shortcuts = ShortcutManager()
  let updates = UpdateService()
  let navigation = SettingsNavigation()
  private(set) var windows: WindowCoordinator!
  private(set) var requests: OpenRequestHandler!

  private var activationObserver: NSObjectProtocol?

  private init() {
    store = .shared()
    settings = SettingsModel(store: store)
    windows = WindowCoordinator(
      settingsView: { [unowned self] in
        AnyView(SettingsView(model: settings, environment: self, navigation: navigation))
      },
      onboardingView: { [unowned self] close in
        AnyView(OnboardingView(model: settings, onFinish: close))
      })
    requests = OpenRequestHandler(
      settings: settings, store: store, onOpenSettings: { [unowned self] in windows.showSettings() })
  }

  func start() {
    store.ensureRequestToken()
    OpenHereLog.setLevel(settings.settings.loggingLevel)

    settings.onChange = { [unowned self] old, new in settingsDidChange(from: old, to: new) }

    shortcuts.onTrigger = { [unowned self] target in
      requests.openFinderLocation(kind: target == .editor ? .editor : .terminal)
    }
    shortcuts.onStatusChange = { [unowned self] status in settings.shortcutStatus = status }
    shortcuts.apply(settings.settings.shortcut)

    // Cheap: re-check which applications are installed whenever the user comes back to us.
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [unowned self] _ in
      MainActor.assumeIsolated { settings.markInstalledApplicationsChanged() }
    }

    if !settings.settings.onboardingCompleted { windows.showOnboarding() }
    OpenHereLog.debug(.app, "Started")
  }

  private func settingsDidChange(from old: OpenHereSettings, to new: OpenHereSettings) {
    if old.loggingLevel != new.loggingLevel { OpenHereLog.setLevel(new.loggingLevel) }
    if old.shortcut != new.shortcut { shortcuts.apply(new.shortcut) }
  }

  func showSettings(_ pane: SettingsPane) {
    navigation.selection = pane
    windows.showSettings()
  }

  func handleURL(_ url: URL) {
    requests.handle(url: url)
  }
}
