#!/bin/bash
#
# build-release.sh
# Builds, signs, notarizes, and packages NotchFlow.app into a DMG
#
# Usage: ./build-release.sh
#
# Environment variables (for CI):
#   APPLE_TEAM_ID         - 10-character Team ID
#   APPLE_ID              - Apple ID email for notarization
#   APPLE_ID_PASSWORD     - App-specific password
#   SKIP_NOTARIZATION     - Set to "true" to skip notarization (local testing)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="NotchFlow"
SCHEME="NotchFlow"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"
DMG_DIR="${BUILD_DIR}/dmg"

# Get version from Info.plist
INFO_PLIST="${PROJECT_DIR}/${PROJECT_NAME}/Resources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
DMG_NAME="${PROJECT_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Building ${PROJECT_NAME} v${VERSION}${NC}"
echo -e "${GREEN}========================================${NC}"

# Clean previous builds
echo -e "\n${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$EXPORT_PATH" "$DMG_DIR"

# Resolve Swift packages
echo -e "\n${YELLOW}Resolving Swift packages...${NC}"
cd "$PROJECT_DIR"
xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME"

# Build archive
echo -e "\n${YELLOW}Building archive...${NC}"
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create export options plist
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

# Export signed app
echo -e "\n${YELLOW}Exporting signed app...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

# Verify the app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at ${APP_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}App exported to: ${APP_PATH}${NC}"

# Create DMG
echo -e "\n${YELLOW}Creating DMG...${NC}"

# Prepare DMG contents
cp -R "$APP_PATH" "$DMG_DIR/"

# Create a symbolic link to /Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG using hdiutil
hdiutil create -volname "$PROJECT_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo -e "${GREEN}DMG created: ${DMG_PATH}${NC}"

# Notarization
if [ "${SKIP_NOTARIZATION:-false}" = "true" ]; then
    echo -e "\n${YELLOW}Skipping notarization (SKIP_NOTARIZATION=true)${NC}"
else
    if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_ID_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
        echo -e "\n${YELLOW}Skipping notarization (credentials not set)${NC}"
        echo "Set APPLE_ID, APPLE_ID_PASSWORD, and APPLE_TEAM_ID to enable notarization"
    else
        echo -e "\n${YELLOW}Submitting for notarization...${NC}"
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

        echo -e "\n${YELLOW}Stapling notarization ticket...${NC}"
        xcrun stapler staple "$DMG_PATH"

        echo -e "${GREEN}Notarization complete!${NC}"
    fi
fi

# Calculate SHA256
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

# Output summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Version:  ${VERSION}"
echo -e "DMG:      ${DMG_PATH}"
echo -e "Size:     $(du -h "$DMG_PATH" | cut -f1)"
echo -e "SHA256:   ${SHA256}"
echo -e "\n${YELLOW}For Homebrew Cask:${NC}"
echo "  sha256 \"${SHA256}\""
