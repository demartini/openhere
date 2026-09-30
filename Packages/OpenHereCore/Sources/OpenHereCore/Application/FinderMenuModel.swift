import Foundation

public enum FinderMenuKind: Sendable, Equatable {
  case items
  case container
  case sidebar
  case toolbar
}

/// Describes the Finder menu without touching AppKit, so it can be unit tested. The extension only
/// has to render this model.
public struct FinderMenuModel: Equatable, Sendable {
  public var terminals: [ApplicationDefinition]
  public var editors: [ApplicationDefinition]
  public var others: [ApplicationDefinition]
  public var copyStyles: [PathCopyStyle]
  public var showsConfigure: Bool
  public var usesSubmenu: Bool
  public var showsIcons: Bool
  /// Selection contains only files: editors go first ("smart" menu).
  public var editorsFirst: Bool

  public var isEmpty: Bool { terminals.isEmpty && editors.isEmpty && others.isEmpty }

  /// Applications in the order they should be displayed.
  public var orderedApplications: [ApplicationDefinition] {
    editorsFirst ? editors + others + terminals : terminals + editors + others
  }

  public static func make(
    settings: OpenHereSettings,
    kind: FinderMenuKind,
    selection: [URL] = [],
    fileSystem: any FileSystemInspecting = LocalFileSystem(),
    isInstalled: (ApplicationDefinition) -> Bool
  ) -> FinderMenuModel? {
    switch kind {
    case .toolbar where !settings.showToolbarAction: return nil
    case .items, .container, .sidebar: if !settings.showContextMenu { return nil }
    default: break
    }

    let catalog = ApplicationCatalog(settings: settings)
    let available = catalog.applications.filter {
      (kind == .toolbar ? settings.isInToolbar($0.id) : settings.isEnabled($0.id)) && isInstalled($0)
    }

    let onlyFiles =
      kind == .items && !selection.isEmpty
      && selection.allSatisfy { fileSystem.isDirectory($0) == false }

    return FinderMenuModel(
      terminals: available.filter { $0.kind == .terminal },
      editors: available.filter { $0.kind == .editor },
      others: available.filter { $0.kind == .custom },
      copyStyles: settings.showCopyPathItems && kind != .toolbar ? PathCopyStyle.allCases : [],
      showsConfigure: true,
      usesSubmenu: settings.useSubmenu && kind != .toolbar,
      showsIcons: settings.showIcons,
      editorsFirst: settings.smartMenu && onlyFiles
    )
  }
}
