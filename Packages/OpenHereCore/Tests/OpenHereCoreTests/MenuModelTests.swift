import Foundation
import Testing

@testable import OpenHereCore

struct MenuModelTests {
  private let fs = FakeFileSystem(directories: ["/d"], files: ["/f.txt"])
  private func url(_ p: String) -> URL { URL(fileURLWithPath: p) }

  private func make(
    _ settings: OpenHereSettings = OpenHereSettings(), kind: FinderMenuKind = .container,
    selection: [URL] = [], installed: Set<String> = ["terminal", "ghostty", "vscode", "zed"]
  ) -> FinderMenuModel? {
    FinderMenuModel.make(
      settings: settings, kind: kind, selection: selection, fileSystem: fs
    ) { installed.contains($0.id) }
  }

  @Test func onlyInstalledAndEnabledApplicationsAppear() throws {
    var settings = OpenHereSettings()
    settings.enabledApplicationIDs = nil
    settings.setEnabled(false, applicationID: "zed", allIDs: BuiltInApplications.all.map(\.id))
    let model = try #require(make(settings))
    #expect(model.terminals.map(\.id) == ["terminal", "ghostty"])
    #expect(model.editors.map(\.id) == ["vscode"])
  }

  @Test func smartMenuPutsEditorsFirstForFiles() throws {
    let files = try #require(make(kind: .items, selection: [url("/f.txt")]))
    #expect(files.editorsFirst)
    #expect(files.orderedApplications.first?.kind == .editor)
    let folder = try #require(make(kind: .items, selection: [url("/d")]))
    #expect(!folder.editorsFirst)
    #expect(folder.orderedApplications.first?.kind == .terminal)
    var off = OpenHereSettings()
    off.smartMenu = false
    #expect(try #require(make(off, kind: .items, selection: [url("/f.txt")])).editorsFirst == false)
  }

  @Test func toolbarHonoursItsOwnSelection() throws {
    var settings = OpenHereSettings()
    settings.enabledApplicationIDs = ["terminal", "ghostty", "vscode"]
    settings.toolbarApplicationIDs = ["ghostty"]
    let toolbar = try #require(make(settings, kind: .toolbar))
    #expect(toolbar.orderedApplications.map(\.id) == ["ghostty"])
    let context = try #require(make(settings))
    #expect(context.orderedApplications.map(\.id) == ["terminal", "ghostty", "vscode"])
  }

  @Test func togglesHideMenus() {
    var settings = OpenHereSettings()
    settings.showContextMenu = false
    #expect(make(settings) == nil)
    #expect(make(settings, kind: .toolbar) != nil)
    settings.showToolbarAction = false
    #expect(make(settings, kind: .toolbar) == nil)
  }

  @Test func toolbarIsFlatWithoutCopyItems() throws {
    let model = try #require(make(kind: .toolbar))
    #expect(!model.usesSubmenu)
    #expect(model.copyStyles.isEmpty)
    let context = try #require(make(kind: .items, selection: [url("/d")]))
    #expect(context.usesSubmenu)
    #expect(context.copyStyles == PathCopyStyle.allCases)
  }
}
