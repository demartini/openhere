import Foundation

/// What clicking the Finder toolbar button does.
public enum ToolbarBehavior: String, Codable, Sendable, CaseIterable, Hashable {
  /// Opens straight away with the default terminal (no menu).
  case openDefaultTerminal
  case openDefaultEditor
  case showMenu
}

public enum LoggingLevel: String, Codable, Sendable, CaseIterable, Hashable {
  case disabled
  case errorsOnly
  case debug
}

/// All user configuration, stored as a single JSON document in the App Group so the app and the
/// Finder extension always see a consistent snapshot.
public struct OpenHereSettings: Codable, Sendable, Equatable {
  public var defaultTerminalID: String = BuiltInApplications.defaultTerminalID
  public var defaultEditorID: String = BuiltInApplications.defaultEditorID
  /// Applications shown in the Finder context menu and the menu bar. `nil` means all of them.
  public var enabledApplicationIDs: Set<String>? = [
    BuiltInApplications.defaultTerminalID, BuiltInApplications.defaultEditorID,
  ]
  /// Applications listed in the toolbar menu. `nil` follows `enabledApplicationIDs`.
  public var toolbarApplicationIDs: Set<String>?
  public var toolbarBehavior: ToolbarBehavior = .openDefaultTerminal
  public var applicationOrder: [String] = []
  public var customApplications: [ApplicationDefinition] = []

  public var showContextMenu = true
  public var useSubmenu = true
  public var showIcons = true
  public var showToolbarAction = true
  public var showCopyPathItems = true
  public var smartMenu = true
  public var launchBehavior: LaunchBehavior = .newWindow

  public var shortcut: ShortcutConfiguration = .default
  public var showMenuBarIcon = true
  public var loggingLevel: LoggingLevel = .errorsOnly
  public var onboardingCompleted = false

  public init() {}

  public func isEnabled(_ applicationID: String) -> Bool {
    enabledApplicationIDs?.contains(applicationID) ?? true
  }

  public func isInToolbar(_ applicationID: String) -> Bool {
    toolbarApplicationIDs?.contains(applicationID) ?? isEnabled(applicationID)
  }

  public mutating func setInToolbar(_ shown: Bool, applicationID: String, allIDs: [String]) {
    var set = toolbarApplicationIDs ?? Set(allIDs.filter(isEnabled))
    if shown { set.insert(applicationID) } else { set.remove(applicationID) }
    toolbarApplicationIDs = set
  }

  public mutating func setEnabled(_ enabled: Bool, applicationID: String, allIDs: [String]) {
    var set = enabledApplicationIDs ?? Set(allIDs)
    if enabled { set.insert(applicationID) } else { set.remove(applicationID) }
    enabledApplicationIDs = set
  }

  // MARK: Codable – every key is optional so older/newer documents still load.

  private enum CodingKeys: String, CodingKey {
    case defaultTerminalID, defaultEditorID, enabledApplicationIDs, applicationOrder
    case toolbarApplicationIDs, toolbarBehavior
    case customApplications, showContextMenu, useSubmenu, showIcons, showToolbarAction
    case showCopyPathItems, smartMenu, launchBehavior, shortcut, showMenuBarIcon, loggingLevel
    case onboardingCompleted
  }

  public init(from decoder: Decoder) throws {
    self.init()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    defaultTerminalID = try c.decodeIfPresent(String.self, forKey: .defaultTerminalID) ?? defaultTerminalID
    defaultEditorID = try c.decodeIfPresent(String.self, forKey: .defaultEditorID) ?? defaultEditorID
    enabledApplicationIDs = try c.decodeIfPresent(Set<String>.self, forKey: .enabledApplicationIDs)
    toolbarApplicationIDs = try c.decodeIfPresent(Set<String>.self, forKey: .toolbarApplicationIDs)
    toolbarBehavior = try c.decodeIfPresent(ToolbarBehavior.self, forKey: .toolbarBehavior) ?? toolbarBehavior
    applicationOrder = try c.decodeIfPresent([String].self, forKey: .applicationOrder) ?? []
    customApplications =
      try c.decodeIfPresent([ApplicationDefinition].self, forKey: .customApplications) ?? []
    showContextMenu = try c.decodeIfPresent(Bool.self, forKey: .showContextMenu) ?? showContextMenu
    useSubmenu = try c.decodeIfPresent(Bool.self, forKey: .useSubmenu) ?? useSubmenu
    showIcons = try c.decodeIfPresent(Bool.self, forKey: .showIcons) ?? showIcons
    showToolbarAction =
      try c.decodeIfPresent(Bool.self, forKey: .showToolbarAction) ?? showToolbarAction
    showCopyPathItems =
      try c.decodeIfPresent(Bool.self, forKey: .showCopyPathItems) ?? showCopyPathItems
    smartMenu = try c.decodeIfPresent(Bool.self, forKey: .smartMenu) ?? smartMenu
    launchBehavior =
      try c.decodeIfPresent(LaunchBehavior.self, forKey: .launchBehavior) ?? launchBehavior
    shortcut = try c.decodeIfPresent(ShortcutConfiguration.self, forKey: .shortcut) ?? shortcut
    showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? showMenuBarIcon
    loggingLevel = try c.decodeIfPresent(LoggingLevel.self, forKey: .loggingLevel) ?? loggingLevel
    onboardingCompleted =
      try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? onboardingCompleted
  }
}
