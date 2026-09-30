import OpenHereCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
  case general, applications, shortcuts, finder, advanced, about

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .general: "General"
    case .applications: "Applications"
    case .shortcuts: "Shortcuts"
    case .finder: "Finder"
    case .advanced: "Advanced"
    case .about: "About"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape.fill"
    case .applications: "square.grid.2x2.fill"
    case .shortcuts: "command"
    case .finder: "face.smiling.inverse"
    case .advanced: "wrench.and.screwdriver.fill"
    case .about: "info.circle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .general: .gray
    case .applications: .blue
    case .shortcuts: .orange
    case .finder: .cyan
    case .advanced: .indigo
    case .about: .blue
    }
  }
}

/// System Settings–style icon: a tinted rounded square with a white glyph.
struct SettingsIcon: View {
  let symbol: String
  let tint: Color
  var size: CGFloat = 26

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: size * 0.5, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
      .accessibilityHidden(true)
  }
}

struct SettingsView: View {
  @Bindable var model: SettingsModel
  let environment: AppEnvironment
  @Bindable var navigation: SettingsNavigation

  private var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  }

  var body: some View {
    NavigationSplitView {
      List(SettingsPane.allCases, selection: $navigation.selection) { pane in
        Label {
          Text(pane.title)
        } icon: {
          SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 20)
        }
        .tag(pane)
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Text("OpenHere \(version)")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16).padding(.vertical, 10)
      }
    } detail: {
      detail(for: navigation.selection ?? .general)
        .navigationTitle(Text((navigation.selection ?? .general).title))
        .scrollContentBackground(.hidden)
    }
    .frame(minWidth: 740, minHeight: 500)
  }

  @ViewBuilder
  private func detail(for pane: SettingsPane) -> some View {
    switch pane {
    case .general: GeneralSettingsView(model: model, updates: environment.updates)
    case .applications: ApplicationsSettingsView(model: model)
    case .shortcuts: ShortcutsSettingsView(model: model)
    case .finder: FinderSettingsView(model: model)
    case .advanced: AdvancedSettingsView(model: model)
    case .about: AboutView(updates: environment.updates)
    }
  }
}

// MARK: - General

struct GeneralSettingsView: View {
  @Bindable var model: SettingsModel
  let updates: UpdateService
  @State private var launchAtLogin = LoginItem.isEnabled
  @State private var loginError: String?

