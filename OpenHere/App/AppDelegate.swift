import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    // Registered this early so a launch caused by an `openhere://` URL is not missed.
    NSAppleEventManager.shared().setEventHandler(
      self, andSelector: #selector(handleGetURL(_:withReplyEvent:)),
      forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    MainActor.assumeIsolated { AppEnvironment.shared.start() }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { MainActor.assumeIsolated { AppEnvironment.shared.windows.showSettings() } }
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  @objc private func handleGetURL(
    _ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor
  ) {
    guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
      let url = URL(string: string)
    else { return }
    MainActor.assumeIsolated { AppEnvironment.shared.handleURL(url) }
  }
}
