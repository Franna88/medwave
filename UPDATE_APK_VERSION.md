# How to Update APK Version

## ✅ Version Updated to 1.2.12

All code has been updated to reference version **1.2.12** instead of 1.2.7.

## Files Updated

1. ✅ `upload_apk_to_storage.js` - Now looks for `MedWave-v1.2.12.apk`
2. ✅ `functions/index.js` - Cloud Function now serves `MedWave-v1.2.12.apk`
3. ✅ `lib/screens/download/download_app_screen.dart` - UI shows version 1.2.12

## Where to Find/Generate Your APK

### Option 1: Build Fresh APK (Recommended)

```bash
# Build the APK for release
flutter build apk --release

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk

# Rename it to match the version
mv build/app/outputs/flutter-apk/app-release.apk MedWave-v1.2.12.apk
```

### Option 2: Use Existing APK

If you already have a built APK, just rename it:

```bash
# If you have the latest build
cp path/to/your/latest.apk MedWave-v1.2.12.apk
```

### Option 3: Check Your Build Directory

```bash
# Check if you have a recent build
ls -lh build/app/outputs/flutter-apk/

# If you find app-release.apk with today's date, copy it
cp build/app/outputs/flutter-apk/app-release.apk MedWave-v1.2.12.apk
```

## Verify APK Version

Before uploading, verify the APK is the correct version:

```bash
# Check file exists
ls -lh MedWave-v1.2.12.apk

# Check file size (should be 60-70 MB)
# If much smaller, it might be the wrong build
```

## Upload to Firebase Storage

Once you have `MedWave-v1.2.12.apk` in your project root:

```bash
# Upload to Firebase Storage
node upload_apk_to_storage.js
```

**Expected output:**
```
🚀 Starting APK upload to Firebase Storage...
📁 Source: /Users/mac/dev/medwave/MedWave-v1.2.12.apk
📦 Destination: downloads/apks/MedWave-v1.2.12.apk
📊 File size: XX.X MB
✅ APK uploaded successfully!
```

## Deploy Cloud Functions

After uploading the APK, deploy the updated Cloud Function:

```bash
firebase deploy --only functions
```

This updates the Cloud Function to serve the new version 1.2.12 APK.

## Complete Deployment Sequence

```bash
# 1. Build APK (if needed)
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk MedWave-v1.2.12.apk

# 2. Upload APK to Firebase Storage
node upload_apk_to_storage.js

# 3. Deploy Firestore rules (if not done yet)
firebase deploy --only firestore:rules,firestore:indexes

# 4. Deploy Cloud Functions (updated to serve v1.2.12)
firebase deploy --only functions

# 5. Install Flutter dependencies (if not done yet)
flutter pub get

# 6. Build and deploy web app (if not done yet)
flutter build web --release
firebase deploy --only hosting:medx-ai
```

## Troubleshooting

### Error: APK file not found

```bash
# Make sure the file is in project root
ls MedWave-v1.2.12.apk

# If not, build it or copy it there
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk MedWave-v1.2.12.apk
```

### Wrong APK Size

If your APK is much smaller than 60-70 MB, you might have:
- Built a debug version (use `--release` flag)
- Built for a specific architecture only

Build the full release APK:
```bash
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

## Updating to Future Versions

When you release version 1.2.13 or later, update these files:

1. `upload_apk_to_storage.js` (lines 28-29, 55-56)
2. `functions/index.js` (lines 54, 79-81)
3. `lib/screens/download/download_app_screen.dart` (line 1038)
4. Your `pubspec.yaml` version number

Then follow the same deployment sequence above.

---

**Current Version**: 1.2.12  
**Last Updated**: October 17, 2025

