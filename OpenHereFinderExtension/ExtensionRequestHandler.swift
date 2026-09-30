import AppKit
import OpenHereCore

/// Sends work to the main app. The extension never launches anything itself.
struct ExtensionRequestHandler {
  let store: any SettingsStoring

  func open(applicationID: String, context: FinderContext) {
    send(.open(applicationID: applicationID), context: context)
  }

  func openDefault(kind: ApplicationKind, context: FinderContext) {
    send(.openDefault(kind: kind), context: context)
  }

  func openSettings() {
    if let url = OpenHereURL(action: .settings).url { NSWorkspace.shared.open(url) }
  }

  func copy(_ style: PathCopyStyle, context: FinderContext) {
    let items = context.selection.isEmpty ? context.windowDirectory.map { [$0] } ?? [] : context.selection
    guard !items.isEmpty else { return }
    let text = PathFormatter.format(items, style: style, relativeTo: context.windowDirectory)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private func send(_ action: OpenHereURL.Action, context: FinderContext) {
    // Selection wins; with nothing selected the folder shown by the window is used.
    var paths = context.selection.map(\.path)
    if paths.isEmpty, let directory = context.windowDirectory { paths = [directory.path] }
    let request = OpenHereURL(action: action, paths: paths, token: store.requestToken())
    guard let url = request.url else { return }
    NSWorkspace.shared.open(url)
  }
}
