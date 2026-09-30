# Changelog

## 1.0.2

### Fixed

- **Release notes**: the update window showed the GitHub release page instead of the notes. It now shows the notes themselves, in Sparkle's own style.

### Changed

- **Settings sidebar**: more compact, with smaller icons, tighter rows and the version in the footer.

## 1.0.1

### Fixed

- Settings were lost every time the installed app was reopened, so the onboarding ran again.
- The toolbar button and the context-menu actions did nothing in the downloaded (ad-hoc signed) app; only Copy Path worked.

### Changed

- Settings and the request token are now stored in `~/Library/Application Support/OpenHere` and read by the Finder extension through a read-only sandbox exception. The app no longer uses an App Group, which macOS only grants to apps with a paid Apple Developer team. Settings saved by 1.0.0 are not migrated, so the onboarding runs once more.
- The Finder extension logs how many locations it monitors and whether it can read its settings (`log stream --predicate 'subsystem == "dev.demartini.openhere"' --info`).
- Version and build number are set by the release itself: the version comes from the git tag and the build number is the commit count.

## 1.0.0

- Finder Sync extension: toolbar button (opens the default terminal or editor at once, or shows a menu),
  context menu (submenu or flat) and Copy Path (POSIX / escaped / relative). Works on every mounted volume.
- Terminals: Terminal, iTerm, Ghostty, Warp, WezTerm, kitty, Alacritty, Tabby, Hyper.
- Editors: Visual Studio Code, Cursor, Zed, Xcode, Sublime Text.
- Choose which applications appear in the context menu and in the toolbar menu; reorder them.
- Custom applications ("Open With" or explicit arguments).
- Menu bar item, configurable global / Finder-only shortcut (default ⇧⌘O), launch at login.
- Onboarding, redesigned Settings with About pane, Help menu, diagnostics export, logging levels.
- English and Brazilian Portuguese, light and dark mode, new layered app icon.
- In-app updates with Sparkle (EdDSA-signed, appcast on GitHub Pages, gentle reminders for scheduled checks).
- Landing page (English / Português) published with GitHub Pages.
