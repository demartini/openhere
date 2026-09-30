import AppKit
import Foundation

public protocol ApplicationLocating: Sendable {
  func url(for application: ApplicationDefinition) -> URL?
}

extension ApplicationLocating {
  public func isInstalled(_ application: ApplicationDefinition) -> Bool {
    url(for: application) != nil
  }
}

/// Resolves applications through LaunchServices (fast, cached by the system, works in the sandbox).
public struct WorkspaceApplicationLocator: ApplicationLocating {
  public init() {}

  public func url(for application: ApplicationDefinition) -> URL? {
    if let path = application.applicationPath {
      var isDirectory: ObjCBool = false
      let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
      if exists, isDirectory.boolValue { return URL(fileURLWithPath: path) }
    }
    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier)
  }
}