  var body: some View {
    Form {
      Section("Default applications") {
        Picker("Default terminal", selection: $model.settings.defaultTerminalID) {
          ForEach(model.installedApplications(of: .terminal)) { Text($0.name).tag($0.id) }
        }
        .onChange(of: model.settings.defaultTerminalID) { _, id in model.ensureShown(id) }
        Picker("Default editor", selection: $model.settings.defaultEditorID) {
          ForEach(model.installedApplications(of: .editor)) { Text($0.name).tag($0.id) }
        }
        .onChange(of: model.settings.defaultEditorID) { _, id in model.ensureShown(id) }
        Picker("Launch behavior", selection: $model.settings.launchBehavior) {
          Text("Reuse the running application").tag(LaunchBehavior.newWindow)
          Text("Always start a new instance").tag(LaunchBehavior.newInstance)
        }
      }

      Section("Startup") {
        Toggle("Open OpenHere at login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, enabled in
            do {
              try LoginItem.setEnabled(enabled)
              loginError = nil
            } catch {
              launchAtLogin = LoginItem.isEnabled
              loginError = error.localizedDescription
            }
          }
        if LoginItem.requiresApproval {
          Button("Approve in System Settings…", action: LoginItem.openSystemSettings)
        }
        if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
        Text("The keyboard shortcut and menu bar item need OpenHere to be running.")
          .font(.caption).foregroundStyle(.secondary)
        Toggle("Show icon in the menu bar", isOn: $model.settings.showMenuBarIcon)
      }

      Section("Updates") {
        @Bindable var updates = updates
        Toggle("Check for updates automatically", isOn: $updates.automaticallyChecksForUpdates)
        HStack {
          Button("Check Now") { updates.checkForUpdates() }
            .disabled(!updates.canCheckForUpdates)
          Spacer()
        }
        Text("Updates are downloaded from GitHub Releases and verified with an EdDSA signature.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Applications

struct ApplicationsSettingsView: View {
  @Bindable var model: SettingsModel
  @State private var showingAddSheet = false

  var body: some View {
    List {
      Text("Choose which applications appear in Finder's context menu and in the toolbar menu. Only installed applications can be selected.")
        .font(.caption).foregroundStyle(.secondary)
      section("Terminals", kind: .terminal)
      section("Editors", kind: .editor)
      Section {
        ForEach(model.catalog.applications(of: .custom)) { application in
          row(application)
        }
        .onMove { model.moveApplications(of: .custom, from: $0, to: $1) }
        Button("Add Application…", systemImage: "plus") { showingAddSheet = true }
          .buttonStyle(.borderless)
      } header: {
        columnHeader("Custom")
      }
    }
    .listStyle(.inset)
    .sheet(isPresented: $showingAddSheet) {
      AddApplicationSheet { model.add($0) }
    }
  }

  private func section(_ title: LocalizedStringKey, kind: ApplicationKind) -> some View {
    Section {
      ForEach(model.catalog.applications(of: kind)) { application in
        row(application)
      }
      .onMove { model.moveApplications(of: kind, from: $0, to: $1) }
    } header: {
      columnHeader(title)
    }
  }

  private func columnHeader(_ title: LocalizedStringKey) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text("Context menu").frame(width: 100)
      Text("Toolbar").frame(width: 70)
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(.secondary)
  }

  private func row(_ application: ApplicationDefinition) -> some View {
    let installed = model.isInstalled(application)
    return HStack {
      ApplicationIcon(url: model.applicationURL(application), size: 24)
      Text(application.name)
      if !installed {
        Text("Not installed").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Toggle(
        "Context menu",
        isOn: Binding(
          get: { model.settings.isEnabled(application.id) },
          set: { model.setEnabled($0, for: application) })
      )
      .toggleStyle(.checkbox).labelsHidden().frame(width: 100)
      .disabled(!installed)
      Toggle(
        "Toolbar",
        isOn: Binding(
          get: { model.settings.isInToolbar(application.id) },
          set: { model.setInToolbar($0, for: application) })
      )
      .toggleStyle(.checkbox).labelsHidden().frame(width: 70)
      .disabled(!installed)
      if application.isUserDefined {
        Button("Remove", systemImage: "trash", role: .destructive) { model.remove(application) }
          .labelStyle(.iconOnly).buttonStyle(.borderless)
      }
    }
    .opacity(installed ? 1 : 0.6)
  }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
  @Bindable var model: SettingsModel
  @State private var rejected = false

  var body: some View {
    Form {
      Section {
        Toggle("Enable keyboard shortcut", isOn: $model.settings.shortcut.isEnabled)
        LabeledContent("Shortcut") {
          ShortcutRecorder(configuration: $model.settings.shortcut) { rejected = true }
            .frame(width: 160)
        }
        .disabled(!model.settings.shortcut.isEnabled)
        Picker("Opens with", selection: $model.settings.shortcut.target) {
          Text("Default terminal").tag(ShortcutTarget.terminal)
          Text("Default editor").tag(ShortcutTarget.editor)
        }
        .disabled(!model.settings.shortcut.isEnabled)
        Toggle("Only active when Finder is focused", isOn: $model.settings.shortcut.onlyWhenFinderIsFocused)
          .disabled(!model.settings.shortcut.isEnabled)
        if !model.settings.shortcut.onlyWhenFinderIsFocused {
          Text("A global shortcut can conflict with other applications.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }

      Section {
        statusView
        Button("Reset to ⇧⌘O") {
          model.settings.shortcut.keyCode = ShortcutConfiguration.default.keyCode
          model.settings.shortcut.carbonModifiers = ShortcutConfiguration.default.carbonModifiers
          rejected = false
        }
        Text(
          "Opens the selected item, or the folder of the frontmost Finder window. The first use asks for permission to control Finder."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .onChange(of: model.settings.shortcut) { _, _ in rejected = false }
  }

  @ViewBuilder
  private var statusView: some View {
    if rejected {
      Label("Shortcuts must include ⌘ or ⌃.", systemImage: "exclamationmark.triangle")
        .foregroundStyle(.orange)
    } else {
      switch model.shortcutStatus {
      case .conflict:
        Label(
          "This shortcut is already used by another application.", systemImage: "exclamationmark.triangle"
        )
        .foregroundStyle(.orange)
      case .failed:
        Label("The shortcut could not be registered.", systemImage: "xmark.octagon").foregroundStyle(.red)
      case .active:
        Label("Shortcut is active.", systemImage: "checkmark.circle").foregroundStyle(.green)
      case .inactive:
        if model.settings.shortcut.isEnabled && model.settings.shortcut.onlyWhenFinderIsFocused {
          Label("Becomes active when Finder is in front.", systemImage: "info.circle")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

// MARK: - Finder

struct FinderSettingsView: View {
  @Bindable var model: SettingsModel
  @State private var extensionEnabled = FinderExtensionStatus.isEnabled

  var body: some View {
    Form {
      Section("Extension") {
        LabeledContent("Status") {
          if extensionEnabled {
            Label("Enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
          } else {
            Label("Disabled", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
          }
        }
        Button("Open Finder Extension Settings…", action: FinderExtensionStatus.openManagementInterface)
        Text(
          "To add the toolbar button, choose View › Customize Toolbar… in Finder and drag “Open Here” into the toolbar."
        )
        .font(.caption).foregroundStyle(.secondary)
      }

      Section("Menu") {
        Toggle("Show context menu", isOn: $model.settings.showContextMenu)
        Toggle("Use submenu", isOn: $model.settings.useSubmenu)
        Toggle("Show application icons", isOn: $model.settings.showIcons)
        Toggle("Show “Copy Path” items", isOn: $model.settings.showCopyPathItems)
        Toggle("Smart menu (editors first for files)", isOn: $model.settings.smartMenu)
        Toggle("Enable toolbar action", isOn: $model.settings.showToolbarAction)
        Picker("Toolbar button", selection: $model.settings.toolbarBehavior) {
          Text("Open with default terminal").tag(ToolbarBehavior.openDefaultTerminal)
          Text("Open with default editor").tag(ToolbarBehavior.openDefaultEditor)
          Text("Show a menu").tag(ToolbarBehavior.showMenu)
        }
        .disabled(!model.settings.showToolbarAction)
      }
    }
    .formStyle(.grouped)
    .onAppear { extensionEnabled = FinderExtensionStatus.isEnabled }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      extensionEnabled = FinderExtensionStatus.isEnabled
    }
  }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {
  @Bindable var model: SettingsModel
  @State private var confirmingReset = false

  private var version: String {
    let info = Bundle.main.infoDictionary
    return
      "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
  }

  var body: some View {
    Form {
      Section("Logging") {
        Picker("Level", selection: $model.settings.loggingLevel) {
          Text("Disabled").tag(LoggingLevel.disabled)
          Text("Errors only").tag(LoggingLevel.errorsOnly)
          Text("Debug").tag(LoggingLevel.debug)
        }
        Text("Paths are always marked private in the system log.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Diagnostics") {
        Button("Export Diagnostics…") { DiagnosticsExporter.export(settings: model.settings) }
        Text(
          "Includes version, system, extension status and configuration. It does not include your files' paths."
        )
        .font(.caption).foregroundStyle(.secondary)
      }

      Section("Configuration") {
        Button("Reset All Settings…", role: .destructive) { confirmingReset = true }
      }

      Section {
        LabeledContent("Version", value: version)
      }
    }
    .formStyle(.grouped)
    .confirmationDialog("Reset all settings?", isPresented: $confirmingReset) {
      Button("Reset", role: .destructive) { model.resetToDefaults() }
    } message: {
      Text("Custom applications and preferences will be removed.")
    }
  }
}
