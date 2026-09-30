import AppKit
import Foundation
import OpenHereCore

/// Turns requests (URL from the Finder extension, menu bar, shortcut) into launches.
@MainActor
final class OpenRequestHandler {
  private let settings: SettingsModel
  private let store: any SettingsStoring
  private let launcher: Launcher
  private let locator: any ApplicationLocating
  private let finderQuery = FinderQuery()
  private let onOpenSettings: () -> Void

  init(
    settings: SettingsModel, store: any SettingsStoring, launcher: Launcher = Launcher(),
    locator: any ApplicationLocating = WorkspaceApplicationLocator(),
    onOpenSettings: @escaping () -> Void
  ) {
    self.settings = settings
    self.store = store
    self.launcher = launcher
    self.locator = locator
    self.onOpenSettings = onOpenSettings
  }

  // MARK: Entry points

  /// `openhere://…` sent by the Finder extension. Treated as untrusted input.
  func handle(url: URL) {
    guard let request = OpenHereURL(url: url) else {
      OpenHereLog.error(.app, "Ignored malformed URL")
      return
    }
    if case .settings = request.action {
      onOpenSettings()
      return
    }
    guard isTrusted(request.token) else {
      OpenHereLog.error(.app, "Rejected request with invalid token")
      return
    }

    let catalog = settings.catalog
    let application: ApplicationDefinition?
    switch request.action {
    case .open(let id):
      application = catalog.application(id: id)
      if application == nil { return present(LaunchError.unknownApplication(id: id)) }
    case .openDefault(let kind):
      application = effectiveDefault(kind: kind)
    case .settings:
      return
    }
    guard let application else { return presentNoDefaultApplication() }

    let urls = request.paths.compactMap { PathValidator.validatedURL($0) }
    Task { await open(application: application, context: await context(selection: urls)) }
  }

  /// Menu bar item and keyboard shortcut: use what Finder currently shows.
  func openFinderLocation(kind: ApplicationKind) {
    guard let application = effectiveDefault(kind: kind) else { return presentNoDefaultApplication() }
    openFinderLocation(with: application)
  }

  func openFinderLocation(with application: ApplicationDefinition) {
    Task {
      do {
        let context = try finderQuery.currentContext()
        await open(application: application, context: context)
      } catch {
        // Without Automation permission we can still open the Desktop; explain why it happened.
        present(error)
      }
    }
  }

  // MARK: Implementation

  private func context(selection: [URL]) async -> FinderContext {
    if !selection.isEmpty { return FinderContext(selection: selection) }
    return (try? finderQuery.currentContext()) ?? FinderContext()
  }

  private func open(application: ApplicationDefinition, context: FinderContext) async {
    let target = OpenTargetResolver().resolve(context)
    let requests = LaunchRequestBuilder().requests(
      for: target, application: application, behavior: settings.settings.launchBehavior)
    do {
      try await launcher.launch(requests)
    } catch {
      present(error)
    }
  }

  private func effectiveDefault(kind: ApplicationKind) -> ApplicationDefinition? {
    let current = settings.settings
    return settings.catalog.effectiveDefault(
      kind: kind == .editor ? .editor : .terminal, settings: current, isInstalled: locator.isInstalled)
  }

  private func isTrusted(_ token: String?) -> Bool {
    RequestAuthenticator.isTrusted(provided: token, expected: store.requestToken())
  }

  // MARK: Errors

  private func presentNoDefaultApplication() {
    present(
      NSError(
        domain: "OpenHere", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: String(
            localized: "No supported application is installed. Choose one in Settings.")
        ]))
  }

  private func present(_ error: Error) {
    OpenHereLog.error(.launcher, "Presenting error", detail: "\(error)")
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(localized: "OpenHere could not open this location")
    alert.informativeText = error.localizedDescription
    alert.addButton(withTitle: String(localized: "OK"))
    alert.addButton(withTitle: String(localized: "Open Settings…"))
    if case FinderQuery.QueryError.notAuthorized = error {
      alert.addButton(withTitle: String(localized: "Open Automation Settings"))
    }
    NSApp.activate()
    switch alert.runModal() {
    case .alertSecondButtonReturn: onOpenSettings()
    case .alertThirdButtonReturn:
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
      {
        NSWorkspace.shared.open(url)
      }
    default: break
    }
  }
}
