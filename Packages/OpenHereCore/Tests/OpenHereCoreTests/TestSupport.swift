import Foundation

@testable import OpenHereCore

/// In-memory file system: paths ending in `/` are directories.
struct FakeFileSystem: FileSystemInspecting {
  var directories: Set<String> = []
  var files: Set<String> = []

  func isDirectory(_ url: URL) -> Bool? {
    if directories.contains(url.path) { return true }
    if files.contains(url.path) { return false }
    return nil
  }
}

struct FakeLocator: ApplicationLocating {
  var installed: [String: URL] = [:]
  func url(for application: ApplicationDefinition) -> URL? { installed[application.bundleIdentifier] }
}

final class RecordingWorkspace: WorkspaceOpening, @unchecked Sendable {
  struct Call: Equatable { var urls: [URL]; var app: URL; var newInstance: Bool }
  private(set) var calls: [Call] = []
  func open(_ urls: [URL], withApplicationAt applicationURL: URL, newInstance: Bool) async throws {
    calls.append(Call(urls: urls, app: applicationURL, newInstance: newInstance))
  }
}

final class RecordingProcess: ProcessRunning, @unchecked Sendable {
  struct Call: Equatable { var executable: URL; var arguments: [String] }
  private(set) var calls: [Call] = []
  func run(executable: URL, arguments: [String]) async throws {
    calls.append(Call(executable: executable, arguments: arguments))
  }
}
