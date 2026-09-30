import Foundation

/// The request the Finder extension sends to the app: `openhere://open?app=…&path=…&token=…`.
///
/// The extension is sandboxed and small on purpose; the app does the real work. Everything that
/// arrives through this URL is untrusted input (any web page can open a custom URL scheme), so the
/// app validates the token, the application id and every path before acting.
public struct OpenHereURL: Equatable, Sendable {
  public enum Action: Equatable, Sendable {
    /// Open with a specific application id.
    case open(applicationID: String)
    /// Open with the default application of a kind.
    case openDefault(kind: ApplicationKind)
    case settings
  }

  public static let maximumPaths = 64

  public var action: Action
  public var paths: [String]
  public var token: String?

  public init(action: Action, paths: [String] = [], token: String? = nil) {
    self.action = action
    self.paths = paths
    self.token = token
  }

  // MARK: Encoding

  public var url: URL? {
    var items: [(String, String)] = []
    let host: String
    switch action {
    case .open(let id):
      host = "open"
      items.append(("app", id))
    case .openDefault(let kind):
      host = "open"
      items.append(("default", kind.rawValue))
    case .settings:
      host = "settings"
    }
    items += paths.prefix(Self.maximumPaths).map { ("path", $0) }
    if let token { items.append(("token", token)) }

    var string = "\(OpenHereConstants.urlScheme)://\(host)"
    if !items.isEmpty {
      string += "?" + items.map { "\(Self.encode($0.0))=\(Self.encode($0.1))" }.joined(separator: "&")
    }
    return URL(string: string)
  }

  // MARK: Decoding

  public init?(url: URL) {
    guard url.scheme?.lowercased() == OpenHereConstants.urlScheme,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let host = components.host?.lowercased()
    else { return nil }

    var values: [String: String] = [:]
    var paths: [String] = []
    for pair in (components.percentEncodedQuery ?? "").split(separator: "&", omittingEmptySubsequences: true) {
      let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      guard let key = parts.first.flatMap({ String($0).removingPercentEncoding }) else { continue }
      let value = parts.count > 1 ? (String(parts[1]).removingPercentEncoding ?? "") : ""
      if key == "path" {
        if paths.count < Self.maximumPaths { paths.append(value) }
      } else {
        values[key] = value
      }
    }

    switch host {
    case "settings":
      self.action = .settings
    case "open":
      if let id = values["app"], !id.isEmpty {
        self.action = .open(applicationID: id)
      } else if let raw = values["default"], let kind = ApplicationKind(rawValue: raw) {
        self.action = .openDefault(kind: kind)
      } else {
        return nil
      }
    default:
      return nil
    }
    self.paths = paths
    self.token = values["token"]
  }

  // MARK: Helpers

  private static let allowed: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-._~/")
    return set
  }()

  private static func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
  }
}

/// Validates a path received from an untrusted channel.
public enum PathValidator {
  /// Returns a standardized file URL for absolute, existing paths; `nil` otherwise.
  public static func validatedURL(
    _ path: String, fileSystem: any FileSystemInspecting = LocalFileSystem()
  ) -> URL? {
    guard path.hasPrefix("/"), !path.contains("\0"), path.utf8.count < 4096 else { return nil }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard fileSystem.isDirectory(url) != nil else { return nil }
    return url
  }
}
