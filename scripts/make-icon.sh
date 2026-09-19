#!/usr/bin/env bash
#
# Renders the app icon and the menu bar mark from their SVG sources in design/svg.
# Run after editing either source.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/design/svg"
RES="$ROOT/App/Resources"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swiftc -O -o "$TMP/svg2png" "$ROOT/scripts/svg2png.swift"
swiftc -O -o "$TMP/svg2pdf" "$ROOT/scripts/svg2pdf.swift"

SET="$TMP/Snimach.iconset"
mkdir -p "$SET"
render() { "$TMP/svg2png" "$SRC/appicon.svg" "$SET/$1" "$2"; }
render icon_16x16.png 16
render icon_16x16@2x.png 32
render icon_32x32.png 32
render icon_32x32@2x.png 64
render icon_128x128.png 128
render icon_128x128@2x.png 256
render icon_256x256.png 256
render icon_256x256@2x.png 512
render icon_512x512.png 512
render icon_512x512@2x.png 1024

mkdir -p "$RES/Icons"
iconutil -c icns "$SET" -o "$RES/Snimach.icns"
"$TMP/svg2pdf" "$SRC/menubar.svg" "$RES/Icons/snimach-mark.pdf"
"$TMP/svg2pdf" "$SRC/redact.svg" "$RES/Icons/redact.pdf"

echo "wrote $RES/Snimach.icns, $RES/Icons/snimach-mark.pdf and $RES/Icons/redact.pdf"
