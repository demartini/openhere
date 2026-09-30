import Foundation

/// What Finder tells us about the current situation.
public struct FinderContext: Sendable, Equatable {
  public var selection: [URL]
  /// Folder shown by the frontmost Finder window (Finder Sync `targetedURL`).
  public var windowDirectory: URL?

  public init(selection: [URL] = [], windowDirectory: URL? = nil) {
    self.selection = selection
    self.windowDirectory = windowDirectory
  }
}

public protocol FileSystemInspecting: Sendable {
  /// `true` for directories (following symlinks), `false` for files, `nil` when nothing exists.
  func isDirectory(_ url: URL) -> Bool?
}

public struct LocalFileSystem: FileSystemInspecting {
  public init() {}

  public func isDirectory(_ url: URL) -> Bool? {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
    return isDir.boolValue
  }
}

/// Selection first, then the Finder window's folder, then the Desktop.
public struct OpenTargetResolver: Sendable {
  private let fileSystem: any FileSystemInspecting
  private let desktopDirectory: URL

  public init(
    fileSystem: any FileSystemInspecting = LocalFileSystem(),
    desktopDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Desktop", directoryHint: .isDirectory)
  ) {
    self.fileSystem = fileSystem
    self.desktopDirectory = desktopDirectory
  }

  public func resolve(_ context: FinderContext) -> OpenTarget {
    var seen = Set<String>()
    let items = context.selection
      .filter(\.isFileURL)
      .map(\.standardizedFileURL)
      .filter { fileSystem.isDirectory($0) != nil && seen.insert($0.path).inserted }

    switch items.count {
    case 0:
      return .finderLocation(fallbackDirectory(context.windowDirectory))
    case 1:
      let item = items[0]
      return fileSystem.isDirectory(item) == true ? .directory(item) : .file(item)
    default:
      return .multipleFiles(items)
    }
  }

  private func fallbackDirectory(_ candidate: URL?) -> URL {
    guard let candidate, candidate.isFileURL else { return desktopDirectory }
    let url = candidate.standardizedFileURL
    switch fileSystem.isDirectory(url) {
    case true: return url
    case false: return url.deletingLastPathComponent()
    case nil: return desktopDirectory
    }
  }
}
