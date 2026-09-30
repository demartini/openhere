import AppKit
import OpenHereCore
import SwiftUI

extension View {
  /// Liquid Glass call-to-action on macOS 26+, standard prominent button before that.
  @ViewBuilder
  func prominentActionStyle() -> some View {
    if #available(macOS 26, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }

  @ViewBuilder
  func secondaryActionStyle() -> some View {
    if #available(macOS 26, *) {
      buttonStyle(.glass)
    } else {
      buttonStyle(.bordered)
    }
  }

  /// Rounded card used for grouped content.
  func card() -> some View {
    padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct OnboardingView: View {
  @Bindable var model: SettingsModel
  let onFinish: () -> Void

  private enum Step: Int, CaseIterable { case welcome, applications, finder, shortcut, done }

  @State private var step: Step = .welcome
  @State private var extensionEnabled = FinderExtensionStatus.isEnabled

  var body: some View {
    VStack(spacing: 0) {
      Group {
        switch step {
        case .welcome: welcome
        case .applications: applications
        case .finder: finder
        case .shortcut: shortcut
        case .done: done
        }
      }
      .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
      .id(step)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 40)
      .padding(.top, 44)

      footer
    }
    .frame(width: 600, height: 520)
    .background(.background)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      extensionEnabled = FinderExtensionStatus.isEnabled
    }
  }

  // MARK: Footer

  private var footer: some View {
    HStack {
      Button("Back") { move(-1) }
        .secondaryActionStyle()
        .opacity(step == .welcome || step == .done ? 0 : 1)
        .disabled(step == .welcome || step == .done)
      Spacer()
      HStack(spacing: 7) {
        ForEach(Step.allCases, id: \.rawValue) { item in
          Circle().fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
        }
      }
      .accessibilityHidden(true)
      Spacer()
      if step == .done {
        Button("Done", action: finish).keyboardShortcut(.defaultAction).prominentActionStyle()
      } else {
        Button(step == .welcome ? LocalizedStringKey("Get Started") : LocalizedStringKey("Continue")) { move(1) }
          .keyboardShortcut(.defaultAction).prominentActionStyle()
      }
    }
    .controlSize(.large)
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
  }

  private func move(_ delta: Int) {
    guard let next = Step(rawValue: step.rawValue + delta) else { return }
    withAnimation(.smooth(duration: 0.3)) { step = next }
  }

  private func finish() {
    model.settings.onboardingCompleted = true
    onFinish()
  }

  // MARK: Steps

  private func header(_ symbol: String, tint: Color, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
    VStack(spacing: 10) {
      SettingsIcon(symbol: symbol, tint: tint).scaleEffect(1.9).frame(width: 52, height: 52)
      Text(title).font(.title.bold())
      Text(subtitle).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
  }

  private var welcome: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
      Text("OpenHere").font(.system(size: 40, weight: .bold, design: .rounded))
      Text("Open your workspace faster.").font(.title3).foregroundStyle(.secondary)
      Text("Terminal · Editor · Finder").font(.callout).foregroundStyle(.tertiary)
      Spacer()
    }
  }

  private var applications: some View {
    VStack(spacing: 22) {
      header(
        "square.grid.2x2.fill", tint: .blue, "Choose your applications",
        "These open when you click the toolbar button or use the shortcut. You can change them any time in Settings.")
      VStack(spacing: 0) {
        picker("Default terminal", symbol: "terminal.fill", selection: $model.settings.defaultTerminalID, kind: .terminal)
        Divider().padding(.leading, 44)
        picker("Default editor", symbol: "chevron.left.forwardslash.chevron.right", selection: $model.settings.defaultEditorID, kind: .editor)
      }
      .card()
      Text("Other applications can be added later in Settings › Applications.")
        .font(.caption).foregroundStyle(.secondary)
      Spacer()
    }
  }

  private func picker(_ title: LocalizedStringKey, symbol: String, selection: Binding<String>, kind: ApplicationKind) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
      Text(title)
      Spacer()
      Picker(title, selection: selection) {
        ForEach(model.installedApplications(of: kind)) { Text($0.name).tag($0.id) }
      }
      .labelsHidden().fixedSize()
      .onChange(of: selection.wrappedValue) { _, id in model.ensureShown(id) }
    }
    .padding(.vertical, 8)
  }

  private var finder: some View {
    VStack(spacing: 22) {
      header(
        "face.smiling.inverse", tint: .cyan, "Finder integration",
        "Enable the OpenHere extension so it appears in Finder's context menu and toolbar.")
      VStack(alignment: .leading, spacing: 14) {
        if extensionEnabled {
          Label("Extension enabled", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
        } else {
          Button("Open Finder Extension Settings…", action: FinderExtensionStatus.openManagementInterface)
            .prominentActionStyle().controlSize(.large)
        }
        Text("Then, in Finder, choose View › Customize Toolbar… and drag “Open Here” into the toolbar.")
          .foregroundStyle(.secondary)
      }
      .card()
      Text("macOS only asks for extra permissions when you first use a feature that needs them (for example, controlling Finder from the shortcut).")
        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Spacer()
    }
  }

  private var shortcut: some View {
    VStack(spacing: 22) {
      header(
        "command", tint: .orange, "Keyboard shortcut",
        "The shortcut opens the selected item, or the current Finder folder, in your default terminal.")
      VStack(spacing: 12) {
        Toggle("Enable keyboard shortcut", isOn: $model.settings.shortcut.isEnabled)
        Divider()
        LabeledContent("Shortcut") {
          ShortcutRecorder(configuration: $model.settings.shortcut).frame(width: 160)
        }
        .disabled(!model.settings.shortcut.isEnabled)
        Divider()
        Toggle("Only active when Finder is focused", isOn: $model.settings.shortcut.onlyWhenFinderIsFocused)
          .disabled(!model.settings.shortcut.isEnabled)
      }
      .toggleStyle(.switch)
      .card()
      Spacer()
    }
  }

  private var done: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "checkmark.circle.fill").font(.system(size: 72)).foregroundStyle(.green.gradient)
        .symbolEffect(.bounce, value: step)
      Text("You're ready.").font(.system(size: 34, weight: .bold, design: .rounded))
      Text("Open any Finder folder with OpenHere.").font(.title3).foregroundStyle(.secondary)
      Spacer()
    }
  }
}
