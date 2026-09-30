import AppKit
import FinderSync
import Foundation
import OpenHereCore
import UniformTypeIdentifiers

/// Builds `OpenHere-Diagnostics.zip`. Private paths (selected items, custom app locations) are
/// deliberately left out.
@MainActor
enum DiagnosticsExporter {
  struct Report: Codable {
    var generatedAt: Date
    var appVersion: String
    var build: String
    var macOS: String
    var architecture: String
    var finderExtensionEnabled: Bool
    var loggingLevel: String
    var installedSupportedApplications: [String]
    var settings: RedactedSettings
  }

  struct RedactedSettings: Codable {
    var defaultTerminalID: String
    var defaultEditorID: String
    var enabledApplicationIDs: [String]?
    var customApplicationNames: [String]
    var useSubmenu: Bool
    var showIcons: Bool
    var showContextMenu: Bool
    var showToolbarAction: Bool
    var smartMenu: Bool
    var launchBehavior: String
    var shortcut: String
    var shortcutFinderOnly: Bool
  }

  static func export(settings: OpenHereSettings) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.zip]
    panel.nameFieldStringValue = "OpenHere-Diagnostics.zip"
    NSApp.activate()
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    do {
      try build(settings: settings, destination: destination)
      NSWorkspace.shared.activateFileViewerSelecting([destination])
    } catch {
      let alert = NSAlert(error: error)
      alert.runModal()
    }
  }

  private static func build(settings: OpenHereSettings, destination: URL) throws {
    let fileManager = FileManager.default
    let folder = fileManager.temporaryDirectory.appending(
      path: "OpenHere-Diagnostics-\(UUID().uuidString)", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: folder) }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(report(settings: settings)).write(to: folder.appending(path: "report.json"))
    try logs().write(to: folder.appending(path: "logs.txt"), atomically: true, encoding: .utf8)

    if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
    let ditto = Process()
    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ditto.arguments = ["-c", "-k", "--keepParent", folder.path, destination.path]
    try ditto.run()
    ditto.waitUntilExit()
    guard ditto.terminationStatus == 0 else {
      throw CocoaError(.fileWriteUnknown)
    }
  }

  private static func report(settings: OpenHereSettings) -> Report {
    let info = Bundle.main.infoDictionary ?? [:]
    let locator = WorkspaceApplicationLocator()
    let installed = ApplicationCatalog(settings: settings).applications
      .filter(locator.isInstalled).map(\.bundleIdentifier)

    return Report(
      generatedAt: Date(),
      appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
      build: info["CFBundleVersion"] as? String ?? "?",
      macOS: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: architecture(),
      finderExtensionEnabled: FinderExtensionStatus.isEnabled,
      loggingLevel: settings.loggingLevel.rawValue,
      installedSupportedApplications: installed,
      settings: RedactedSettings(
        defaultTerminalID: settings.defaultTerminalID,
        defaultEditorID: settings.defaultEditorID,
        enabledApplicationIDs: settings.enabledApplicationIDs.map { $0.sorted() },
        customApplicationNames: settings.customApplications.map(\.name),
        useSubmenu: settings.useSubmenu, showIcons: settings.showIcons,
        showContextMenu: settings.showContextMenu, showToolbarAction: settings.showToolbarAction,
        smartMenu: settings.smartMenu, launchBehavior: settings.launchBehavior.rawValue,
        shortcut: settings.shortcut.displayString,
        shortcutFinderOnly: settings.shortcut.onlyWhenFinderIsFocused))
  }

  private static func architecture() -> String {
    #if arch(arm64)
      "arm64"
    #else
      "x86_64"
    #endif
  }

  private static func logs() -> String {
    let entries = OpenHereLog.recentEntries()
    let header = "Log level: \(OpenHereLog.currentLevel.rawValue). Paths are redacted. Only this session is included.\n"
    return header + (entries.isEmpty ? "No entries recorded in this session.\n" : entries.joined(separator: "\n") + "\n")
  }
}
