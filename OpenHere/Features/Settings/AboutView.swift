import OpenHereCore
import SwiftUI

struct AboutView: View {
  let updates: UpdateService

  private var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
  }

  private var build: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        hero
        section("Support") {
          linkRow(
            "ladybug.fill", "Report a bug or request a feature",
            ProjectLinks.newIssue)
        }
        section("Project") {
          linkRow("chevron.left.forwardslash.chevron.right", "Source code", ProjectLinks.repository)
          Divider()
          linkRow("sparkles", "Release notes", ProjectLinks.releases)
          Divider()
          linkRow("doc.text.fill", "MIT License", ProjectLinks.license)
        }
        Button("Check for Updates…") { updates.checkForUpdates() }
          .disabled(!updates.canCheckForUpdates)
          .secondaryActionStyle()
          .controlSize(.large)
      }
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 28)
      .padding(.vertical, 24)
    }
  }

  private var hero: some View {
    VStack(spacing: 8) {
      Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
      Text("OpenHere").font(.system(size: 30, weight: .bold, design: .rounded))
      Text("Version \(version) (Build \(build))").font(.callout).foregroundStyle(.secondary)
      Text("Made with ❤️ by Iolar Demartini Junior").font(.footnote).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
  }

  private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.title3.weight(.semibold))
      VStack(spacing: 0) { content() }.card()
    }
  }

  private func linkRow(_ symbol: String, _ title: LocalizedStringKey, _ url: URL) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
      Text(title)
      Spacer()
      Button("View") { NSWorkspace.shared.open(url) }
        .buttonStyle(.bordered).controlSize(.regular)
    }
    .padding(.vertical, 6)
  }
}
