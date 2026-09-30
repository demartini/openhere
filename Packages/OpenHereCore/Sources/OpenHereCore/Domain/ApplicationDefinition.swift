import Foundation

/// Identifiers shared by the app, the Finder extension and the tooling.
public enum OpenHereConstants {
  public static let appBundleIdentifier = "dev.demartini.openhere"
  public static let extensionBundleIdentifier = "dev.demartini.openhere.FinderExtension"
  public static let urlScheme = "openhere"
  public static let repository = "demartini/openhere"
  /// Used when the Info.plist does not provide a team-prefixed group (e.g. unsigned test runs).
  public static let fallbackAppGroup = "group.dev.demartini.openhere"
  public static let appGroupInfoPlistKey = "OpenHereAppGroup"
}

public enum ApplicationKind: String, Codable, Sendable, CaseIterable, Hashable {
  case terminal
  case editor
  case custom
}

public enum ApplicationCapability: String, Codable, Sendable, Hashable {
  case opensDirectories
  case opensFiles
  case opensMultipleItems
}

/// How an application is asked to open something. No strategy ever goes through a shell.
public enum LaunchStrategy: Codable, Sendable, Hashable {
  /// `NSWorkspace.open(_:withApplicationAt:)` – the same thing Finder does for "Open With".
  case workspace
  /// `/usr/bin/open -a <app> --args <arguments>`; every argument is a separate `argv` entry and
  /// `{path}` is substituted inside each entry.
  case processArguments(arguments: [String], newInstance: Bool)
  /// Opens a URL built from a template (`{path}` is percent-encoded) with the application.
  case urlScheme(template: String)
}

/// Describes an application OpenHere can open things with. Adding an application means adding a
/// definition to `BuiltInApplications` – no other layer needs to change.
public struct ApplicationDefinition: Identifiable, Codable, Sendable, Hashable {
  public let id: String
  public var name: String
  public var bundleIdentifier: String
  public var kind: ApplicationKind
  public var capabilities: Set<ApplicationCapability>
  public var strategy: LaunchStrategy
  /// Absolute path of the `.app` bundle for user-defined applications.
  public var applicationPath: String?

  public var isUserDefined: Bool { applicationPath != nil }

  public init(
    id: String,
    name: String,
    bundleIdentifier: String,
    kind: ApplicationKind,
    capabilities: Set<ApplicationCapability>,
    strategy: LaunchStrategy = .workspace,
    applicationPath: String? = nil
  ) {
    self.id = id
    self.name = name
    self.bundleIdentifier = bundleIdentifier
    self.kind = kind
    self.capabilities = capabilities
    self.strategy = strategy
    self.applicationPath = applicationPath
  }

  public static let terminalCapabilities: Set<ApplicationCapability> = [.opensDirectories]
  public static let editorCapabilities: Set<ApplicationCapability> = [
    .opensDirectories, .opensFiles, .opensMultipleItems,
  ]
}
