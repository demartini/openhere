import Foundation
import Testing

@testable import OpenHereCore

struct CatalogAndSettingsTests {
  @Test func builtInIdentifiersAreUnique() {
    let ids = BuiltInApplications.all.map(\.id)
    #expect(Set(ids).count == ids.count)
    let bundles = BuiltInApplications.all.map(\.bundleIdentifier)
    #expect(Set(bundles).count == bundles.count)
  }

  @Test func everyProcessStrategyHasPathPlaceholder() {
    for app in BuiltInApplications.all {
      if case .processArguments(let arguments, _) = app.strategy {
        #expect(arguments.contains { $0.contains("{path}") }, "\(app.id)")
      }
    }
  }

  @Test func settingsRoundTripAndTolerateMissingKeys() throws {
    var settings = OpenHereSettings()
    settings.defaultTerminalID = "ghostty"
    settings.useSubmenu = false
    settings.shortcut.keyCode = 5
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(OpenHereSettings.self, from: data) == settings)

    let sparse = try JSONDecoder().decode(OpenHereSettings.self, from: Data(#"{"useSubmenu":false}"#.utf8))
    #expect(sparse.useSubmenu == false)
    #expect(sparse.defaultTerminalID == "terminal")
    #expect(sparse.shortcut == .default)
  }

  private func temporaryStore() -> (FileSettingsStore, URL) {
    let dir = FileManager.default.temporaryDirectory.appending(path: "openhere-test-\(UUID().uuidString)")
    return (FileSettingsStore(directory: dir), dir)
  }

  @Test func storeFallsBackToDefaultsOnCorruptData() throws {
    let (store, dir) = temporaryStore()
    defer { try? FileManager.default.removeItem(at: dir) }
    try Data("garbage".utf8).write(to: dir.appending(path: "settings.json"))
    #expect(store.load() == OpenHereSettings())

    var settings = OpenHereSettings()
    settings.showIcons = false
    store.save(settings)
    #expect(FileSettingsStore(directory: dir).load().showIcons == false)  // visible to another instance
    store.reset()
    #expect(store.load() == OpenHereSettings())
  }

  @Test func requestTokenIsStableAndPrivate() throws {
    let (store, dir) = temporaryStore()
    defer { try? FileManager.default.removeItem(at: dir) }
    #expect(store.requestToken() == nil)
    let token = store.ensureRequestToken()
    #expect(token.count == 64)
    #expect(store.ensureRequestToken() == token)
    #expect(FileSettingsStore(directory: dir).requestToken() == token)
    let permissions = try FileManager.default.attributesOfItem(atPath: dir.appending(path: "request-token").path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
  }

  @Test func freshSettingsShowOnlyDefaultApplications() {
    let settings = OpenHereSettings()
    #expect(settings.isEnabled("terminal") && settings.isEnabled("vscode"))
    #expect(!settings.isEnabled("iterm"))
    #expect(settings.isInToolbar("terminal") && !settings.isInToolbar("zed"))
    #expect(settings.toolbarBehavior == .openDefaultTerminal)
  }

  @Test func toolbarSelectionIsIndependentOnceCustomized() {
    var settings = OpenHereSettings()
    let all = BuiltInApplications.all.map(\.id)
    settings.setInToolbar(true, applicationID: "zed", allIDs: all)
    #expect(settings.isInToolbar("zed") && settings.isInToolbar("terminal"))
    settings.setEnabled(true, applicationID: "iterm", allIDs: all)
    #expect(settings.isEnabled("iterm") && !settings.isInToolbar("iterm"))
  }

  @Test func enabledSetAndOrdering() {
    var settings = OpenHereSettings()
    settings.enabledApplicationIDs = nil
    #expect(settings.isEnabled("ghostty"))
    settings.setEnabled(false, applicationID: "ghostty", allIDs: BuiltInApplications.all.map(\.id))
    #expect(!settings.isEnabled("ghostty"))
    #expect(settings.isEnabled("iterm"))

    settings.applicationOrder = ["kitty", "ghostty"]
    let ids = ApplicationCatalog(settings: settings).applications.map(\.id)
    #expect(ids.prefix(2) == ["kitty", "ghostty"])
    #expect(ids.count == BuiltInApplications.all.count)
  }

  @Test func effectiveDefaultFallsBackWhenMissing() {
    var settings = OpenHereSettings()
    settings.defaultTerminalID = "ghostty"
    let catalog = ApplicationCatalog(settings: settings)
    let result = catalog.effectiveDefault(kind: .terminal, settings: settings) { $0.id == "iterm" }
    #expect(result?.id == "iterm")
    #expect(catalog.effectiveDefault(kind: .terminal, settings: settings) { _ in false } == nil)
    #expect(
      catalog.effectiveDefault(kind: .terminal, settings: settings) { _ in true }?.id == "ghostty")
  }

  @Test func shortcutValidationAndDisplay() {
    #expect(ShortcutConfiguration.default.isValid)
    #expect(ShortcutConfiguration.default.displayString == "⇧⌘O")
    var bad = ShortcutConfiguration.default
    bad.carbonModifiers = ShortcutConfiguration.shiftMask
    #expect(!bad.isValid)
  }

  @Test func customApplicationValidation() throws {
    let appURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
    let ok = try CustomApplicationFactory.make(
      name: " Calc ", applicationURL: appURL, kind: .editor,
      mode: .arguments(["--open", "{path}"], newInstance: false))
    #expect(ok.name == "Calc")
    #expect(ok.isUserDefined)
    #expect(ok.strategy == .processArguments(arguments: ["--open", "{path}"], newInstance: false))

    #expect(throws: CustomApplicationError.missingPathPlaceholder) {
      try CustomApplicationFactory.make(
        name: "x", applicationURL: appURL, kind: .terminal, mode: .arguments(["--open"], newInstance: false))
    }
    #expect(throws: CustomApplicationError.emptyName) {
      try CustomApplicationFactory.make(name: "  ", applicationURL: appURL, kind: .terminal, mode: .standard)
    }
    #expect(throws: CustomApplicationError.notAnApplication) {
      try CustomApplicationFactory.make(
        name: "x", applicationURL: URL(fileURLWithPath: "/usr/bin/true"), kind: .terminal, mode: .standard)
    }
  }
}
