import AppKit
import SwiftUI

/// Owns the Settings and Onboarding windows. The app is an agent (`LSUIElement`); it becomes a
/// regular app (Dock icon, ⌘-Tab) only while one of these windows is visible.
@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
  private var settingsWindow: NSWindow?
  private var onboardingWindow: NSWindow?

  private let makeSettingsView: () -> AnyView
  private let makeOnboardingView: (@escaping () -> Void) -> AnyView

  init(
    settingsView: @escaping () -> AnyView,
    onboardingView: @escaping (@escaping () -> Void) -> AnyView
  ) {
    self.makeSettingsView = settingsView
    self.makeOnboardingView = onboardingView
  }

  func showSettings() {
    if let settingsWindow {
      present(settingsWindow)
      return
    }
    let window = makeWindow(
      title: String(localized: "OpenHere Settings"), content: makeSettingsView(),
      style: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .unified
    window.setContentSize(NSSize(width: 800, height: 560))
    window.minSize = NSSize(width: 740, height: 500)
    window.setFrameAutosaveName("OpenHereSettings")
    settingsWindow = window
    present(window)
  }

  func showOnboarding() {
    if let onboardingWindow {
      present(onboardingWindow)
      return
    }
    let window = makeWindow(
      title: String(localized: "Welcome to OpenHere"),
      content: makeOnboardingView { [weak self] in self?.closeOnboarding() },
      style: [.titled, .closable, .fullSizeContentView])
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    onboardingWindow = window
    present(window)
  }

  private func closeOnboarding() {
    onboardingWindow?.close()
  }

  private func makeWindow(title: String, content: AnyView, style: NSWindow.StyleMask) -> NSWindow {
    let controller = NSHostingController(rootView: content)
    let window = NSWindow(contentViewController: controller)
    window.title = title
    window.styleMask = style
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    return window
  }

  private func present(_ window: NSWindow) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  /// Back to a menu bar–only app once none of our windows is open (used after update dialogs).
  func restoreAgentModeIfIdle() {
    if settingsWindow == nil && onboardingWindow == nil { NSApp.setActivationPolicy(.accessory) }
  }

  func windowWillClose(_ notification: Notification) {
    guard let closing = notification.object as? NSWindow else { return }
    if closing === settingsWindow { settingsWindow = nil }
    if closing === onboardingWindow { onboardingWindow = nil }
    if settingsWindow == nil && onboardingWindow == nil {
      NSApp.setActivationPolicy(.accessory)
    }
  }
}
