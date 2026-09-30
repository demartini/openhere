# Releasing

OpenHere is **not notarized** (no paid Apple Developer account). Releases are ad-hoc signed and
published as a DMG on GitHub Releases. Updates use [Sparkle](https://sparkle-project.org): every DMG is
signed with an EdDSA key and announced in `appcast.xml`, served by GitHub Pages. The Apple signature is
not involved, so this works without a Developer ID.

## One-time setup

1. **Key pair.** Done once with Sparkle's `generate_keys`, which is inside the Sparkle package artifacts
   after a build (`<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/`). The private key lives in
   your login keychain; the public key is `SUPublicEDKey` in `OpenHere/Info.plist`.
   **Back the private key up** – without it existing installs can never update again:

   ```bash
   generate_keys -x sparkle_private_key     # writes the key to a file; store it in a password manager
   ```

2. **GitHub secret** `SPARKLE_ED_PRIVATE_KEY`: the contents of that file.
3. **GitHub Pages**: Settings › Pages › Source = "GitHub Actions". Pages on a private repository needs a
   paid GitHub plan; a public repository is free. The repository must also be public for the updater and
   the download links to work for other people.
4. The `Release` workflow pushes the new appcast to `main`, so `main` must allow pushes from GitHub Actions
   (no branch protection that blocks it).

## Local build

The DMG (background, icon positions, volume icon) is built with [create-dmg](https://github.com/create-dmg/create-dmg):
`brew install create-dmg`. Its window art is `assets/dmg/background.png` (660×440 pt, drawn at 2×); if you move the
icons, keep the coordinates in `scripts/build_release.sh` in sync with the arrow in that image.

```bash
scripts/build_release.sh                       # ad hoc
SIGNING_IDENTITY="Apple Development: Name (XXXX)" scripts/build_release.sh
scripts/make_appcast.sh build/release/OpenHere-1.0.0.dmg /tmp/appcast.xml   # signs with the keychain key
```

Output: `build/release/OpenHere-<version>.dmg` and `.dmg.sha256`. `make_appcast.sh` needs a build first so
SwiftPM has fetched Sparkle's tools.

## Cutting a release

1. Add a `## <version>` section to `CHANGELOG.md` (for example `## 1.0.1`). Its body becomes the GitHub
   Release notes, which is also what Sparkle's "Release Notes" link shows; the workflow fails when the section is
   missing.
2. Tag and push:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

The `Release` workflow tests, builds, signs the DMG for Sparkle, publishes the GitHub Release, and commits
the new `site/public/appcast.xml` to `main`; the workflow then dispatches the `Pages` workflow explicitly (pushes made with `GITHUB_TOKEN` do not trigger
other workflows) so the site is redeployed with the new appcast. The tag must be `v<version>`; the build number (`CFBundleVersion`) is the workflow run number
and always increases, which is what Sparkle compares. The appcast lists only the latest release, so every
older version updates straight to it.

## Website

`site/` (HTML + Tailwind v4, English and Portuguese) is deployed by the `Pages` workflow whenever `site/`
changes on `main`. Until the first release, `site/public/appcast.xml` is an empty feed, so update checks
report "up to date". Preview locally with `cd site && npm install && npm run build`.

## What users see

- **Downloading the DMG in a browser** adds the quarantine flag and Gatekeeper refuses the app.
  Fix once: right-click › Open, or `xattr -dr com.apple.quarantine /Applications/OpenHere.app`.
- **Updates from inside the app** (Sparkle) download, verify the EdDSA signature, replace the app and
  relaunch; Sparkle clears the quarantine flag on the new copy. Scheduled checks only change the menu bar
  icon and add an "Update Available" menu item (gentle reminders); the user starts the installation.

## Limitations of ad-hoc signing

- macOS ties the Automation (Finder) permission to the code signature. Each ad-hoc build has a new one, so
  macOS may ask again after an update. Signing every release with the same development certificate avoids
  this.
- The app has the `disable-library-validation` entitlement so the hardened runtime can load Sparkle when
  everything is ad-hoc signed (see `docs/SECURITY.md`).
