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

/// Settings and the request token stored as files in the App Group container.
///
/// Plain files are used instead of `UserDefaults`: the extension runs in another process and a
/// preferences suite is cached per process (and can be detached from `cfprefsd`), so changes made in
/// the app could stay invisible to the extension. Reading a small file on every menu is instant.
public final class FileSettingsStore: SettingsStoring, @unchecked Sendable {
  private let directory: URL
  private var settingsURL: URL { directory.appending(path: "settings.json") }
  private var tokenURL: URL { directory.appending(path: "request-token") }

  public init(directory: URL) {
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  /// The store shared by the app and the extension.
  public static func shared(bundle: Bundle = .main) -> FileSettingsStore {
    let group = AppGroup.identifier(bundle: bundle)
    let container =
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "OpenHere", directoryHint: .isDirectory)
    if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) == nil {
      OpenHereLog.error(.app, "App Group container unavailable", detail: group)
    }
    return FileSettingsStore(directory: container)
  }

  public func load() -> OpenHereSettings {
    guard let data = try? Data(contentsOf: settingsURL),
      let settings = try? JSONDecoder().decode(OpenHereSettings.self, from: data)
    else { return OpenHereSettings() }
    return settings
  }

  public func save(_ settings: OpenHereSettings) {
    guard let data = try? JSONEncoder().encode(settings) else { return }
    try? data.write(to: settingsURL, options: .atomic)
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

public enum AppGroup {
  /// Team-prefixed group id injected into Info.plist (`$(TeamIdentifierPrefix)group.…`).
  public static func identifier(bundle: Bundle = .main) -> String {
    let value = bundle.object(forInfoDictionaryKey: OpenHereConstants.appGroupInfoPlistKey) as? String
    guard let value, !value.isEmpty, !value.contains("$(") else {
      return OpenHereConstants.fallbackAppGroup
    }
    return value
  }
}
