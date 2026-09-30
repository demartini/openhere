import OpenHereCore
import SwiftUI

struct MenuBarContent: View {
  let model: SettingsModel
  let environment: AppEnvironment

  var body: some View {
    Button("Open Finder Location") {
      environment.requests.openFinderLocation(kind: .terminal)
    }

    Divider()

    applicationsMenu("Terminal", kind: .terminal)
    applicationsMenu("Editor", kind: .editor)
    let custom = model.installedApplications(of: .custom).filter { model.settings.isEnabled($0.id) }
    if !custom.isEmpty { applicationsMenu("Other", kind: .custom) }

    Divider()

    if let version = environment.updates.pendingUpdateVersion {
      Button("Update Available: \(version)…") { environment.updates.checkForUpdates() }
    }
    Button("Check for Updates…") { environment.updates.checkForUpdates() }
      .disabled(!environment.updates.canCheckForUpdates)
    Button("Settings…") { environment.windows.showSettings() }
      .keyboardShortcut(",")
    Button("Quit OpenHere") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }

  @ViewBuilder
  private func applicationsMenu(_ title: LocalizedStringKey, kind: ApplicationKind) -> some View {
    let applications = model.installedApplications(of: kind).filter { model.settings.isEnabled($0.id) }
    if !applications.isEmpty {
      Menu(title) {
        ForEach(applications) { application in
          Button {
            environment.requests.openFinderLocation(with: application)
          } label: {
            Text(application.name)
          }
        }
      }
    }
  }
}
