import Foundation

public enum CustomApplicationError: Error, Equatable, Sendable {
  case notAnApplication
  case emptyName
  case missingPathPlaceholder
}

/// Validates and builds user-defined application definitions.
public enum CustomApplicationFactory {
  public enum LaunchMode: Equatable, Sendable {
    /// Same as Finder's "Open With".
    case standard
    /// Run with arguments; one entry per element and at least one must contain `{path}`.
    case arguments([String], newInstance: Bool)
  }

  public static func make(
    name: String,
    applicationURL: URL,
    kind: ApplicationKind,
    mode: LaunchMode,
    id: String = "custom." + UUID().uuidString.lowercased()
  ) throws -> ApplicationDefinition {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CustomApplicationError.emptyName }
    guard applicationURL.pathExtension == "app", let bundle = Bundle(url: applicationURL),
      let bundleID = bundle.bundleIdentifier
    else { throw CustomApplicationError.notAnApplication }

    let strategy: LaunchStrategy
    switch mode {
    case .standard:
      strategy = .workspace
    case .arguments(let arguments, let newInstance):
      let cleaned = arguments.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
      guard cleaned.contains(where: { $0.contains(LaunchTemplate.placeholder) }) else {
        throw CustomApplicationError.missingPathPlaceholder
      }
      strategy = .processArguments(arguments: cleaned, newInstance: newInstance)
    }

    return ApplicationDefinition(
      id: id, name: trimmed, bundleIdentifier: bundleID, kind: kind,
      capabilities: kind == .terminal
        ? ApplicationDefinition.terminalCapabilities : ApplicationDefinition.editorCapabilities,
      strategy: strategy, applicationPath: applicationURL.path)
  }
}
