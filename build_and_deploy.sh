#!/bin/bash

# MedWave APK Build and Deploy Script
# Usage: ./build_and_deploy.sh [version]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="MedWave"
OUTPUT_DIR="build/app/outputs/flutter-apk"
DEPLOY_DIR="deployment"
VERSION_FILE="pubspec.yaml"

echo -e "${BLUE}🏥 MedWave APK Build & Deploy Script${NC}"
echo "================================="

# Create deployment directory if it doesn't exist
mkdir -p $DEPLOY_DIR

# Step 1: Clean previous build
echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
flutter clean

# Step 2: Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Step 3: Extract current version
CURRENT_VERSION=$(grep '^version:' $VERSION_FILE | sed 's/version: //')
echo -e "${BLUE}📋 Current version: ${CURRENT_VERSION}${NC}"

# Step 4: Build APK
echo -e "${YELLOW}🔨 Building release APK...${NC}"
flutter build apk --release

# Step 5: Check if build was successful
if [ ! -f "$OUTPUT_DIR/app-release.apk" ]; then
    echo -e "${RED}❌ Build failed! APK not found.${NC}"
    exit 1
fi

# Step 6: Get APK info
APK_SIZE=$(ls -lh "$OUTPUT_DIR/app-release.apk" | awk '{print $5}')
APK_CHECKSUM=$(shasum -a 256 "$OUTPUT_DIR/app-release.apk" | awk '{print $1}')

echo -e "${GREEN}✅ Build successful!${NC}"
echo -e "${BLUE}📱 APK Size: ${APK_SIZE}${NC}"
echo -e "${BLUE}🔒 SHA-256: ${APK_CHECKSUM}${NC}"

# Step 7: Copy to deployment directory with version name
VERSIONED_APK="${APP_NAME}-v${CURRENT_VERSION}.apk"
cp "$OUTPUT_DIR/app-release.apk" "$DEPLOY_DIR/$VERSIONED_APK"
cp "$OUTPUT_DIR/app-release.apk" "$DEPLOY_DIR/app-release.apk"  # Latest version

echo -e "${GREEN}📁 APK copied to: ${DEPLOY_DIR}/${VERSIONED_APK}${NC}"

# Step 8: Update verification file
cat > "$DEPLOY_DIR/verification.txt" << EOF
$APP_NAME APK Security Verification
================================

File: $VERSIONED_APK
Version: $CURRENT_VERSION
Size: $(stat -f%z "$DEPLOY_DIR/$VERSIONED_APK") bytes
SHA-256: $APK_CHECKSUM
Build Date: $(date)

Verification Instructions:
-------------------------
1. Check file size matches exactly
2. Verify SHA-256 checksum
3. Ensure download source is trusted

Expected SHA-256: $APK_CHECKSUM

Built with Flutter $(flutter --version | head -n1)
Last Updated: $(date)
EOF

# Step 9: Update download page
sed -i.bak "s/Version:[^<]*/Version: ${CURRENT_VERSION%+*} (Build ${CURRENT_VERSION#*+})/" apk_download.html
sed -i.bak "s/File Size:[^<]*/File Size: $APK_SIZE/" apk_download.html
sed -i.bak "s/Last Updated:[^<]*/Last Updated: $(date +"%B %d, %Y")/" apk_download.html
rm apk_download.html.bak

echo -e "${GREEN}📄 Download page updated${NC}"

# Step 10: Create changelog entry
CHANGELOG_FILE="$DEPLOY_DIR/CHANGELOG.md"
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "# MedWave Changelog" > "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
fi

# Add new version to changelog
sed -i.bak "1a\\
\\
## Version $CURRENT_VERSION - $(date +"%Y-%m-%d")\\
\\
### Changes\\
- [Add your changes here]\\
- Bug fixes and performance improvements\\
\\
### Technical Details\\
- APK Size: $APK_SIZE\\
- SHA-256: $APK_CHECKSUM\\
" "$CHANGELOG_FILE"
rm "$CHANGELOG_FILE.bak"

echo -e "${GREEN}📝 Changelog updated${NC}"

# Step 11: Summary
echo ""
echo -e "${GREEN}🎉 Build and deployment preparation complete!${NC}"
echo ""
echo "📋 Summary:"
echo "  • APK: $DEPLOY_DIR/$VERSIONED_APK"
echo "  • Size: $APK_SIZE"
echo "  • Checksum: ${APK_CHECKSUM:0:16}..."
echo ""
echo "🚀 Next steps:"
echo "  1. Test the APK on a device"
echo "  2. Upload $DEPLOY_DIR/ contents to your hosting platform"
echo "  3. Update the download URL if needed"
echo "  4. Notify users of the new version"
echo ""
echo -e "${YELLOW}⚠️  Remember to update CHANGELOG.md with actual changes!${NC}"
