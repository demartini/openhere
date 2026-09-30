import Foundation

/// The applications OpenHere knows out of the box.
/// To support a new one: add a definition here, choose a `LaunchStrategy`, add a test.
public enum BuiltInApplications {
  private static func terminal(
    _ id: String, _ name: String, _ bundleID: String, strategy: LaunchStrategy = .workspace
  ) -> ApplicationDefinition {
    ApplicationDefinition(
      id: id, name: name, bundleIdentifier: bundleID, kind: .terminal,
      capabilities: ApplicationDefinition.terminalCapabilities, strategy: strategy)
  }

  private static func editor(
    _ id: String, _ name: String, _ bundleID: String, strategy: LaunchStrategy = .workspace
  ) -> ApplicationDefinition {
    ApplicationDefinition(
      id: id, name: name, bundleIdentifier: bundleID, kind: .editor,
      capabilities: ApplicationDefinition.editorCapabilities, strategy: strategy)
  }

  public static let terminals: [ApplicationDefinition] = [
    terminal("terminal", "Terminal", "com.apple.Terminal"),
    terminal("iterm", "iTerm", "com.googlecode.iterm2"),
    terminal("ghostty", "Ghostty", "com.mitchellh.ghostty"),
    terminal("warp", "Warp", "dev.warp.Warp-Stable"),
    terminal(
      "wezterm", "WezTerm", "com.github.wez.wezterm",
      strategy: .processArguments(arguments: ["start", "--cwd", "{path}"], newInstance: true)),
    terminal(
      "kitty", "kitty", "net.kovidgoyal.kitty",
      strategy: .processArguments(arguments: ["--directory", "{path}"], newInstance: true)),
    terminal(
      "alacritty", "Alacritty", "org.alacritty",
      strategy: .processArguments(
        arguments: ["--working-directory", "{path}"], newInstance: true)),
    terminal("tabby", "Tabby", "org.tabby"),
    terminal("hyper", "Hyper", "co.zeit.hyper"),
  ]

  public static let editors: [ApplicationDefinition] = [
    editor("vscode", "Visual Studio Code", "com.microsoft.VSCode"),
    editor("cursor", "Cursor", "com.todesktop.230313mzl4w4u92"),
    editor("zed", "Zed", "dev.zed.Zed"),
    editor("xcode", "Xcode", "com.apple.dt.Xcode"),
    editor("sublime", "Sublime Text", "com.sublimetext.4"),
  ]

  public static let all: [ApplicationDefinition] = terminals + editors

  public static let defaultTerminalID = "terminal"
  public static let defaultEditorID = "vscode"
}
