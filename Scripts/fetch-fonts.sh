#!/bin/bash

# Downloads Switzer (Indian Type Foundry, via Fontshare) into .fonts/.
#
# The ITF Free Font License lets us embed the font in Odo.app but not
# redistribute it from a public repository, so the files are never committed:
# every build fetches them from Fontshare instead.
#
# Usage: ./Scripts/fetch-fonts.sh   (no-op when .fonts/ is already filled)

set -e
cd "$(dirname "$0")/.."

DEST=".fonts"
WEIGHTS=(Regular Medium Semibold Bold Extrabold Black)

missing=false
for w in "${WEIGHTS[@]}"; do [ -f "${DEST}/Switzer-${w}.otf" ] || missing=true; done
[ "$missing" = false ] && exit 0

echo "Fetching Switzer from Fontshare..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "${TMP}/switzer.zip" "https://api.fontshare.com/v2/fonts/download/switzer"
unzip -q "${TMP}/switzer.zip" -d "${TMP}"

mkdir -p "${DEST}"
for w in "${WEIGHTS[@]}"; do
    cp "$(find "${TMP}" -path "*OTF/Switzer-${w}.otf" | head -1)" "${DEST}/"
done
cp "$(find "${TMP}" -name FFL.txt | head -1)" "${DEST}/LICENSE.txt"
