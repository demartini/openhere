import Foundation
import Testing

@testable import OpenHereCore

struct ResolverAndBuilderTests {
  private let desktop = URL(fileURLWithPath: "/Users/t/Desktop")
  private let fs = FakeFileSystem(
    directories: ["/Users/t/Desktop", "/Users/t/Projects", "/Users/t/Projects/App", "/Volumes/Disk/x"],
    files: [
      "/Users/t/Projects/README.md", "/Users/t/Projects/App/package.json", "/Users/t/Projects/Makefile",
    ])

  private func resolver() -> OpenTargetResolver {
    OpenTargetResolver(fileSystem: fs, desktopDirectory: desktop)
  }

  private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

  @Test func folderSelection() {
    let target = resolver().resolve(FinderContext(selection: [url("/Users/t/Projects")]))
    #expect(target == .directory(url("/Users/t/Projects")))
  }

  @Test func fileSelection() {
    let target = resolver().resolve(FinderContext(selection: [url("/Users/t/Projects/README.md")]))
    #expect(target == .file(url("/Users/t/Projects/README.md")))
  }

  @Test func fileWithoutExtension() {
    let target = resolver().resolve(FinderContext(selection: [url("/Users/t/Projects/Makefile")]))
    #expect(target == .file(url("/Users/t/Projects/Makefile")))
  }

  @Test func multipleSelectionIsDeduplicated() {
    let a = url("/Users/t/Projects/README.md")
    let target = resolver().resolve(FinderContext(selection: [a, a, url("/Users/t/Projects/App")]))
    #expect(target == .multipleFiles([a, url("/Users/t/Projects/App")]))
  }

  @Test func nothingSelectedUsesWindowDirectory() {
    let target = resolver().resolve(FinderContext(windowDirectory: url("/Volumes/Disk/x")))
    #expect(target == .finderLocation(url("/Volumes/Disk/x")))
  }

  @Test func noWindowFallsBackToDesktop() {
    #expect(resolver().resolve(FinderContext()) == .finderLocation(desktop))
    #expect(
      resolver().resolve(FinderContext(windowDirectory: url("/gone"))) == .finderLocation(desktop))
  }

  @Test func missingSelectionFallsBack() {
    let ctx = FinderContext(selection: [url("/gone")], windowDirectory: url("/Users/t/Projects"))
    #expect(resolver().resolve(ctx) == .finderLocation(url("/Users/t/Projects")))
  }

  @Test func terminalGetsParentOfFile() throws {
    let terminal = BuiltInApplications.terminals[0]
    let requests = LaunchRequestBuilder(fileSystem: fs).requests(
      for: .file(url("/Users/t/Projects/README.md")), application: terminal)
    #expect(requests.map(\.target) == [.directory(url("/Users/t/Projects"))])
  }

  @Test func terminalMultipleSelectionOpensUniqueDirectories() {
    let requests = LaunchRequestBuilder(fileSystem: fs).requests(
      for: .multipleFiles([
        url("/Users/t/Projects/README.md"), url("/Users/t/Projects/Makefile"),
        url("/Users/t/Projects/App"),
      ]),
      application: BuiltInApplications.terminals[0])
    #expect(
      requests.map(\.target) == [
        .directory(url("/Users/t/Projects")), .directory(url("/Users/t/Projects/App")),
      ])
  }

  @Test func editorGetsEverythingInOneRequest() {
    let target = OpenTarget.multipleFiles([url("/Users/t/Projects/README.md"), url("/Users/t/Projects/App")])
    let requests = LaunchRequestBuilder(fileSystem: fs).requests(
      for: target, application: BuiltInApplications.editors[0])
    #expect(requests.count == 1)
    #expect(requests[0].target == target)
  }

  @Test func windowCountIsCapped() {
    var big = FakeFileSystem()
    var urls: [URL] = []
    for i in 0..<50 {
      big.directories.insert("/d/\(i)")
      urls.append(url("/d/\(i)"))
    }
    let requests = LaunchRequestBuilder(fileSystem: big).requests(
      for: .multipleFiles(urls), application: BuiltInApplications.terminals[0])
    #expect(requests.count == LaunchRequestBuilder.maximumRequests)
  }
}
