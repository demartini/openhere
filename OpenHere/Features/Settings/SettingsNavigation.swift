import Observation

/// Which Settings pane is showing; lets menus (About, Help) open a specific pane.
@MainActor
@Observable
final class SettingsNavigation {
  var selection: SettingsPane? = .general
}
