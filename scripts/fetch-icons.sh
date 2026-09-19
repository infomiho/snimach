#!/usr/bin/env bash
#
# Vendors the Solar icons the editor toolbar uses as vector PDFs, so the app does not depend on
# runtime SVG support. Solar is CC BY 4.0, see ATTRIBUTION.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/App/Resources/Icons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ICONS=(
  arrow-right-up-linear
  hashtag-linear
  undo-left-linear
  undo-right-linear
  diskette-linear
  copy-linear
  close-circle-linear
  stop-linear
  pipette-linear
  menu-dots-linear
  alt-arrow-up-linear
  pen-linear
  crop-linear
  window-frame-linear
  monitor-linear
)

mkdir -p "$OUT"
swiftc -o "$TMP/svg2pdf" "$ROOT/scripts/svg2pdf.swift"

for icon in "${ICONS[@]}"; do
  curl -fsSL "https://api.iconify.design/solar/$icon.svg" -o "$TMP/$icon.svg"
  "$TMP/svg2pdf" "$TMP/$icon.svg" "$OUT/$icon.pdf"
  echo "vendored $icon.pdf"
done
