import Foundation

public enum ShortcutTarget: String, Codable, Sendable, CaseIterable, Hashable {
  case terminal
  case editor
}

/// A keyboard shortcut in Carbon terms (virtual key code + Carbon modifier mask).
public struct ShortcutConfiguration: Codable, Sendable, Equatable, Hashable {
  public static let commandMask: UInt32 = 1 << 8
  public static let shiftMask: UInt32 = 1 << 9
  public static let optionMask: UInt32 = 1 << 11
  public static let controlMask: UInt32 = 1 << 12

  public var isEnabled: Bool
  public var keyCode: UInt32
  public var carbonModifiers: UInt32
  /// Register the shortcut only while Finder is the frontmost application.
  public var onlyWhenFinderIsFocused: Bool
  public var target: ShortcutTarget

  /// ⌘⇧O, active in Finder only.
  public static let `default` = ShortcutConfiguration(
    isEnabled: true, keyCode: 31, carbonModifiers: commandMask | shiftMask,
    onlyWhenFinderIsFocused: true, target: .terminal)

  public init(
    isEnabled: Bool, keyCode: UInt32, carbonModifiers: UInt32, onlyWhenFinderIsFocused: Bool,
    target: ShortcutTarget
  ) {
    self.isEnabled = isEnabled
    self.keyCode = keyCode
    self.carbonModifiers = carbonModifiers
    self.onlyWhenFinderIsFocused = onlyWhenFinderIsFocused
    self.target = target
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = ShortcutConfiguration.default
    isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
    keyCode = try c.decodeIfPresent(UInt32.self, forKey: .keyCode) ?? d.keyCode
    carbonModifiers = try c.decodeIfPresent(UInt32.self, forKey: .carbonModifiers) ?? d.carbonModifiers
    onlyWhenFinderIsFocused =
      try c.decodeIfPresent(Bool.self, forKey: .onlyWhenFinderIsFocused) ?? d.onlyWhenFinderIsFocused
    target = try c.decodeIfPresent(ShortcutTarget.self, forKey: .target) ?? d.target
  }

  /// A shortcut must contain ⌘ or ⌃, otherwise it would fire while typing.
  public var isValid: Bool {
    carbonModifiers & (Self.commandMask | Self.controlMask) != 0
  }

  public var displayString: String {
    var text = ""
    if carbonModifiers & Self.controlMask != 0 { text += "⌃" }
    if carbonModifiers & Self.optionMask != 0 { text += "⌥" }
    if carbonModifiers & Self.shiftMask != 0 { text += "⇧" }
    if carbonModifiers & Self.commandMask != 0 { text += "⌘" }
    return text + KeyCodeNames.name(for: keyCode)
  }
}

/// Names for ANSI-layout virtual key codes (`kVK_*`).
public enum KeyCodeNames {
  private static let names: [UInt32: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
    12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
    22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
    32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
    42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
    51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
    109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓",
    126: "↑",
  ]

  public static func name(for keyCode: UInt32) -> String {
    names[keyCode] ?? "Key \(keyCode)"
  }
}
