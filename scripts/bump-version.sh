#!/bin/bash
#
# bump-version.sh
# Updates version numbers in Info.plist
#
# Usage: ./bump-version.sh <version>
# Example: ./bump-version.sh 1.0.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check arguments
if [ $# -ne 1 ]; then
    echo -e "${RED}Usage: $0 <version>${NC}"
    echo "Example: $0 1.0.0"
    exit 1
fi

NEW_VERSION="$1"

# Validate version format (semver: X.Y.Z)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Version must be in format X.Y.Z (e.g., 1.0.0)${NC}"
    exit 1
fi

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INFO_PLIST="${PROJECT_DIR}/NotchFlow/Resources/Info.plist"

# Check if Info.plist exists
if [ ! -f "$INFO_PLIST" ]; then
    echo -e "${RED}Error: Info.plist not found at ${INFO_PLIST}${NC}"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST")

# Calculate new build number (increment by 1)
NEW_BUILD=$((CURRENT_BUILD + 1))

echo -e "${YELLOW}Updating version...${NC}"
echo "  Current: ${CURRENT_VERSION} (${CURRENT_BUILD})"
echo "  New:     ${NEW_VERSION} (${NEW_BUILD})"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${NEW_VERSION}" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" "$INFO_PLIST"

echo -e "\n${GREEN}Version updated successfully!${NC}"
echo -e "\nNext steps:"
echo "  git add ${INFO_PLIST}"
echo "  git commit -m \"Bump version to ${NEW_VERSION}\""
echo "  git tag v${NEW_VERSION}"
echo "  git push origin main --tags"
