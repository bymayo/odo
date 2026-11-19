#!/bin/bash

# Odo release preparation: bump, commit, tag and push. CI does the rest.
# Usage: ./Scripts/prepare-release.sh <version> [commit message]

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

VERSION="$1"
COMMIT_MSG="${2:-Version ${VERSION}}"
INFO_PLIST="Packaging/Info.plist"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: version must be X.Y.Z (e.g. 1.0.2)${NC}"
    exit 1
fi

# Tags are cut from main, which is what release-health watches
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
    echo -e "${RED}Error: releases are tagged from main (you're on ${BRANCH}). Merge first.${NC}"
    exit 1
fi

# The release notes come from this section, verbatim
if ! grep -qE "^##[[:space:]]+${VERSION//./\\.}[[:space:]]*$" CHANGELOG.md; then
    echo -e "${RED}Error: CHANGELOG.md has no '## ${VERSION}' section. Add the release notes first.${NC}"
    exit 1
fi

CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "${GREEN}Preparing release v${VERSION}${NC}"
echo -e "${CYAN}Version: ${CURRENT_VERSION} -> ${VERSION}   Build: ${CURRENT_BUILD} -> ${NEW_BUILD}${NC}"
read -p "Continue? (y/n) " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo -e "${YELLOW}Aborted.${NC}"; exit 0; }

if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    echo -e "${RED}Error: tag v${VERSION} already exists.${NC}"
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" "$INFO_PLIST"

git add -A
git commit -m "v${VERSION}: ${COMMIT_MSG}" || echo "Nothing to commit"
git tag "v${VERSION}"
git push origin main
git push origin "v${VERSION}"

echo ""
echo -e "${GREEN}v${VERSION} tagged and pushed.${NC} The Build and Release workflow now signs,"
echo "notarises and publishes it to bymayo/odo-releases. Then confirm it:"
echo "  gh release view v${VERSION} --repo bymayo/odo-releases"
