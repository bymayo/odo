#!/bin/bash

# Odo build script: Swift package -> Odo.app -> DMG (optionally signed + notarised)
#
# Usage: ./Scripts/build-dmg.sh <version> [--sign] [--app-only]
#   --sign      Developer ID + hardened runtime, then notarise and staple
#   --app-only  stop after build/Odo.app (used by `make app` / `make run`)
#
# Signing reads DEVELOPER_ID, TEAM_ID and NOTARY_PROFILE (or APPLE_ID +
# APP_PASSWORD on CI) from the environment; the Makefile loads .env.local.

set -e
cd "$(dirname "$0")/.."

APP_NAME="Odo"
VERSION="${1:-}"
BUILD_DIR="build"
DMG_DIR="${BUILD_DIR}/dmg"
APP_PATH="${DMG_DIR}/${APP_NAME}.app"
INFO_PLIST="Packaging/Info.plist"
ENTITLEMENTS="Packaging/Odo.entitlements"
ICON="Packaging/AppIcon.icns"

SIGN_APP=false
APP_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --sign) SIGN_APP=true ;;
        --app-only) APP_ONLY=true ;;
    esac
done

[ -n "$VERSION" ] || VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${YELLOW}$*${NC}"; }

echo -e "${GREEN}Building ${APP_NAME} v${VERSION}${NC}"
echo "=================================="

if [ "$SIGN_APP" = true ]; then
    if [ -z "$DEVELOPER_ID" ]; then
        echo -e "${RED}Error: DEVELOPER_ID not set.${NC} Put it in .env.local (certificate SHA-1 hash"
        echo "if you hold more than one Developer ID). Find it with: security find-identity -v -p codesigning"
        exit 1
    fi
    if [ -n "$NOTARY_PROFILE" ]; then
        NOTARIZE=true; NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    elif [ -n "$TEAM_ID" ] && [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ]; then
        NOTARIZE=true; NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID")
    else
        echo -e "${YELLOW}Warning: no notarisation credentials. Signing only.${NC}"
        NOTARIZE=false
    fi
    echo -e "${YELLOW}Code signing: ENABLED${NC}"
else
    echo -e "${YELLOW}Code signing: DISABLED (ad-hoc, for this Mac only)${NC}"
fi

# --- Fonts -------------------------------------------------------------------
# Switzer isn't in the repo (its licence forbids that); fetch it from Fontshare.
# A release must have it, so signed builds fail without it; local builds fall
# back to the system font.
step "Fetching fonts..."
if ! ./Scripts/fetch-fonts.sh; then
    [ "$SIGN_APP" = true ] && { echo -e "${RED}Error: couldn't download Switzer.${NC}"; exit 1; }
    echo -e "${YELLOW}Warning: couldn't download Switzer; this build uses the system font.${NC}"
fi

# --- Build (universal) -------------------------------------------------------
step "Compiling release (arm64 + x86_64)..."
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN_DIR=$(swift build -c release "${ARCHS[@]}" --show-bin-path)

# --- Assemble the bundle -----------------------------------------------------
step "Assembling ${APP_NAME}.app..."
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Frameworks" "${APP_PATH}/Contents/Resources"

cp "${BIN_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
# ditto keeps the framework's symlinks (Versions/Current), which codesign requires
ditto "${BIN_DIR}/Sparkle.framework" "${APP_PATH}/Contents/Frameworks/Sparkle.framework"
cp "${INFO_PLIST}" "${APP_PATH}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_PATH}/Contents/Info.plist"
[ -f "${ICON}" ] && cp "${ICON}" "${APP_PATH}/Contents/Resources/AppIcon.icns"
if ls .fonts/*.otf >/dev/null 2>&1; then
    mkdir -p "${APP_PATH}/Contents/Resources/Fonts"
    cp .fonts/*.otf .fonts/LICENSE.txt "${APP_PATH}/Contents/Resources/Fonts/"
fi

# --- Sign --------------------------------------------------------------------
SPARKLE="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
if [ "$SIGN_APP" = true ]; then
    step "Signing with Developer ID + hardened runtime (inside out)..."
    CS=(codesign --force --timestamp --options runtime --sign "${DEVELOPER_ID}")
    # Sparkle's nested helpers each need the hardened runtime, or notarisation
    # comes back Invalid (the lesson from Cargo's first signed release)
    "${CS[@]}" "${SPARKLE}/Versions/B/XPCServices/Installer.xpc"
    "${CS[@]}" --preserve-metadata=entitlements "${SPARKLE}/Versions/B/XPCServices/Downloader.xpc"
    "${CS[@]}" "${SPARKLE}/Versions/B/Autoupdate"
    "${CS[@]}" "${SPARKLE}/Versions/B/Updater.app"
    "${CS[@]}" "${SPARKLE}"
    "${CS[@]}" --entitlements "${ENTITLEMENTS}" "${APP_PATH}"
else
    step "Ad-hoc signing..."
    codesign --force --deep --sign - "${APP_PATH}"
fi
codesign --verify --deep --strict --verbose=1 "${APP_PATH}"

if [ "$APP_ONLY" = true ]; then
    echo -e "${GREEN}Built ${APP_PATH}${NC}"
    exit 0
fi

# --- DMG ---------------------------------------------------------------------
step "Creating DMG..."
if command -v create-dmg &> /dev/null; then
    VOLICON=(); [ -f "${ICON}" ] && VOLICON=(--volicon "${ICON}")
    create-dmg \
        --volname "${APP_NAME}" "${VOLICON[@]}" \
        --window-pos 200 120 --window-size 600 400 --icon-size 100 \
        --icon "${APP_NAME}.app" 150 185 --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 185 --no-internet-enable \
        "${DMG_PATH}" "${DMG_DIR}" || USE_HDIUTIL=true
else
    USE_HDIUTIL=true
fi
if [ "${USE_HDIUTIL}" = true ]; then
    ln -sf /Applications "${DMG_DIR}/Applications"
    hdiutil create -srcfolder "${DMG_DIR}" -volname "${APP_NAME}" -fs HFS+ \
        -format UDZO -imagekey zlib-level=9 -ov "${DMG_PATH}"
fi

if [ "$SIGN_APP" = true ]; then
    step "Signing DMG..."
    codesign --force --timestamp --sign "${DEVELOPER_ID}" "${DMG_PATH}"
fi

if [ "$SIGN_APP" = true ] && [ "$NOTARIZE" = true ]; then
    step "Notarising (a few minutes)..."
    xcrun notarytool submit "${DMG_PATH}" "${NOTARY_ARGS[@]}" --wait | tee "${BUILD_DIR}/notary.log"
    grep -q "status: Accepted" "${BUILD_DIR}/notary.log" || { echo -e "${RED}Notarisation was not accepted.${NC}"; exit 1; }
    xcrun stapler staple "${DMG_PATH}"
fi

CHECKSUM=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')
echo "${CHECKSUM}  $(basename "${DMG_PATH}")" > "${DMG_PATH}.sha256"

echo ""
echo -e "${GREEN}Build complete${NC}"
echo "DMG:     ${DMG_PATH} ($(ls -lh "${DMG_PATH}" | awk '{print $5}'))"
echo "SHA256:  ${CHECKSUM}"
if [ "$SIGN_APP" = true ]; then
    echo "Signed:  yes · Notarised: ${NOTARIZE}"
    [ "$NOTARIZE" = true ] && echo "Check:   spctl -a -vvv -t install ${DMG_PATH}"
else
    echo -e "${YELLOW}Not signed: for testing on this Mac only. Use: make package SIGN=1${NC}"
fi
