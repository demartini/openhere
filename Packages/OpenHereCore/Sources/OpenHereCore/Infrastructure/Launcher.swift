import AppKit
import Foundation

public protocol WorkspaceOpening: Sendable {
  func open(_ urls: [URL], withApplicationAt applicationURL: URL, newInstance: Bool) async throws
}

public protocol ProcessRunning: Sendable {
  /// Runs `executable` with separate `arguments`; throws when it exits with a non-zero status.
  func run(executable: URL, arguments: [String]) async throws
}

/// Opens things with applications. Every strategy avoids shells and script interpreters: paths
/// only ever travel as `URL`s or as individual `argv` entries.
public struct Launcher: Sendable {
  private let locator: any ApplicationLocating
  private let workspace: any WorkspaceOpening
  private let process: any ProcessRunning
  private let fileSystem: any FileSystemInspecting

  public init(
    locator: any ApplicationLocating = WorkspaceApplicationLocator(),
    workspace: any WorkspaceOpening = SystemWorkspaceOpener(),
    process: any ProcessRunning = SystemProcessRunner(),
    fileSystem: any FileSystemInspecting = LocalFileSystem()
  ) {
    self.locator = locator
    self.workspace = workspace
    self.process = process
    self.fileSystem = fileSystem
  }

  public func launch(_ request: LaunchRequest) async throws {
    let application = request.application
    guard let applicationURL = locator.url(for: application) else {
      OpenHereLog.error(.launcher, "Application missing", detail: application.bundleIdentifier)
      throw LaunchError.applicationNotInstalled(name: application.name)
    }

    let urls = request.urls
    guard !urls.isEmpty else { throw LaunchError.targetMissing }
    for url in urls {
      guard url.isFileURL, url.path.hasPrefix("/") else { throw LaunchError.invalidPath }
      guard fileSystem.isDirectory(url) != nil else { throw LaunchError.targetMissing }
    }

    OpenHereLog.debug(.launcher, "Launching", detail: "\(application.id) \(urls.map(\.path))")
    do {
      switch application.strategy {
      case .workspace:
        try await workspace.open(
          urls, withApplicationAt: applicationURL, newInstance: request.behavior == .newInstance)

      case .processArguments(let template, let newInstance):
        for url in urls {
          var arguments = [String]()
          if newInstance || request.behavior == .newInstance { arguments.append("-n") }
          arguments += ["-a", applicationURL.path, "--args"]
          arguments += LaunchTemplate.expand(arguments: template, path: url.path)
          try await process.run(executable: URL(fileURLWithPath: "/usr/bin/open"), arguments: arguments)
        }

      case .urlScheme(let template):
        let links = try urls.map { url -> URL in
          guard let link = LaunchTemplate.expand(urlTemplate: template, path: url.path) else {
            throw LaunchError.invalidPath
          }
          return link
        }
        try await workspace.open(
          links, withApplicationAt: applicationURL, newInstance: request.behavior == .newInstance)
      }
    } catch let error as LaunchError {
      throw error
    } catch {
      OpenHereLog.error(.launcher, "Launch failed", detail: "\(application.id) \(error)")
      throw LaunchError.launchFailed(name: application.name, reason: error.localizedDescription)
    }
  }

  public func launch(_ requests: [LaunchRequest]) async throws {
    for request in requests { try await launch(request) }
  }
}

public enum LaunchTemplate {
  public static let placeholder = "{path}"

  /// Substitutes `{path}` in each argument. The result has exactly as many entries as the template.
  public static func expand(arguments: [String], path: String) -> [String] {
    arguments.map { $0.replacingOccurrences(of: placeholder, with: path) }
  }

  public static func expand(urlTemplate: String, path: String) -> URL? {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "?#&=+")
    guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
    return URL(string: urlTemplate.replacingOccurrences(of: placeholder, with: encoded))
  }
}

// MARK: - System implementations

public struct SystemWorkspaceOpener: WorkspaceOpening {
  public init() {}

  public func open(_ urls: [URL], withApplicationAt applicationURL: URL, newInstance: Bool)
    async throws
  {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = newInstance
    try await NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration)
  }
}

public struct SystemProcessRunner: ProcessRunning {
  public init() {}

  public func run(executable: URL, arguments: [String]) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let process = Process()
      process.executableURL = executable
      process.arguments = arguments
      process.standardInput = FileHandle.nullDevice
      process.standardOutput = FileHandle.nullDevice
      let errorPipe = Pipe()
      process.standardError = errorPipe
      process.terminationHandler = { finished in
        if finished.terminationStatus == 0 {
          continuation.resume()
        } else {
          let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let message =
            String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          continuation.resume(
            throwing: LaunchError.launchFailed(
              name: executable.lastPathComponent,
              reason: message.isEmpty ? "exit status \(finished.terminationStatus)" : message))
        }
      }
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
