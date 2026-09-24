# Snimach

Menubar screenshot app for macOS 14+. Two hotkeys, one editor, clipboard first.

- `Sources/SnimachCore` is a plain Swift package with the capture, document and output logic, tested with `swift test`. `App/` is the AppKit shell, an xcodegen project: `cd App && xcodegen generate` writes `Snimach.xcodeproj`, which is gitignored. Test it with `xcodebuild test -project App/Snimach.xcodeproj -scheme Snimach -destination 'platform=macOS' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`.
- Both suites must be green before a task is done. CI runs the same two commands plus an ad-hoc `scripts/package-app.sh`.
- `swift` on this Mac needs full Xcode: if `swift test` fails with "Could not initialize build system", run it with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Screen Recording grants are keyed to the code signature, so local runs go through `scripts/run.sh`, which signs with the machine's Developer ID and installs to /Applications.
- Module designs live in `docs/` (`capture.md`, `document.md`, `output.md`, `shell.md`), the ordered task list in `TASKS.md`, and the brand sources in `design/svg` (`scripts/make-icon.sh` renders the icon and menu bar mark).
- Icons are Solar only, never SF Symbols. Add the `linear` name to `scripts/fetch-icons.sh`, vendor it into `App/Resources/Icons` and load it with `BundledIcon`.
- Bundle identifier `dev.twoducks.snimach`. Saved shots go to `~/Pictures/Snimach` by default.

## Releases

Every release is the same four steps. `vX.Y.Z` must be plain `MAJOR.MINOR.PATCH` (no suffixes) and match the version in `App/project.yml`, or the workflow refuses it.

1. Bump `MARKETING_VERSION` in `App/project.yml`. That is Xcode's name for the user-facing version; `scripts/package-app.sh` derives the numeric `CFBundleVersion` from it.
2. Commit and push to `main`, and wait for CI to be green.
3. Tag with a message, it becomes the release notes on GitHub, in the Sparkle update window and on `snimach.miho.dev/releases`. Format, same as cadence: first line `Snimach X.Y.Z`, blank line, then one bullet per user-visible change as `- **Short claim.** One or two sentences on what changed for the user.` No headings, no commit lists, no internal refactors. Write it in a file and tag with `git tag -a vX.Y.Z -F notes.md`.
4. Push the tag: `git push origin vX.Y.Z`. Then check https://github.com/infomiho/snimach/actions.

Pushing the tag triggers `.github/workflows/release.yml`, which builds `Snimach.app`, signs and notarizes a DMG, signs the appcast with the Sparkle key, creates the GitHub release with the DMG, its sha256 and `appcast.xml`, bumps `Casks/snimach.rb` in `infomiho/homebrew-tap`, and calls the Coolify webhook so `snimach.miho.dev` rebuilds. Do NOT create the GitHub release manually after pushing a tag; the workflow fails with "a release with the same tag name already exists". If the run fails, fix on `main`, then delete and recreate the tag (`git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z`, tag again, push).

One-time setup, already done, rerun only on rotation:

- `scripts/setup-release-signing.sh` stores the Developer ID certificate and the App Store Connect API key as repo secrets (`APPLE_*`).
- `scripts/setup-sparkle-key.sh` stores `SPARKLE_PRIVATE_KEY` and writes the public key into `App/project.yml`. xcodegen regenerates `App/Info.plist` from `project.yml` on every generate, so plist keys are edited there, never in the plist. Back the private key up: without it no installed copy accepts an update.
- `TAP_DEPLOY_KEY` is the private half of a write deploy key on the tap repo (`gh repo deploy-key add --allow-write`, then `gh secret set TAP_DEPLOY_KEY`). A local checkout of the tap lives at `~/dev/homebrew-tap`.
- `COOLIFY_WEBHOOK` and `COOLIFY_TOKEN` point at the `snimach-web` app on Coolify.

Installed copies read `https://github.com/infomiho/snimach/releases/latest/download/appcast.xml` and update themselves through Sparkle, linked as a Swift package (`App/Updater.swift`). Debug builds and ad-hoc packaging runs leave `SUFeedURL` empty, which keeps the updater inert and the Check for Updates item out of the menu.

## Web

`web/` is a separate Rust crate that serves the landing page and release notes at `snimach.miho.dev`. See `web/AGENTS.md`. Validate with `cargo fmt --manifest-path web/Cargo.toml -- --check`, `cargo clippy --manifest-path web/Cargo.toml --all-targets -- -D warnings`, and `cargo test --manifest-path web/Cargo.toml`.

## Promo

`promo/` is a [HyperFrames](https://github.com/heygen-com/hyperframes) composition for the promo video: the whole piece is `promo/index.html`, timed on the music's beat grid (`beat(n)`). Validate with `npx hyperframes lint` and render with `npm run render` inside `promo/`. The music is ["Medicine" by Gvidon](https://pixabay.com/music/drum-n-bass-gvidon-medicine-364031/) from Pixabay. It is not committed: download it to `promo/assets/audio/medicine.mp3`. Renders go to `promo/renders/`, which is gitignored.
