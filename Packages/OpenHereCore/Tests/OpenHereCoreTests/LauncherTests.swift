import Foundation
import Testing

@testable import OpenHereCore

struct LauncherTests {
  private let fs = FakeFileSystem(directories: ["/p/My Project"], files: ["/p/a.txt"])
  private let workspace = RecordingWorkspace()
  private let process = RecordingProcess()

  private func launcher(installed: [String: URL]) -> Launcher {
    Launcher(
      locator: FakeLocator(installed: installed), workspace: workspace, process: process,
      fileSystem: fs)
  }

  private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

  @Test func workspaceStrategyPassesURLsUntouched() async throws {
    let ghostty = try #require(BuiltInApplications.terminals.first { $0.id == "ghostty" })
    let appURL = url("/Applications/Ghostty.app")
    try await launcher(installed: [ghostty.bundleIdentifier: appURL]).launch(
      LaunchRequest(target: .directory(url("/p/My Project")), application: ghostty))
    #expect(
      workspace.calls == [.init(urls: [url("/p/My Project")], app: appURL, newInstance: false)])
    #expect(process.calls.isEmpty)
  }

  @Test func processStrategyKeepsPathAsSingleArgument() async throws {
    let kitty = try #require(BuiltInApplications.terminals.first { $0.id == "kitty" })
    let appURL = url("/Applications/kitty.app")
    try await launcher(installed: [kitty.bundleIdentifier: appURL]).launch(
      LaunchRequest(target: .directory(url("/p/My Project")), application: kitty))
    #expect(
      process.calls == [
        .init(
          executable: url("/usr/bin/open"),
          arguments: ["-n", "-a", "/Applications/kitty.app", "--args", "--directory", "/p/My Project"])
      ])
  }

  @Test func missingApplicationThrowsWithoutLaunching() async {
    let zed = BuiltInApplications.editors.first { $0.id == "zed" }!
    await #expect(throws: LaunchError.applicationNotInstalled(name: "Zed")) {
      try await launcher(installed: [:]).launch(
        LaunchRequest(target: .file(url("/p/a.txt")), application: zed))
    }
    #expect(workspace.calls.isEmpty)
  }

  @Test func missingTargetThrows() async {
    let zed = BuiltInApplications.editors.first { $0.id == "zed" }!
    await #expect(throws: LaunchError.targetMissing) {
      try await launcher(installed: [zed.bundleIdentifier: url("/Applications/Zed.app")]).launch(
        LaunchRequest(target: .file(url("/p/gone.txt")), application: zed))
    }
  }

  @Test func newInstanceBehaviorIsForwarded() async throws {
    let terminal = BuiltInApplications.terminals[0]
    let appURL = url("/System/Applications/Utilities/Terminal.app")
    try await launcher(installed: [terminal.bundleIdentifier: appURL]).launch(
      LaunchRequest(
        target: .directory(url("/p/My Project")), application: terminal, behavior: .newInstance))
    #expect(workspace.calls.first?.newInstance == true)
  }

  @Test func urlSchemeStrategyEncodesPath() throws {
    let link = try #require(
      LaunchTemplate.expand(urlTemplate: "myeditor://open?path={path}", path: "/a b/c&d=e#f"))
    #expect(link.absoluteString == "myeditor://open?path=/a%20b/c%26d%3De%23f")
  }
}
