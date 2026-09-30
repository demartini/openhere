<div align="center">
  <img align="center" src=".github/media/logo.png?raw=true" alt="Logo" width="200">
</div>

<h1 align="center">OpenHere</h1>

<p align="center">Open the Finder location in the terminal or editor you choose.</p>

<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]

</div>

## Table of Contents <!-- omit in toc -->

- [About](#about)
- [Features](#features)
- [Supported Applications](#supported-applications)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Toolbar](#toolbar)
  - [Context Menu](#context-menu)
  - [Keyboard Shortcut](#keyboard-shortcut)
  - [Menu Bar](#menu-bar)
  - [Settings](#settings)
- [Building from Source](#building-from-source)
  - [Signing](#signing)
  - [Common Tasks](#common-tasks)
  - [Project Layout](#project-layout)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

## About

Finder shows where your files are; your terminal and editor are where you work on them. Bridging the two usually means dragging a folder onto an icon, or typing `cd` followed by a path that has to be escaped by hand.

`OpenHere` is a native macOS utility that closes that gap. It adds a toolbar button, a context menu and an optional keyboard shortcut to Finder, and opens the current folder or selection in the application you configured — Terminal, Ghostty, iTerm, Visual Studio Code, Cursor and others.

Resolution is deterministic: the **selection** wins, then the **folder shown by the Finder window**, then the **Desktop**. Paths are handed to applications as URLs or as discrete arguments and never pass through a shell, so unusual folder names cannot be interpreted as commands.

<p align="right">(<a href="#top">back to top</a>)</p>

## Features

- 🖱 Finder toolbar button that opens your default terminal or editor instantly — or shows a menu, your choice
- 📂 Finder context menu, as a submenu or a flat list, on every mounted volume
- 🎛 Independent application selection for the context menu and the toolbar, with custom ordering
- ➕ Custom applications, launched like "Open With" or with explicit arguments
- ⌨️ Configurable shortcut (`⇧⌘O` by default), active only in Finder or globally
- 📋 Copy Path as POSIX, shell-escaped or relative
- 🧠 Smart menu that lists editors first when the selection contains only files
- 🔒 No shell, no interpolated scripts, no analytics
- 🔄 In-app updates, verified with an EdDSA signature
- 🌗 Light and dark mode, English and Português (Brasil)

<p align="right">(<a href="#top">back to top</a>)</p>

## Supported Applications

| Kind      | Applications                                                            |
| --------- | ----------------------------------------------------------------------- |
| Terminals | Terminal, iTerm, Ghostty, Warp, WezTerm, kitty, Alacritty, Tabby, Hyper |
| Editors   | Visual Studio Code, Cursor, Zed, Xcode, Sublime Text                    |
| Custom    | Any application, through a standard "Open With" or a list of arguments  |

Applications are detected automatically; only those installed on the machine are offered.

<p align="right">(<a href="#top">back to top</a>)</p>

## Requirements

- macOS 15 (Sequoia) or later

<p align="right">(<a href="#top">back to top</a>)</p>

## Installation

1. Download the latest `OpenHere-<version>.dmg` from [Releases][releases-url] and drag **OpenHere** to **Applications**.
2. The app is not notarized, so macOS blocks the first launch of a downloaded copy. Clear the quarantine flag once:

   ```console
   xattr -dr com.apple.quarantine /Applications/OpenHere.app
   ```

   Alternatively, right-click the app and choose **Open**.

3. Launch OpenHere and follow the onboarding: pick your default applications and enable the Finder extension in **System Settings › General › Login Items & Extensions › Finder**.
4. In Finder, choose **View › Customize Toolbar…** and drag **Open Here** into the toolbar.

Later versions are installed from inside the app (**Settings › General › Updates**).

<p align="right">(<a href="#top">back to top</a>)</p>

## Usage

### Toolbar

Click **Open Here** to open the current folder — or the selected item — in your default terminal. The behavior is configurable under **Settings › Finder › Toolbar button**: open the default terminal, open the default editor, or show a menu of the applications ticked for the toolbar.

### Context Menu

Right-click any item, or the background of a Finder window, and choose **Open Here**. The menu lists the applications enabled in **Settings › Applications** and adds **Copy Path**:

| Item               | Result                                           |
| ------------------ | ------------------------------------------------ |
| Copy POSIX Path    | `/Users/me/My Projects/App`                      |
| Copy Escaped Path  | `/Users/me/My\ Projects/App`                     |
| Copy Relative Path | Path relative to the folder of the Finder window |

Terminals open folders only: a selected file opens its parent folder, and several selections open one window per unique folder. Editors receive every selected item at once.

### Keyboard Shortcut

`⇧⌘O` opens the selection, or the current Finder folder, with the default terminal or editor. It can be rebound, restricted to Finder or made global under **Settings › Shortcuts**. The first use asks macOS for permission to control Finder.

### Menu Bar

The menu bar item offers **Open Finder Location**, a submenu per application kind, and quick access to Settings and updates. It can be hidden under **Settings › General**.

### Settings

| Pane         | Controls                                                                              |
| ------------ | ------------------------------------------------------------------------------------- |
| General      | Default terminal and editor, launch behavior, launch at login, menu bar icon, updates |
| Applications | Visibility in the context menu and toolbar, ordering, custom applications             |
| Shortcuts    | Shortcut recorder, target, Finder-only mode                                           |
| Finder       | Extension status, submenu, icons, Copy Path items, smart menu, toolbar behavior       |
| Advanced     | Logging level, diagnostics export, reset                                              |
| About        | Version, support links                                                                |

<p align="right">(<a href="#top">back to top</a>)</p>

## Building from Source

Building requires **Xcode 26** or later; the app icon is an Icon Composer document. The project is written in Swift 6 and the shared logic lives in a local Swift package, `OpenHereCore`.

```console
git clone https://github.com/demartini/openhere.git
cd openhere
open OpenHere.xcodeproj
```

### Signing

The Finder extension is sandboxed and shares its settings with the app through an App Group, so it only works end to end with a real signing identity. A free personal team is sufficient.

Create the git-ignored local configuration and set your team:

```console
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

```xcconfig
DEVELOPMENT_TEAM = YOURTEAMID
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development
```

Then run the **OpenHere** scheme and enable the extension as described in [Installation](#installation).

### Common Tasks

| Task                             | Command                                                                                                      |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Run the unit tests               | `swift test --package-path Packages/OpenHereCore`                                                            |
| Check formatting                 | `swift format lint --strict -r OpenHere OpenHereFinderExtension Packages/OpenHereCore`                       |
| Apply formatting                 | `swift format -i -r OpenHere OpenHereFinderExtension Packages/OpenHereCore`                                  |
| Build without a signing identity | `xcodebuild -project OpenHere.xcodeproj -scheme OpenHere -configuration Debug CODE_SIGNING_ALLOWED=NO build` |
| Package a release                | `brew install create-dmg && scripts/build_release.sh`                                                        |

### Project Layout

```text
OpenHere/                 App: SwiftUI views, menu bar, shortcut, Finder queries, updates
OpenHereFinderExtension/  Finder Sync extension: renders the menu, forwards clicks to the app
Packages/OpenHereCore/    Domain, application catalog, launching, path handling, settings, tests
Config/                   Build configuration (xcconfig)
assets/dmg/               Installer window background
scripts/                  Release packaging and signing
```

<p align="right">(<a href="#top">back to top</a>)</p>

## Contributing

If you'd like to contribute, review our [contribution guidelines][contributing-url] and open an [issue][issues-url] or [pull request][pull-request-url].

<p align="right">(<a href="#top">back to top</a>)</p>

## Changelog

See [CHANGELOG][changelog-url] for a complete and human-readable history of changes.

<p align="right">(<a href="#top">back to top</a>)</p>

## License

Distributed under the MIT License. See [LICENSE][license-url] for details.

<p align="right">(<a href="#top">back to top</a>)</p>

[changelog-url]: https://github.com/demartini/openhere/blob/main/CHANGELOG.md
[contributing-url]: https://github.com/demartini/.github/blob/main/CONTRIBUTING.md
[pull-request-url]: https://github.com/demartini/openhere/pulls
[releases-url]: https://github.com/demartini/openhere/releases

[contributors-shield]: https://img.shields.io/github/contributors/demartini/openhere.svg?style=for-the-badge&color=8bd5ca&labelColor=181926
[contributors-url]: https://github.com/demartini/openhere/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/demartini/openhere.svg?style=for-the-badge&color=8bd5ca&labelColor=181926
[forks-url]: https://github.com/demartini/openhere/network/members
[issues-shield]: https://img.shields.io/github/issues/demartini/openhere.svg?style=for-the-badge&color=8bd5ca&labelColor=181926
[issues-url]: https://github.com/demartini/openhere/issues
[license-shield]: https://img.shields.io/github/license/demartini/openhere.svg?style=for-the-badge&color=8bd5ca&labelColor=181926
[license-url]: https://github.com/demartini/openhere/blob/main/LICENSE
[stars-shield]: https://img.shields.io/github/stars/demartini/openhere.svg?style=for-the-badge&color=8bd5ca&labelColor=181926
[stars-url]: https://github.com/demartini/openhere/stargazers
