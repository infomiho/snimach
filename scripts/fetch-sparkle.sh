#!/bin/sh
# Downloads the pinned Sparkle release once into .cache/sparkle and prints the
# directory that holds the bin/ tools (generate_keys, generate_appcast). The app
# itself links Sparkle through Swift Package Manager, see App/project.yml, so
# only the command line tools come from here.
set -eu

version="2.10.0"
sha256="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."

cache=".cache/sparkle/$version"
if [ ! -d "$cache/bin" ]; then
  staging=$(mktemp -d)
  archive="$staging/Sparkle-$version.tar.xz"
  curl -fsSL --retry 3 -o "$archive" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz"
  echo "$sha256  $archive" | shasum -a 256 -c - >/dev/null
  tar -xJf "$archive" -C "$staging" ./bin
  rm -f "$archive"
  rm -rf "$cache"
  mkdir -p "$(dirname "$cache")"
  mv "$staging" "$cache"
fi
printf '%s\n' "$cache"
