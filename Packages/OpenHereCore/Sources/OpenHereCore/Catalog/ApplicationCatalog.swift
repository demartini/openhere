import Foundation

/// Built-in plus user-defined applications, in the order the user configured.
public struct ApplicationCatalog: Sendable, Equatable {
  public let applications: [ApplicationDefinition]

  public init(settings: OpenHereSettings) {
    var seen = Set<String>()
    let merged = (BuiltInApplications.all + settings.customApplications).filter {
      seen.insert($0.id).inserted
    }
    let position = Dictionary(
      settings.applicationOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    // Stable sort: unknown ids keep their catalog position after the ordered ones.
    self.applications = merged.enumerated().sorted { lhs, rhs in
      let l = position[lhs.element.id] ?? Int.max
      let r = position[rhs.element.id] ?? Int.max
      return l == r ? lhs.offset < rhs.offset : l < r
    }.map(\.element)
  }

  public func application(id: String) -> ApplicationDefinition? {
    applications.first { $0.id == id }
  }

  public func applications(of kind: ApplicationKind) -> [ApplicationDefinition] {
    applications.filter { $0.kind == kind }
  }

  /// The application used by "open here" without a specific choice. Falls back to the first
  /// installed application of the requested kind when the configured default disappeared.
  public func effectiveDefault(
    kind: ApplicationKind,
    settings: OpenHereSettings,
    isInstalled: (ApplicationDefinition) -> Bool
  ) -> ApplicationDefinition? {
    let preferredID = kind == .editor ? settings.defaultEditorID : settings.defaultTerminalID
    if let preferred = application(id: preferredID), preferred.kind == kind, isInstalled(preferred) {
      return preferred
    }
    return applications(of: kind).first { settings.isEnabled($0.id) && isInstalled($0) }
      ?? applications(of: kind).first(where: isInstalled)
  }
}
