#!/bin/bash

# MedWave Security Verification Script
# Run this before committing to ensure no sensitive data is exposed

echo "🔒 MedWave Security Verification"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check 1: Verify .gitignore exists
echo "1️⃣  Checking .gitignore exists..."
if [ -f .gitignore ]; then
    echo -e "${GREEN}✅ .gitignore found${NC}"
else
    echo -e "${RED}❌ .gitignore missing!${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 2: Verify sensitive files are not tracked
echo "2️⃣  Checking for tracked sensitive files..."
SENSITIVE_FILES=$(git ls-files | grep -E "(api_keys\.dart|firebase_options\.dart|firebase-adminsdk|users\.json|key\.properties|local\.properties|\.env$)" || true)
if [ -z "$SENSITIVE_FILES" ]; then
    echo -e "${GREEN}✅ No sensitive files tracked by git${NC}"
else
    echo -e "${RED}❌ Found tracked sensitive files:${NC}"
    echo "$SENSITIVE_FILES"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 3: Check for hardcoded API keys in TRACKED source files
echo "3️⃣  Scanning for hardcoded API keys in tracked files..."
# Only check files that are tracked by git (excludes .gitignored files)
HARDCODED_KEYS=$(git ls-files | grep -E '\.(dart|js)$' | xargs grep -l "sk-proj-\|pit-009fb0b0" 2>/dev/null || true)
if [ -z "$HARDCODED_KEYS" ]; then
    echo -e "${GREEN}✅ No hardcoded API keys found in tracked files${NC}"
else
    echo -e "${RED}❌ Found hardcoded API keys in tracked files:${NC}"
    echo "$HARDCODED_KEYS"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 4: Verify template files exist
echo "4️⃣  Checking template files exist..."
TEMPLATE_FILES=(
    "lib/config/api_keys.template.dart"
    "lib/firebase_options.template.dart"
    "android/key.template.properties"
    "ghl-proxy/.env.template"
    "functions/.env.template"
)

for file in "${TEMPLATE_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file exists${NC}"
    else
        echo -e "${YELLOW}⚠️  $file missing${NC}"
    fi
done
echo ""

# Check 5: Verify actual config files exist locally (should NOT be in git)
echo "5️⃣  Checking local configuration files..."
LOCAL_FILES=(
    "lib/config/api_keys.dart"
    "lib/firebase_options.dart"
    "ghl-proxy/.env"
    "functions/.env"
)

for file in "${LOCAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file exists (local only)${NC}"
    else
        echo -e "${YELLOW}⚠️  $file missing (needed for local development)${NC}"
    fi
done
echo ""

# Final summary
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Security verification PASSED${NC}"
    echo "Safe to commit!"
    exit 0
else
    echo -e "${RED}❌ Security verification FAILED with $ERRORS error(s)${NC}"
    echo "DO NOT commit until issues are resolved!"
    exit 1
fi
