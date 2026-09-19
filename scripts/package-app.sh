#!/bin/sh
# Builds Snimach.app in Release and packages it as a DMG in dist/.
#
# With SNIMACH_CODESIGN_IDENTITY set to a Developer ID Application identity the
# app and the DMG are signed for distribution (hardened runtime, timestamp);
# otherwise they carry an ad-hoc signature for local use and the Sparkle feed
# is left out so the updater stays inert.
#
# The version comes from MARKETING_VERSION in App/project.yml. Sparkle compares
# CFBundleVersion, so the build number is derived from the semver triple.
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."

version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' App/project.yml)
test -n "$version"
case "$version" in
  *[!0-9.]* | *..* | .* | *.)
    echo "Version $version must be MAJOR.MINOR.PATCH to package a release." >&2
    exit 1
    ;;
esac
build_number=$(printf '%s\n' "$version" | awk -F. 'NF == 3 { print $1 * 1000000 + $2 * 1000 + $3 }')
test -n "$build_number"

identity=${SNIMACH_CODESIGN_IDENTITY:--}
if [ "$identity" = "-" ]; then
  team=""
  feed_url=""
else
  team=$(printf '%s' "$identity" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')
  feed_url="https://github.com/infomiho/snimach/releases/latest/download/appcast.xml"
fi

sign() {
  if [ "$identity" = "-" ]; then
    codesign --force --sign - "$@"
  else
    codesign --force --timestamp --options runtime --sign "$identity" "$@"
  fi
}

derived="build/DerivedData"
app="$derived/Build/Products/Release/Snimach.app"
rm -rf "$app"
(cd App && xcodegen generate >/dev/null)
xcodebuild build \
  -project App/Snimach.xcodeproj \
  -scheme Snimach \
  -configuration Release \
  -derivedDataPath "$derived" \
  -quiet \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build_number" \
  SPARKLE_FEED_URL="$feed_url" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$identity" \
  DEVELOPMENT_TEAM="$team" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"
test -d "$app"
codesign --verify --deep --strict "$app"

architecture=$(uname -m)
image="dist/Snimach-$version-macOS-$architecture.dmg"
mkdir -p dist
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$image" "$image.sha256"
hdiutil create -quiet -volname "Snimach" -srcfolder "$staging" -ov -format UDZO "$image"
sign "$image"
(cd "$(dirname "$image")" && shasum -a 256 "$(basename "$image")" >"$(basename "$image").sha256")
echo "$image"
