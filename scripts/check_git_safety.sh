#!/bin/bash

# Git Safety Check Script
# This script verifies that sensitive files are properly ignored by Git

echo "🔍 Checking Git safety for MedWave project..."
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for issues
issues=0

# Function to check if a file would be tracked by Git
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        if git check-ignore "$file" > /dev/null 2>&1; then
            echo -e "✅ ${GREEN}SAFE${NC}: $description ($file) is properly ignored"
        else
            echo -e "❌ ${RED}DANGER${NC}: $description ($file) will be tracked by Git!"
            issues=$((issues + 1))
        fi
    else
        echo -e "ℹ️  ${YELLOW}INFO${NC}: $description ($file) does not exist"
    fi
}

# Function to check if a pattern is ignored
check_pattern() {
    local pattern="$1"
    local description="$2"
    
    # Create a temporary file with the pattern to test
    local temp_file="temp_$pattern"
    touch "$temp_file"
    
    if git check-ignore "$temp_file" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}SAFE${NC}: $description pattern (*$pattern) is properly ignored"
    else
        echo -e "❌ ${RED}DANGER${NC}: $description pattern (*$pattern) is NOT ignored!"
        issues=$((issues + 1))
    fi
    
    rm -f "$temp_file"
}

echo ""
echo "Checking Firebase configuration files..."
check_file "lib/firebase_options.dart" "Firebase Options (Dart)"
check_file "android/app/google-services.json" "Google Services (Android)"
check_file "ios/Runner/GoogleService-Info.plist" "Google Services (iOS)"

echo ""
echo "Checking Firebase Admin SDK keys..."
check_file "bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json" "Firebase Admin SDK Key 1"
check_file "bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json" "Firebase Admin SDK Key 2"
check_file "scripts/firebase-key.json" "Firebase Admin SDK Key (scripts)"

echo ""
echo "Checking Android configuration..."
check_file "android/key.properties" "Android Signing Keys"
check_file "android/local.properties" "Android Local Properties"

echo ""
echo "Checking user data files..."
check_file "users.json" "User Data"

echo ""
echo "Checking common patterns..."
check_pattern ".env" "Environment files"
check_pattern "firebase-adminsdk" "Firebase Admin SDK"

echo ""
echo "============================================="

if [ $issues -eq 0 ]; then
    echo -e "🎉 ${GREEN}ALL CHECKS PASSED!${NC} Your repository is safe to push to Git."
    echo ""
    echo "You can now safely run:"
    echo "  git add ."
    echo "  git commit -m 'Your commit message'"
    echo "  git push"
else
    echo -e "⚠️  ${RED}$issues ISSUES FOUND!${NC} Do NOT push to Git until these are resolved."
    echo ""
    echo "To fix these issues:"
    echo "1. Check that .gitignore file exists and contains the proper exclusions"
    echo "2. Move sensitive files to template files if needed"
    echo "3. Run this script again to verify fixes"
    exit 1
fi

echo ""
echo "💡 Remember:"
echo "  - Template files (.template.*) are safe to commit"
echo "  - Actual configuration files should never be committed"
echo "  - Share template files with your team for easy setup"
