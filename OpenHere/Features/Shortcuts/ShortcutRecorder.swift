import AppKit
import Carbon.HIToolbox
import OpenHereCore
import SwiftUI

/// Click, then press the desired combination. Esc cancels; combinations must contain ⌘ or ⌃.
struct ShortcutRecorder: NSViewRepresentable {
  @Binding var configuration: ShortcutConfiguration
  var onRejected: () -> Void = {}

  func makeNSView(context: Context) -> RecorderButton {
    let button = RecorderButton()
    button.onRecord = { keyCode, modifiers in
      var updated = configuration
      updated.keyCode = keyCode
      updated.carbonModifiers = modifiers
      configuration = updated
    }
    button.onRejected = onRejected
    return button
  }

  func updateNSView(_ button: RecorderButton, context: Context) {
    button.displayValue = configuration.displayString
    button.onRejected = onRejected
  }

  final class RecorderButton: NSButton {
    var onRecord: ((UInt32, UInt32) -> Void)?
    var onRejected: (() -> Void)?
    private var isRecording = false { didSet { refreshTitle() } }

    var displayValue = "" { didSet { refreshTitle() } }

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      bezelStyle = .rounded
      setButtonType(.momentaryPushIn)
      target = self
      action = #selector(toggleRecording)
      setAccessibilityLabel(String(localized: "Keyboard shortcut"))
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
      NSSize(width: max(140, super.intrinsicContentSize.width), height: super.intrinsicContentSize.height)
    }

    override func resignFirstResponder() -> Bool {
      isRecording = false
      return super.resignFirstResponder()
    }

    @objc private func toggleRecording() {
      isRecording.toggle()
      if isRecording { window?.makeFirstResponder(self) }
    }

    private func refreshTitle() {
      title = isRecording ? String(localized: "Type shortcut…") : displayValue
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
      guard isRecording else { return super.performKeyEquivalent(with: event) }
      handle(event)
      return true
    }

    override func keyDown(with event: NSEvent) {
      guard isRecording else { return super.keyDown(with: event) }
      handle(event)
    }

    private func handle(_ event: NSEvent) {
      if event.keyCode == UInt16(kVK_Escape) {
        isRecording = false
        return
      }
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      var carbon: UInt32 = 0
      if flags.contains(.command) { carbon |= ShortcutConfiguration.commandMask }
      if flags.contains(.shift) { carbon |= ShortcutConfiguration.shiftMask }
      if flags.contains(.option) { carbon |= ShortcutConfiguration.optionMask }
      if flags.contains(.control) { carbon |= ShortcutConfiguration.controlMask }

      guard carbon & (ShortcutConfiguration.commandMask | ShortcutConfiguration.controlMask) != 0
      else {
        NSSound.beep()
        onRejected?()
        return
      }
      isRecording = false
      onRecord?(UInt32(event.keyCode), carbon)
    }
  }
}
