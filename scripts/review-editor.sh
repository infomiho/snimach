#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEW_DIR="${1:-$PROJECT_ROOT/build/editor-review/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$REVIEW_DIR"
REVIEW_DIR="$(cd "$REVIEW_DIR" && pwd)"

if [[ -e "$REVIEW_DIR/Tests.xcresult" ]]; then
  echo "Use a new output directory: $REVIEW_DIR/Tests.xcresult already exists" >&2
  exit 1
fi
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)}"
TEAM="${TEAM_ID:-}"
if [[ -z "$TEAM" && "$IDENTITY" == "Developer ID Application:"* ]]; then
  TEAM="$(printf '%s' "$IDENTITY" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')"
fi
SIGNING_ARGS=("CODE_SIGN_STYLE=Manual" "CODE_SIGN_IDENTITY=${IDENTITY:--}")
if [[ -n "$TEAM" ]]; then
  SIGNING_ARGS+=("DEVELOPMENT_TEAM=$TEAM")
fi

xcodegen generate --spec "$PROJECT_ROOT/App/project.yml" >/dev/null
status=0
xcodebuild test \
  -project "$PROJECT_ROOT/App/Snimach.xcodeproj" \
  -scheme Snimach \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$PROJECT_ROOT/build/DerivedData" \
  -resultBundlePath "$REVIEW_DIR/Tests.xcresult" \
  -only-testing:SnimachTests/EditorVisualTests \
  "${SIGNING_ARGS[@]}" \
  >"$REVIEW_DIR/test.log" 2>&1 || status=$?

if [[ -d "$REVIEW_DIR/Tests.xcresult" ]]; then
  xcrun xcresulttool export attachments \
    --path "$REVIEW_DIR/Tests.xcresult" \
    --output-path "$REVIEW_DIR/attachments" >/dev/null || status=1
  if [[ -f "$REVIEW_DIR/attachments/manifest.json" ]]; then
    python3 "$PROJECT_ROOT/scripts/editor-gallery.py" "$REVIEW_DIR" || status=1
  fi
fi
if [[ "$status" -ne 0 ]]; then
  tail -60 "$REVIEW_DIR/test.log"
fi
exit "$status"
