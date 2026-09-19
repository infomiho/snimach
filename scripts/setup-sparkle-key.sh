#!/bin/sh
# Stores the Sparkle update signing key as the SPARKLE_PRIVATE_KEY GitHub
# secret and writes the public key into App/project.yml, which xcodegen copies
# into Info.plist on every generate. Sparkle keeps one key
# per user account in the login keychain, so this reuses the key already there
# or creates it on first run.
#
# Pass a path to also export a backup of the private key. Every installed
# Snimach trusts only updates signed with it, so losing the key means users
# have to reinstall by hand.
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."

project=App/project.yml
backup=${1:-}

gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first." >&2; exit 1; }
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
tools="$(./scripts/fetch-sparkle.sh)/bin"

"$tools/generate_keys" >/dev/null
public_key=$("$tools/generate_keys" -p)
test -n "$public_key"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
exported="$work/sparkle-private-key"
"$tools/generate_keys" -x "$exported"
gh secret set SPARKLE_PRIVATE_KEY --repo "$repo" <"$exported"
if [ -n "$backup" ]; then
  mkdir -p "$(dirname "$backup")"
  cp "$exported" "$backup"
  echo "Private key backed up to $backup."
fi

sed -i '' "s|^\( *SUPublicEDKey: \).*|\1\"$public_key\"|" "$project"
grep -q "SUPublicEDKey: \"$public_key\"" "$project"
echo "SPARKLE_PRIVATE_KEY stored on $repo and the public key written to $project. Commit that change."
