import AppKit
import OpenHereCore
import SwiftUI
import UniformTypeIdentifiers

struct AddApplicationSheet: View {
  let onAdd: (ApplicationDefinition) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var applicationURL: URL?
  @State private var kind: ApplicationKind = .editor
  @State private var usesArguments = false
  @State private var arguments = "{path}"
  @State private var newInstance = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Add Application").font(.title3.bold())

      Form {
        TextField("Name", text: $name)

        LabeledContent("Application") {
          HStack {
            if let applicationURL {
              ApplicationIcon(url: applicationURL)
              Text(applicationURL.deletingPathExtension().lastPathComponent)
            }
            Button("Choose…", action: chooseApplication)
          }
        }

        Picker("Type", selection: $kind) {
          Text("Terminal").tag(ApplicationKind.terminal)
          Text("Editor").tag(ApplicationKind.editor)
          Text("Other").tag(ApplicationKind.custom)
        }

        Toggle("Pass the location as command-line arguments", isOn: $usesArguments)
        if usesArguments {
          VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $arguments)
              .font(.system(.body, design: .monospaced))
              .frame(height: 64)
              .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            Text(
              "One argument per line. Use {path} where the folder or file belongs. Arguments are never interpreted by a shell."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          Toggle("Always start a new instance", isOn: $newInstance)
        }
      }
      .formStyle(.grouped)

      if let errorMessage {
        Text(errorMessage).foregroundStyle(.red).font(.callout)
      }

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Save", action: save)
          .keyboardShortcut(.defaultAction)
          .disabled(applicationURL == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(20)
    .frame(width: 460)
  }

  private func chooseApplication() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    applicationURL = url
    if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
  }

  private func save() {
    guard let applicationURL else { return }
    let mode: CustomApplicationFactory.LaunchMode =
      usesArguments
      ? .arguments(arguments.split(separator: "\n").map(String.init), newInstance: newInstance)
      : .standard
    do {
      onAdd(
        try CustomApplicationFactory.make(
          name: name, applicationURL: applicationURL, kind: kind, mode: mode))
      dismiss()
    } catch CustomApplicationError.missingPathPlaceholder {
      errorMessage = String(localized: "At least one argument must contain {path}.")
    } catch {
      errorMessage = String(localized: "Please choose a valid application and name.")
    }
  }
}
