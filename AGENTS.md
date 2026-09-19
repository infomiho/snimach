# Snimach

Menubar screenshot app for macOS 14+. Two hotkeys, one editor, clipboard first.

- `Sources/SnimachCore` is a plain Swift package with the capture, document and output logic, tested with `swift test`. `App/` is the AppKit shell, an xcodegen project: `cd App && xcodegen generate` writes `Snimach.xcodeproj`, which is gitignored. Test it with `xcodebuild test -project App/Snimach.xcodeproj -scheme Snimach -destination 'platform=macOS' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`.
- Both suites must be green before a task is done. CI runs the same two commands plus an ad-hoc `scripts/package-app.sh`.
- `swift` on this Mac needs full Xcode: if `swift test` fails with "Could not initialize build system", run it with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Screen Recording grants are keyed to the code signature, so local runs go through `scripts/run.sh`, which signs with the machine's Developer ID and installs to /Applications.
- Module designs live in `docs/` (`capture.md`, `document.md`, `output.md`, `shell.md`), the ordered task list in `TASKS.md`, and the brand sources in `design/svg` (`scripts/make-icon.sh` renders the icon and menu bar mark).
- Bundle identifier `dev.twoducks.snimach`. Saved shots go to `~/Pictures/Snimach` by default.

## Releases

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds `Snimach.app`, signs and notarizes a DMG, and runs `gh release create` for that tag. Do NOT create the GitHub release manually after pushing a tag; the workflow fails with "a release with the same tag name already exists".

To cut a release: bump `MARKETING_VERSION` in `App/project.yml`, commit, tag `vX.Y.Z` with a message (it becomes the release notes), push the tag, and let CI publish. Versions must be plain `MAJOR.MINOR.PATCH`: `scripts/package-app.sh` derives the numeric `CFBundleVersion` from it and refuses suffixes.

`scripts/setup-release-signing.sh` stores the Developer ID certificate and the App Store Connect API key as repo secrets once. The workflow also calls the Coolify webhook (`COOLIFY_WEBHOOK`, `COOLIFY_TOKEN`) so the tag refreshes `snimach.miho.dev`.

After publishing, the workflow runs `scripts/update-tap.sh`, which rewrites the version and sha256 of `Casks/snimach.rb` in `infomiho/homebrew-tap` (a local checkout lives at `~/dev/homebrew-tap`) so `brew install --cask infomiho/tap/snimach` serves the new build. It pushes over SSH with the `TAP_DEPLOY_KEY` secret, the private half of a write deploy key registered on the tap repo (`gh repo deploy-key add --allow-write`, then `gh secret set TAP_DEPLOY_KEY`).

The workflow also signs the DMG with the Sparkle key from the `SPARKLE_PRIVATE_KEY` secret and publishes `appcast.xml` as a release asset. Installed copies read `https://github.com/infomiho/snimach/releases/latest/download/appcast.xml` and update themselves through Sparkle, linked as a Swift package (`App/Updater.swift`). `scripts/setup-sparkle-key.sh` stores the secret and writes the public key into `App/Info.plist`. Back the private key up: without it no installed copy accepts an update. Debug builds and ad-hoc packaging runs leave `SUFeedURL` empty, which keeps the updater inert and the Check for Updates item out of the menu.

## Web

`web/` is a separate Rust crate that serves the landing page and release notes at `snimach.miho.dev`. See `web/AGENTS.md`. Validate with `cargo fmt --manifest-path web/Cargo.toml -- --check`, `cargo clippy --manifest-path web/Cargo.toml --all-targets -- -D warnings`, and `cargo test --manifest-path web/Cargo.toml`.
