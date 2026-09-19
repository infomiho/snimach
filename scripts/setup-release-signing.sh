#!/bin/sh
# Stores the Apple signing certificate and notarization key as GitHub secrets
# for the release workflow. Run once per certificate or key rotation.
#
# Needs, from the Apple Developer portal and App Store Connect:
#   - the Developer ID Application certificate exported from Keychain Access
#     as a .p12 with a password
#   - an App Store Connect API key (.p8) with its Key ID and Issuer ID
#
# Every value can be given through the environment to skip its prompt:
#   APPLE_CERTIFICATE_P12, APPLE_CERTIFICATE_PASSWORD,
#   APPLE_API_KEY_P8, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID
set -eu

default_p12="$HOME/Documents/Certificates.p12"
default_p8="$HOME/Downloads/AuthKey_8NY434VFS6.p8"

ask() {
  # ask <variable> <prompt> [default]: keeps a preset variable, otherwise prompts.
  eval "current=\${$1:-}"
  if [ -n "$current" ]; then return; fi
  if [ -n "${3:-}" ]; then printf '%s [%s]: ' "$2" "$3"; else printf '%s: ' "$2"; fi
  read -r answer
  eval "$1=\${answer:-\${3:-}}"
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."

gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first." >&2; exit 1; }
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "No Developer ID Application certificate in the keychain." >&2
  echo "Create one at https://developer.apple.com/account/resources/certificates/add and double-click the downloaded .cer." >&2
  exit 1
fi

ask APPLE_CERTIFICATE_P12 "Path to the exported certificate (.p12)" "$default_p12"
p12=$APPLE_CERTIFICATE_P12
test -f "$p12" || { echo "Not a file: $p12" >&2; exit 1; }
if [ -z "${APPLE_CERTIFICATE_PASSWORD:-}" ]; then
  printf 'Certificate password: '
  stty -echo; read -r APPLE_CERTIFICATE_PASSWORD; stty echo; echo
fi
p12_password=$APPLE_CERTIFICATE_PASSWORD
openssl pkcs12 -in "$p12" -passin "pass:$p12_password" -info -noout -legacy >/dev/null 2>&1 ||
  openssl pkcs12 -in "$p12" -passin "pass:$p12_password" -info -noout >/dev/null 2>&1 ||
  { echo "The certificate file or its password is not valid." >&2; exit 1; }

ask APPLE_API_KEY_P8 "Path to the App Store Connect API key (.p8)" "$default_p8"
p8=$APPLE_API_KEY_P8
grep -q "BEGIN PRIVATE KEY" "$p8" || { echo "Not a .p8 private key: $p8" >&2; exit 1; }
default_key_id=$(basename "$p8" .p8 | sed 's/^AuthKey_//')
ask APPLE_API_KEY_ID "Key ID" "$default_key_id"
key_id=$APPLE_API_KEY_ID
ask APPLE_API_ISSUER_ID "Issuer ID"
issuer_id=$APPLE_API_ISSUER_ID

base64 <"$p12" | gh secret set APPLE_CERTIFICATE_P12 --repo "$repo"
printf '%s' "$p12_password" | gh secret set APPLE_CERTIFICATE_PASSWORD --repo "$repo"
base64 <"$p8" | gh secret set APPLE_API_KEY_P8 --repo "$repo"
printf '%s' "$key_id" | gh secret set APPLE_API_KEY_ID --repo "$repo"
printf '%s' "$issuer_id" | gh secret set APPLE_API_ISSUER_ID --repo "$repo"

echo "Secrets set on $repo. The next v* tag builds a notarized DMG."
