#!/usr/bin/env bash
#
# Builds, installs and launches a local Debug build signed with the machine's Developer ID.
#
# Screen Recording grants are keyed to the code signature and the app is resolved through
# LaunchServices. An ad-hoc signature changes every build, and running out of DerivedData keeps
# the app out of the system's app registry, so both the grant and the Settings entry misbehave.
# This signs with a Developer ID and installs to /Applications.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
BUILT="$DERIVED/Build/Products/Debug/Snimach.app"

IDENTITY="$(security find-identity -v -p codesigning \
  | grep 'Developer ID Application' \
  | head -1 \
  | sed -E 's/^[^"]*"([^"]+)"/\1/')"

if [[ -z "$IDENTITY" ]]; then
  echo "run.sh: no 'Developer ID Application' identity in the keychain" >&2
  exit 1
fi
TEAM="$(printf '%s' "$IDENTITY" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')"

if [[ -w /Applications ]]; then
  INSTALLED=/Applications/Snimach.app
else
  INSTALLED="$HOME/Applications/Snimach.app"
fi

echo "signing as: $IDENTITY"

cd "$ROOT/App"
xcodegen generate >/dev/null

xcodebuild build \
  -project Snimach.xcodeproj \
  -scheme Snimach \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  ENABLE_HARDENED_RUNTIME=YES \
  >/dev/null

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT/Contents/Info.plist")"

pkill -x Snimach 2>/dev/null || true
sleep 1
rm -rf "$INSTALLED"
mkdir -p "$(dirname "$INSTALLED")"
cp -R "$BUILT" "$INSTALLED"
"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f "$INSTALLED"

open "$INSTALLED"
echo "launched $INSTALLED ($BUNDLE_ID)"
