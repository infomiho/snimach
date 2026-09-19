#!/bin/sh
# Copies the shared app artwork into web/static so the site builds from web/
# alone. Run after changing assets/snimach-mark.svg or assets/snimach.webp.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)

cp -f "$root/assets/snimach-mark.svg" "$root/web/static/snimach-mark.svg"
cp -f "$root/assets/snimach.webp" "$root/web/static/snimach.webp"

echo "synced app assets into web/static"
