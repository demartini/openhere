import Foundation

/// Checks the shared secret carried by `openhere://` requests.
public enum RequestAuthenticator {
  /// Constant-time comparison; a missing token on either side never matches.
  public static func isTrusted(provided: String?, expected: String?) -> Bool {
    guard let provided, let expected, !expected.isEmpty else { return false }
    let a = Array(expected.utf8)
    let b = Array(provided.utf8)
    guard a.count == b.count else { return false }
    return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
  }
}
