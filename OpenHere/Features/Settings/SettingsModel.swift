import AppKit
import Observation
import OpenHereCore

/// Observable wrapper around the persisted settings. Every change is saved immediately to the App
/// Group, where the Finder extension reads it.
@MainActor
@Observable
final class SettingsModel {
  var settings: OpenHereSettings {
    didSet {
      guard settings != oldValue else { return }
      store.save(settings)
      onChange?(oldValue, settings)
    }
  }

  /// Incremented when installed applications may have changed, so views re-evaluate `isInstalled`.
  private(set) var installedRevision = 0
  var shortcutStatus: ShortcutManager.Status = .inactive

  @ObservationIgnored private let store: any SettingsStoring
  @ObservationIgnored private let locator: any ApplicationLocating
  @ObservationIgnored var onChange: ((OpenHereSettings, OpenHereSettings) -> Void)?

  init(
    store: any SettingsStoring, locator: any ApplicationLocating = WorkspaceApplicationLocator()
  ) {
    self.store = store
    self.locator = locator
    self.settings = store.load()
  }

  var catalog: ApplicationCatalog { ApplicationCatalog(settings: settings) }

  func isInstalled(_ application: ApplicationDefinition) -> Bool {
    _ = installedRevision
    return locator.isInstalled(application)
  }

  func installedApplications(of kind: ApplicationKind) -> [ApplicationDefinition] {
    catalog.applications(of: kind).filter(isInstalled)
  }

  func applicationURL(_ application: ApplicationDefinition) -> URL? {
    locator.url(for: application)
  }

  func markInstalledApplicationsChanged() {
    installedRevision += 1
  }

  func setEnabled(_ enabled: Bool, for application: ApplicationDefinition) {
    settings.setEnabled(
      enabled, applicationID: application.id, allIDs: catalog.applications.map(\.id))
  }

  func setInToolbar(_ shown: Bool, for application: ApplicationDefinition) {
    settings.setInToolbar(shown, applicationID: application.id, allIDs: catalog.applications.map(\.id))
  }

  /// Makes sure an application chosen as default is also listed in the menus.
  func ensureShown(_ applicationID: String) {
    guard let application = catalog.application(id: applicationID) else { return }
    if !settings.isEnabled(applicationID) { setEnabled(true, for: application) }
    if !settings.isInToolbar(applicationID) { setInToolbar(true, for: application) }
  }

  func moveApplications(of kind: ApplicationKind, from offsets: IndexSet, to destination: Int) {
    var groups = ApplicationKind.allCases.map { (kind: $0, apps: catalog.applications(of: $0)) }
    guard let index = groups.firstIndex(where: { $0.kind == kind }) else { return }
    groups[index].apps.move(fromOffsets: offsets, toOffset: destination)
    settings.applicationOrder = groups.flatMap { $0.apps.map(\.id) }
  }

  func add(_ application: ApplicationDefinition) {
    settings.customApplications.append(application)
    settings.applicationOrder = catalog.applications.map(\.id)
  }

  func remove(_ application: ApplicationDefinition) {
    settings.customApplications.removeAll { $0.id == application.id }
    settings.enabledApplicationIDs?.remove(application.id)
    settings.applicationOrder.removeAll { $0 == application.id }
    if settings.defaultTerminalID == application.id {
      settings.defaultTerminalID = BuiltInApplications.defaultTerminalID
    }
    if settings.defaultEditorID == application.id {
      settings.defaultEditorID = BuiltInApplications.defaultEditorID
    }
  }

  /// Restores every option except the onboarding flag.
  func resetToDefaults() {
    var fresh = OpenHereSettings()
    fresh.onboardingCompleted = settings.onboardingCompleted
    settings = fresh
  }
}
