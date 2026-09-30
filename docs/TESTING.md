# Testing

## Automated

```bash
swift test --package-path Packages/OpenHereCore     # 47 tests (Swift Testing)
swift format lint --strict -r OpenHere OpenHereFinderExtension Packages/OpenHereCore/Sources Packages/OpenHereCore/Tests
```

CI (`.github/workflows/ci.yml`) runs the same two commands plus an unsigned Release build of the app and
the Finder extension.

Covered by the unit tests: path escaping (spaces, quotes, `$`, backticks, newlines, unicode, emoji),
relative paths, URL round-trips with hostile paths, path validation, target resolution (folder, file, no
extension, multiple, nothing selected, no window, missing items), request building (terminals vs
editors, window cap), the launcher with mocks (no shell, one `argv` entry per path, missing app, missing
target), the request token check, settings persistence (shared files, corrupt data, token file mode, the sandbox entitlement matching the storage folder),
default / toolbar / context-menu application selection, the menu model, shortcut validation and log
redaction.

## Manual matrix (Finder integration cannot run headless)

| Scenario                                        | Expected                                             |
| ----------------------------------------------- | ---------------------------------------------------- |
| Folder selected → context menu → Terminal       | New Terminal window in that folder                   |
| File selected → editor                          | File opens in the editor                             |
| File selected → terminal                        | Terminal opens in the file's folder                  |
| Several files → editor                          | All open in one editor request                       |
| Nothing selected (background click)             | Folder of the Finder window                          |
| Toolbar button (default behavior)               | Default terminal opens at once, no menu              |
| Toolbar button set to "Show a menu"             | Menu with the applications ticked for the toolbar    |
| Copy Path items                                 | POSIX / escaped / relative text on the pasteboard    |
| No Finder window (shortcut or menu bar item)    | Desktop                                              |
| App uninstalled                                 | Menu entry disappears; no crash                      |
| Path `/tmp/My "weird" $(id)/it's`               | Opens correctly, nothing executed                    |
| External disk / network volume                  | Menu appears and opens                               |
| Volume mounted while Finder is running          | Menu appears without restarting anything             |
| Shortcut ⇧⌘O in Finder / in another app         | Works in Finder only (Finder-only mode)              |
| First shortcut / menu bar use                   | macOS asks for Automation → Finder permission        |
| Light and dark mode                             | Menu and toolbar glyphs are legible in both          |
| Installed from the DMG (ad hoc): quit and reopen | Settings survive; no onboarding again              |
| Installed from the DMG: toolbar and menu actions | They open the app; Copy Path works                 |
| Settings: hide an app from menu / toolbar       | Disappears from that menu only                       |
| Settings › General › Check Now (needs release)  | Sparkle finds, verifies and installs the update      |
| Help and About menus                            | Links open; About opens Settings on the About pane   |

Repeat on every supported macOS version (15, 26, 27…) — the Finder extension enablement UI differs.
