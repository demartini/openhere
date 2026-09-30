import AppKit
import Carbon.HIToolbox
import OpenHereCore

/// Registers the global shortcut (Carbon hot key – needs no Accessibility permission). In
/// "Finder only" mode the hot key exists only while Finder is the frontmost application, so it never
/// collides with shortcuts of other apps.
@MainActor
final class ShortcutManager {
  enum Status: Equatable {
    case inactive
    case active
    case conflict
    case failed(OSStatus)
  }

  private static let signature: OSType = 0x4F48_5245  // 'OHRE'
  private static let finderBundleID = "com.apple.finder"

  private var hotKey: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?
  private var configuration: ShortcutConfiguration?
  private var activationObserver: NSObjectProtocol?

  private(set) var status: Status = .inactive
  var onTrigger: (@MainActor (ShortcutTarget) -> Void)?
  var onStatusChange: (@MainActor (Status) -> Void)?

  init() {
    installHandler()
    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reconcile() }
    }
  }

  isolated deinit {
    unregister()
    if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    if let eventHandler { RemoveEventHandler(eventHandler) }
  }

  func apply(_ configuration: ShortcutConfiguration) {
    self.configuration = configuration
    reconcile()
  }

  private func reconcile() {
    guard let configuration, configuration.isEnabled, configuration.isValid else {
      unregister()
      update(.inactive)
      return
    }
    let finderFrontmost =
      NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finderBundleID
    if configuration.onlyWhenFinderIsFocused && !finderFrontmost {
      unregister()
      update(.inactive)
      return
    }
    register(configuration)
  }

  private func register(_ configuration: ShortcutConfiguration) {
    unregister()
    let id = EventHotKeyID(signature: Self.signature, id: 1)
    var ref: EventHotKeyRef?
    let result = RegisterEventHotKey(
      configuration.keyCode, configuration.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
    switch result {
    case noErr:
      hotKey = ref
      update(.active)
    case OSStatus(eventHotKeyExistsErr):
      update(.conflict)
    default:
      OpenHereLog.error(.app, "Hot key registration failed", detail: "status \(result)")
      update(.failed(result))
    }
  }

  private func unregister() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    hotKey = nil
  }

  private func update(_ newStatus: Status) {
    guard newStatus != status else { return }
    status = newStatus
    onStatusChange?(newStatus)
  }

  private func installHandler() {
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let userData = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
        // Carbon delivers hot key events on the main thread.
        MainActor.assumeIsolated {
          if let target = manager.configuration?.target { manager.onTrigger?(target) }
        }
        return noErr
      }, 1, &spec, userData, &eventHandler)
  }
}
