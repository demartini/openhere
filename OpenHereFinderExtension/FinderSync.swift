import Cocoa
import FinderSync
import OpenHereCore
import os

/// Deliberately tiny: it renders `FinderMenuModel` and forwards clicks to the app.
final class FinderSync: FIFinderSync {
  private enum MenuAction {
    case open(applicationID: String)
    case copy(PathCopyStyle)
    case configure
  }

  private let store = FileSettingsStore.shared()
  private let locator = WorkspaceApplicationLocator()
  private let resolver = FinderContextResolver()
  private lazy var handler = ExtensionRequestHandler(store: store)

  /// Finder copies menus across processes, so `representedObject` does not survive the trip; the
  /// item `tag` does. Actions are looked up by tag when the click arrives.
  private var actions: [Int: MenuAction] = [:]
  private var nextTag = 1

  override init() {
    super.init()
    updateMonitoredDirectories()
    let center = NSWorkspace.shared.notificationCenter
    for name in [
      NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
      NSWorkspace.didRenameVolumeNotification,
    ] {
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.updateMonitoredDirectories()
      }
    }
  }

  /// Finder Sync only decorates locations it was told to watch; every browsable volume needs its own entry.
  private func updateMonitoredDirectories() {
    let urls = MonitoredLocations.current()
    FIFinderSyncController.default().directoryURLs = urls
    // Visible with: /usr/bin/log stream --predicate 'subsystem == "dev.demartini.openhere"' --info
    let settingsReadable = store.requestToken() != nil
    Logger(subsystem: OpenHereLog.subsystem, category: LogCategory.finderExtension.rawValue)
      .info(
        "Monitoring \(urls.count, privacy: .public) locations (\(urls.filter { $0.path.hasPrefix("/Volumes/") }.count, privacy: .public) under /Volumes); token readable: \(settingsReadable, privacy: .public)"
      )
  }

  // MARK: Toolbar

  override var toolbarItemName: String { String(localized: "Open Here") }

  override var toolbarItemToolTip: String {
    String(localized: "Open the current folder in a terminal or editor")
  }

  override var toolbarItemImage: NSImage {
    // Template symbol (same glyph as the menu bar item); Finder tints it for light/dark.
    symbolImage(pointSize: 18) ?? NSImage()
  }

  /// Menu images are serialized to Finder, which drops the template flag, so the glyph is tinted here
  /// for the current appearance (white in dark mode, near-black in light mode) and flattened to a bitmap.
  private func menuSymbolImage(pointSize: CGFloat) -> NSImage? {
    let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    let color: NSColor = isDark ? .white : NSColor(white: 0.1, alpha: 1)
    guard
      let symbol = NSImage(systemSymbolName: "chevron.right.square", accessibilityDescription: nil)?
        .withSymbolConfiguration(
          NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color])))
    else { return nil }
    let size = NSSize(width: 16, height: 16)
    let flattened = NSImage(size: size, flipped: false) { rect in
      let scale = min(rect.width / symbol.size.width, rect.height / symbol.size.height)
      let drawn = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
      symbol.draw(
        in: NSRect(x: (rect.width - drawn.width) / 2, y: (rect.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
      return true
    }
    // Force a bitmap representation so nothing is redrawn lazily on the Finder side.
    guard let tiff = flattened.tiffRepresentation, let bitmap = NSImage(data: tiff) else { return flattened }
    bitmap.size = size
    bitmap.isTemplate = false
    return bitmap
  }

  /// The app's glyph as a template image, so Finder draws it white in dark mode and black in light mode
  /// (`withSymbolConfiguration` returns a copy that is not a template by default).
  private func symbolImage(pointSize: CGFloat) -> NSImage? {
    let image = NSImage(systemSymbolName: "chevron.right.square", accessibilityDescription: nil)?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular))
    image?.isTemplate = true
    return image
  }

  // MARK: Menus

  override func menu(for menuKind: FIMenuKind) -> NSMenu? {
    let context = resolver.currentContext()
    let settings = store.load()

    if menuKind == .toolbarItemMenu {
      guard settings.showToolbarAction else { return nil }
      // Clicking the button runs the default action immediately instead of showing a menu.
      switch settings.toolbarBehavior {
      case .openDefaultTerminal:
        handler.openDefault(kind: .terminal, context: context)
        return nil
      case .openDefaultEditor:
        handler.openDefault(kind: .editor, context: context)
        return nil
      case .showMenu:
        break
      }
    }

    let kind: FinderMenuKind =
      switch menuKind {
      case .contextualMenuForItems: .items
      case .contextualMenuForContainer: .container
      case .contextualMenuForSidebar: .sidebar
      case .toolbarItemMenu: .toolbar
      @unknown default: .container
      }

    guard
      let model = FinderMenuModel.make(
        settings: settings, kind: kind, selection: context.selection, isInstalled: locator.isInstalled)
    else { return nil }
    return makeMenu(model)
  }

  private func makeMenu(_ model: FinderMenuModel) -> NSMenu {
    let menu = NSMenu(title: "")
    let openMenu: NSMenu
    if model.usesSubmenu {
      openMenu = NSMenu(title: String(localized: "Open Here"))
      let parent = NSMenuItem(title: String(localized: "Open Here"), action: nil, keyEquivalent: "")
      parent.submenu = openMenu
      parent.image = menuSymbolImage(pointSize: 13)
      menu.addItem(parent)
    } else {
      openMenu = menu
    }

    for application in model.orderedApplications {
      let title = model.usesSubmenu ? application.name : String(localized: "Open in \(application.name)")
      let item = makeItem(title, .open(applicationID: application.id))
      if model.showsIcons, let url = locator.url(for: application) {
        item.image = icon(NSWorkspace.shared.icon(forFile: url.path))
      }
      openMenu.addItem(item)
    }

    if !model.copyStyles.isEmpty {
      let copyMenu = NSMenu(title: String(localized: "Copy Path"))
      for style in model.copyStyles { copyMenu.addItem(makeItem(title(for: style), .copy(style))) }
      if !openMenu.items.isEmpty { openMenu.addItem(.separator()) }
      let parent = NSMenuItem(title: String(localized: "Copy Path"), action: nil, keyEquivalent: "")
      parent.submenu = copyMenu
      openMenu.addItem(parent)
    }

    if model.showsConfigure {
      openMenu.addItem(.separator())
      openMenu.addItem(makeItem(String(localized: "Configure Open Here…"), .configure))
    }
    return menu
  }

  private func makeItem(_ title: String, _ action: MenuAction) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
    item.target = self
    item.tag = nextTag
    actions[nextTag] = action
    nextTag += 1
    if actions.count > 400 {  // menus are rebuilt often; drop the oldest half
      for key in actions.keys.sorted().prefix(200) { actions[key] = nil }
    }
    return item
  }

  private func icon(_ source: NSImage) -> NSImage {
    let image = (source.copy() as? NSImage) ?? source
    image.size = NSSize(width: 16, height: 16)
    return image
  }

  private func title(for style: PathCopyStyle) -> String {
    switch style {
    case .posix: String(localized: "Copy POSIX Path")
    case .escaped: String(localized: "Copy Escaped Path")
    case .relative: String(localized: "Copy Relative Path")
    }
  }

  // MARK: Actions

  @objc private func menuItemClicked(_ sender: NSMenuItem) {
    guard let action = actions[sender.tag] else { return }
    let context = resolver.currentContext()
    switch action {
    case .open(let id): handler.open(applicationID: id, context: context)
    case .copy(let style): handler.copy(style, context: context)
    case .configure: handler.openSettings()
    }
  }
}
