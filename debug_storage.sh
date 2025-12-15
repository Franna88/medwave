#!/bin/bash
# Debug script to gather Android emulator storage evidence
# Maps to hypotheses H1, H3, H4, H5

LOGFILE="/Users/mac/dev/medwave/.cursor/debug.log"
TIMESTAMP=$(date +%s)000

# Helper function to log in NDJSON format
log_data() {
    local location="$1"
    local message="$2"
    local data="$3"
    local hypothesis="$4"
    echo "{\"timestamp\":${TIMESTAMP},\"location\":\"${location}\",\"message\":\"${message}\",\"data\":${data},\"sessionId\":\"debug-session\",\"runId\":\"storage-check\",\"hypothesisId\":\"${hypothesis}\"}" >> "$LOGFILE"
}

echo "=== Gathering Android Emulator Storage Evidence ==="

# H1 & H4: Check emulator storage
echo "Checking emulator storage..."
STORAGE_OUTPUT=$(adb -s emulator-5554 shell df -h 2>&1)
log_data "debug_storage.sh:23" "Emulator storage check" "{\"storage\":\"$(echo "$STORAGE_OUTPUT" | tr '\n' ' ' | sed 's/"/\\"/g')\"}" "H1,H4"

# H3: Check APK size
echo "Checking APK size..."
APK_SIZE=$(ls -lh /Users/mac/dev/medwave/build/app/outputs/flutter-apk/app-debug.apk 2>&1)
log_data "debug_storage.sh:28" "APK size check" "{\"apk_size\":\"$(echo "$APK_SIZE" | sed 's/"/\\"/g')\"}" "H3"

# H2: Check existing app installation
echo "Checking existing app installation..."
APP_INFO=$(adb -s emulator-5554 shell pm list packages -f com.barefoot.medwave2 2>&1)
log_data "debug_storage.sh:33" "Existing app check" "{\"app_info\":\"$(echo "$APP_INFO" | sed 's/"/\\"/g')\"}" "H2"

# H4: Check data partition specifically
echo "Checking data partition..."
DATA_PARTITION=$(adb -s emulator-5554 shell df -h /data 2>&1)
log_data "debug_storage.sh:38" "Data partition check" "{\"data_partition\":\"$(echo "$DATA_PARTITION" | tr '\n' ' ' | sed 's/"/\\"/g')\"}" "H4"

# H5: Check temp/cache directories
echo "Checking cache directories..."
CACHE_SIZE=$(adb -s emulator-5554 shell du -sh /data/local/tmp 2>&1)
log_data "debug_storage.sh:43" "Cache directory size" "{\"cache_size\":\"$(echo "$CACHE_SIZE" | sed 's/"/\\"/g')\"}" "H5"

# Additional: Check if emulator is responsive
echo "Checking emulator responsiveness..."
ADB_DEVICES=$(adb devices 2>&1)
log_data "debug_storage.sh:48" "ADB devices status" "{\"devices\":\"$(echo "$ADB_DEVICES" | tr '\n' ' ' | sed 's/"/\\"/g')\"}" "H1"

echo "=== Evidence gathering complete. Check $LOGFILE for results ==="

