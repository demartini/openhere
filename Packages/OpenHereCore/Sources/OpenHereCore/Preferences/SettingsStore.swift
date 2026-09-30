import Foundation
import Security

public protocol SettingsStoring: Sendable {
  func load() -> OpenHereSettings
  func save(_ settings: OpenHereSettings)
  func reset()
  /// Shared secret between the app and its Finder extension (see `OpenHereURL`).
  func requestToken() -> String?
  /// Creates the token when missing. Only the app calls this.
  @discardableResult func ensureRequestToken() -> String
}

/// Where the app and its Finder extension share state.
///
/// An App Group would be the usual choice, but outside the Mac App Store macOS only grants one to
/// apps whose group id is prefixed with their Team ID (or authorised by an embedded profile), and
/// macOS 27 silently denies containers across teams. A build without a paid Apple team – an
/// ad-hoc or development-signed DMG – therefore cannot use it: the app would write to a container
/// the sandboxed extension can never read. Instead the (unsandboxed) app writes to a fixed folder in
/// the user's real home directory, and the extension reads it through a read-only sandbox exception
/// (`com.apple.security.temporary-exception.files.home-relative-path.read-only`).
public enum SharedStorage {
  /// Path relative to the home directory; must match the extension's entitlement.
  public static let relativePath = "Library/Application Support/OpenHere"

  /// The user's real home directory. `NSHomeDirectory()` would return the sandbox container inside
  /// the extension, so ask the account database instead.
  public static var realHomeDirectory: URL {
    if let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir {
      return URL(fileURLWithPath: String(cString: home), isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
  }

  public static var directory: URL {
    realHomeDirectory.appending(path: relativePath, directoryHint: .isDirectory)
  }
}

/// Settings and the request token stored as files in `SharedStorage.directory`.
///
/// Plain files are used instead of `UserDefaults`: the extension runs in another process and a
/// preferences suite is cached per process, so changes made in the app could stay invisible to it.
/// Reading a small file on every menu is instant. Only the app writes; the extension only reads.
public final class FileSettingsStore: SettingsStoring, @unchecked Sendable {
  private let directory: URL
  private var settingsURL: URL { directory.appending(path: "settings.json") }
  private var tokenURL: URL { directory.appending(path: "request-token") }

  public init(directory: URL) {
    self.directory = directory
    // Fails silently in the sandboxed extension, which only has read access.
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  /// The store shared by the app and the extension.
  public static func shared() -> FileSettingsStore {
    FileSettingsStore(directory: SharedStorage.directory)
  }

  public func load() -> OpenHereSettings {
    guard let data = try? Data(contentsOf: settingsURL),
      let settings = try? JSONDecoder().decode(OpenHereSettings.self, from: data)
    else { return OpenHereSettings() }
    return settings
  }

  public func save(_ settings: OpenHereSettings) {
    guard let data = try? JSONEncoder().encode(settings) else { return }
    do {
      try data.write(to: settingsURL, options: .atomic)
    } catch {
      OpenHereLog.error(.app, "Saving settings failed", detail: "\(error)")
    }
  }

  public func reset() {
    try? FileManager.default.removeItem(at: settingsURL)
  }

  public func requestToken() -> String? {
    guard let data = try? Data(contentsOf: tokenURL),
      let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !token.isEmpty
    else { return nil }
    return token
  }

  @discardableResult
  public func ensureRequestToken() -> String {
    if let token = requestToken() { return token }
    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    precondition(status == errSecSuccess, "Secure random generator failed")
    let token = bytes.map { String(format: "%02x", $0) }.joined()
    FileManager.default.createFile(
      atPath: tokenURL.path, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600])
    return token
  }
}
