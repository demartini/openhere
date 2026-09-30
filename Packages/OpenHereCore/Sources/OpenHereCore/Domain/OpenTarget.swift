import Foundation

/// What the user asked to open.
public enum OpenTarget: Sendable, Equatable {
  case directory(URL)
  case file(URL)
  case multipleFiles([URL])
  /// Nothing was selected: the folder shown by the Finder window (or the Desktop).
  case finderLocation(URL)

  public var urls: [URL] {
    switch self {
    case .directory(let url), .file(let url), .finderLocation(let url): [url]
    case .multipleFiles(let urls): urls
    }
  }
}

public enum LaunchBehavior: String, Codable, Sendable, CaseIterable, Hashable {
  /// Reuse the running application and ask it for a new window (default macOS behaviour).
  case newWindow
  /// Always start a separate instance of the application.
  case newInstance
}

public struct LaunchRequest: Sendable, Equatable {
  public var target: OpenTarget
  public var application: ApplicationDefinition
  public var behavior: LaunchBehavior

  public var urls: [URL] { target.urls }

  public init(
    target: OpenTarget,
    application: ApplicationDefinition,
    behavior: LaunchBehavior = .newWindow
  ) {
    self.target = target
    self.application = application
    self.behavior = behavior
  }
}

public enum LaunchError: Error, Equatable, Sendable {
  case applicationNotInstalled(name: String)
  case targetMissing
  case invalidPath
  case launchFailed(name: String, reason: String)
  case unknownApplication(id: String)
  case untrustedRequest
}

extension LaunchError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .applicationNotInstalled(let name):
      String(localized: "\(name) is not installed.", bundle: .main)
    case .targetMissing:
      String(localized: "The selected item no longer exists.", bundle: .main)
    case .invalidPath:
      String(localized: "The selected path is not valid.", bundle: .main)
    case .launchFailed(let name, let reason):
      String(localized: "Could not open \(name): \(reason)", bundle: .main)
    case .unknownApplication:
      String(localized: "The requested application is not configured.", bundle: .main)
    case .untrustedRequest:
      String(localized: "The request was not sent by the OpenHere Finder extension.", bundle: .main)
    }
  }
}
