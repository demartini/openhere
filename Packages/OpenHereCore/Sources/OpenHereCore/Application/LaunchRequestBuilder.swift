import Foundation

/// Adapts an `OpenTarget` to what a given application can actually open.
public struct LaunchRequestBuilder: Sendable {
  /// Upper bound of windows one click may create (e.g. 500 files selected + a terminal).
  public static let maximumRequests = 8

  private let fileSystem: any FileSystemInspecting

  public init(fileSystem: any FileSystemInspecting = LocalFileSystem()) {
    self.fileSystem = fileSystem
  }

  public func requests(
    for target: OpenTarget,
    application: ApplicationDefinition,
    behavior: LaunchBehavior = .newWindow
  ) -> [LaunchRequest] {
    let capabilities = application.capabilities
    let urls = target.urls

    // Terminals open folders only: files map to the folder that contains them.
    if !capabilities.contains(.opensFiles) {
      var seen = Set<String>()
      let directories = urls.map(directory(for:)).filter { seen.insert($0.path).inserted }
      return directories.prefix(Self.maximumRequests).map {
        LaunchRequest(target: .directory($0), application: application, behavior: behavior)
      }
    }

    if urls.count > 1 && !capabilities.contains(.opensMultipleItems) {
      return urls.prefix(Self.maximumRequests).map {
        LaunchRequest(target: single($0), application: application, behavior: behavior)
      }
    }

    return [LaunchRequest(target: target, application: application, behavior: behavior)]
  }

  private func directory(for url: URL) -> URL {
    fileSystem.isDirectory(url) == false
      ? URL(fileURLWithPath: url.deletingLastPathComponent().path) : url
  }

  private func single(_ url: URL) -> OpenTarget {
    fileSystem.isDirectory(url) == true ? .directory(url) : .file(url)
  }
}
