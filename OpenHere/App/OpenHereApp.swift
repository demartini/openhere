import AppKit
import SwiftUI

@main
struct OpenHereApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  private let environment = AppEnvironment.shared

  var body: some Scene {
    MenuBarExtra(
      "OpenHere",
      systemImage: environment.updates.pendingUpdateVersion == nil ? "chevron.right.square" : "arrow.down.circle.fill",
      isInserted: Binding(
        get: { environment.settings.settings.showMenuBarIcon },
        set: {
          // MenuBarExtra writes the binding back on every update; only react to real changes,
          // otherwise the write invalidates the view and loops forever.
          guard environment.settings.settings.showMenuBarIcon != $0 else { return }
          environment.settings.settings.showMenuBarIcon = $0
        })
    ) {
      MenuBarContent(model: environment.settings, environment: environment)
    }
    .menuBarExtraStyle(.menu)
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("About OpenHere") { environment.showSettings(.about) }
      }
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { environment.showSettings(.general) }.keyboardShortcut(",")
      }
      CommandGroup(replacing: .help) {
        Button("OpenHere Help") { NSWorkspace.shared.open(ProjectLinks.help) }
        Button("Export Diagnostics…") { DiagnosticsExporter.export(settings: environment.settings.settings) }
          .keyboardShortcut("i", modifiers: [.command, .shift])
        Divider()
        Button("View Repository") { NSWorkspace.shared.open(ProjectLinks.repository) }
        Button("View Releases") { NSWorkspace.shared.open(ProjectLinks.releases) }
        Button("View Issues") { NSWorkspace.shared.open(ProjectLinks.issues) }
        Divider()
        Button("Submit New Issue") { NSWorkspace.shared.open(ProjectLinks.newIssue) }
      }
    }
  }
}
