#!/bin/zsh
# Creates a self-signed code-signing certificate "Recall Developer" in your login keychain.
# Signing every build with the same certificate means macOS keeps Recall's folder permissions
# across updates (ad-hoc builds look like a new app every time).
#
# The certificate and its private key are also saved to keys/recall-signing.p12, with a random
# password in keys/recall-signing-password.txt. BACK BOTH UP (e.g. in a password manager).
# If you lose them, every user has to re-approve folder access once.
# Keep them private: whoever has them can sign an app macOS treats as Recall.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="Recall Developer"
P12=keys/recall-signing.p12
PASSFILE=keys/recall-signing-password.txt

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
  ( umask 077; openssl rand -base64 24 > "$PASSFILE" )
  # -legacy: macOS's `security import` can't read OpenSSL 3's default p12 encryption.
  openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$P12" -passout file:"$PASSFILE"
  chmod 600 "$P12"
  echo "Created $P12 and $PASSFILE. Back both up somewhere safe."
fi

# -T /usr/bin/codesign lets codesign use the key without asking every time.
security import "$P12" -k ~/Library/Keychains/login.keychain-db -P "$(cat "$PASSFILE")" -T /usr/bin/codesign
echo "Imported \"$NAME\" into the login keychain."
