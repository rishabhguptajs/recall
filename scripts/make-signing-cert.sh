#!/bin/zsh
# Creates a self-signed code-signing certificate "Recall Developer" in your login keychain.
# Signing every build with the same certificate means macOS keeps Recall's folder permissions
# across updates (ad-hoc builds look like a new app every time).
#
# The certificate and its private key are also saved to keys/recall-signing.p12.
# BACK THAT FILE UP. If you lose it, every user has to re-approve folder access once.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="Recall Developer"
P12=keys/recall-signing.p12

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "\"$NAME\" is already in your keychain. Nothing to do."
  exit 0
fi

mkdir -p keys
if [[ ! -f "$P12" ]]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  openssl req -x509 -newkey rsa:3072 -sha256 -days 7300 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  # -legacy: macOS's `security import` can't read OpenSSL 3's default p12 encryption.
  openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$P12" -passout pass:recall
  chmod 600 "$P12"
  echo "Created $P12 (password: recall). Back it up somewhere safe."
fi

# -T /usr/bin/codesign lets codesign use the key without asking every time.
security import "$P12" -k ~/Library/Keychains/login.keychain-db -P recall -T /usr/bin/codesign
echo "Imported \"$NAME\" into the login keychain."
