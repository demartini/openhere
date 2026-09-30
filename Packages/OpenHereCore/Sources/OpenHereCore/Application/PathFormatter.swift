import Foundation

public enum PathCopyStyle: String, Sendable, CaseIterable, Hashable {
  case posix
  case escaped
  case relative
}

/// Turns Finder paths into text that is safe to paste.
public enum PathFormatter {
  public static func format(_ urls: [URL], style: PathCopyStyle, relativeTo base: URL?) -> String {
    switch style {
    case .posix:
      return urls.map(\.path).joined(separator: "\n")
    case .escaped:
      return urls.map { shellEscape($0.path) }.joined(separator: " ")
    case .relative:
      guard let base else { return urls.map(\.path).joined(separator: "\n") }
      return urls.map { relativePath(of: $0, to: base) }.joined(separator: "\n")
    }
  }

  /// Escapes a path for POSIX-like shells (bash/zsh). Plain paths get backslash escapes; paths
  /// with control characters (newline, tab…) use ANSI-C quoting, the only form that can express them.
  public static func shellEscape(_ path: String) -> String {
    if path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
      var quoted = "$'"
      for scalar in path.unicodeScalars {
        switch scalar {
        case "\\": quoted += "\\\\"
        case "'": quoted += "\\'"
        case "\n": quoted += "\\n"
        case "\t": quoted += "\\t"
        case "\r": quoted += "\\r"
        default:
          if scalar.value < 0x20 || scalar.value == 0x7F {
            quoted += "\\x" + String(format: "%02x", scalar.value)
          } else {
            quoted.unicodeScalars.append(scalar)
          }
        }
      }
      return quoted + "'"
    }

    var result = ""
    for scalar in path.unicodeScalars {
      if needsEscaping(scalar) { result += "\\" }
      result.unicodeScalars.append(scalar)
    }
    return result
  }

  private static func needsEscaping(_ scalar: Unicode.Scalar) -> Bool {
    // Non-ASCII letters, digits and emoji are literal in every shell.
    guard scalar.isASCII else { return false }
    switch scalar {
    case "a"..."z", "A"..."Z", "0"..."9", "/", ".", "_", "-", "+", ",", ":", "@", "%", "=":
      return false
    default:
      return true
    }
  }

  public static func relativePath(of url: URL, to base: URL) -> String {
    let target = url.standardizedFileURL.pathComponents
    let root = base.standardizedFileURL.pathComponents
    var common = 0
    while common < min(target.count, root.count), target[common] == root[common] { common += 1 }
    let up = Array(repeating: "..", count: root.count - common)
    let down = Array(target.dropFirst(common))
    let parts = up + down
    return parts.isEmpty ? "." : parts.joined(separator: "/")
  }
}
