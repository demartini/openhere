# Architecture

```
OpenHere.app (SwiftUI + AppKit, not sandboxed, hardened runtime)
├── App/            composition root, app delegate, window coordinator, project links
├── Features/       Onboarding, Settings (incl. About), MenuBar, Shortcuts, Applications (SwiftUI views)
└── Services/       Finder query (Apple Events), Launching (URL requests), Updates (Sparkle),
                    Diagnostics, System (shortcut, login item)

OpenHereFinderExtension.appex (sandboxed, small)
└── renders FinderMenuModel, forwards clicks as openhere:// URLs

Packages/OpenHereCore (Swift package, no UI)
├── Domain/         ApplicationDefinition, OpenTarget, LaunchRequest, LaunchStrategy
├── Catalog/        BuiltInApplications, ApplicationCatalog
├── Application/    OpenTargetResolver, LaunchRequestBuilder, PathFormatter, OpenHereURL,
│                   FinderMenuModel, RequestAuthenticator, CustomApplicationFactory
├── Infrastructure/ Launcher (NSWorkspace / Process), ApplicationLocating, Logging
└── Preferences/    OpenHereSettings (one JSON document), FileSettingsStore (App Group container)

site/               landing page (HTML + Tailwind v4) and the Sparkle appcast, deployed with GitHub Pages
```

## Flow

```
Finder selection ─▶ extension ─▶ openhere://open?app=…&path=…&token=… ─▶ app
                                        │
   OpenRequestHandler: token → app id → path validation → OpenTargetResolver
   → LaunchRequestBuilder (adapts the target to the app's capabilities) → Launcher
   → NSWorkspace.open(urls, withApplicationAt:)   or   /usr/bin/open -a <app> --args …
```

- **Selection first**, then the folder of the Finder window, then the Desktop.
- Terminals open folders only: a selected file maps to its parent folder; several selections open
  one window per unique folder (capped at 8). Editors receive every item in a single request.
- The extension never launches anything and keeps no state of its own; it re-reads the settings each
  time a menu is requested.

## The Finder extension

- **Monitored locations:** `/` plus every mounted volume (updated on mount / unmount / rename); Finder Sync
  only shows menus for locations it was told to watch.
- **Menu items** are identified by `NSMenuItem.tag`, not `representedObject`: Finder copies the menu across
  processes and drops `representedObject`.
- **Toolbar button:** according to `ToolbarBehavior` it either opens the default terminal / editor straight
  from `menu(for: .toolbarItemMenu)` (returning no menu, so there is no delay) or shows a menu limited to
  the applications chosen for the toolbar.
- Images are tinted for the current appearance before being handed to Finder, which ignores the template flag.

## Adding an application

1. Add an `ApplicationDefinition` to `BuiltInApplications` (bundle id, kind, `LaunchStrategy`).
2. New UI text goes into the `Localizable.xcstrings` catalogs in Xcode (English source + Português (Brasil)).
3. Add a case to `CatalogAndSettingsTests` / `LauncherTests` if the strategy is new.

Nothing else changes: menus, settings, ordering and defaults are all driven by the catalog.

## Launch strategies

| Strategy           | Used by                                                   | Mechanism                                                               |
| ------------------ | --------------------------------------------------------- | ----------------------------------------------------------------------- |
| `workspace`        | Terminal, iTerm, Ghostty, Warp, Tabby, Hyper, all editors | `NSWorkspace.open(_:withApplicationAt:)`                                |
| `processArguments` | kitty, Alacritty, WezTerm                                 | `/usr/bin/open -n -a <app> --args …` with one `argv` entry per argument |
| `urlScheme`        | custom / future apps                                      | URL template, path percent-encoded                                      |

AppleScript is **not** used to launch anything. The single script in the code base
(`FinderQuery`) is a constant that asks Finder for its selection; no data is interpolated.

## Data sharing

`OpenHereSettings` is stored as JSON (`settings.json`) next to the request token (`request-token`, mode
0600) in the App Group container `<TEAMID>.group.dev.demartini.openhere`; the Info.plist key
`OpenHereAppGroup` carries the resolved id. Plain files are used instead of `UserDefaults` because the
extension is another process and a preferences suite can be cached per process. Every field is optional
when decoding, so older or newer documents never fail to load. XPC was deliberately left out (YAGNI); add it
only if the extension needs a reply channel.

Fresh settings show only the default terminal and editor in the menus; the user adds more in Settings ›
Applications (separate checkboxes for the context menu and the toolbar).

## Updates

`UpdateService` wraps Sparkle's `SPUStandardUpdaterController`. Feed: `SUFeedURL` (GitHub Pages
`appcast.xml`); archives: DMGs on GitHub Releases; integrity: EdDSA (`SUPublicEDKey`). Because OpenHere
is a background app, scheduled checks use Sparkle's gentle reminders: the menu bar icon changes and the menu
offers "Update Available". See `docs/RELEASING.md`.
