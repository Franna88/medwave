# Download App Deployment Guide

This guide explains how to deploy the download app functionality with iOS TestFlight form and Android APK download.

## Overview

The download app feature provides:
- **iOS**: TestFlight request form that stores user details in Firestore for manual invitation
- **Android**: APK download from Firebase Storage with installation instructions

## Prerequisites

- Firebase Admin SDK initialized
- Firebase Storage configured
- Firebase Cloud Functions deployed
- APK file available: `MedWave-v1.2.7.apk`

## Step 1: Upload APK to Firebase Storage

### Option A: Using the Upload Script (Recommended)

```bash
# Install dependencies if needed
cd functions
npm install firebase-admin
cd ..

# Run the upload script
node upload_apk_to_storage.js
```

The script will:
- Upload `MedWave-v1.2.7.apk` to Firebase Storage
- Store it at: `downloads/apks/MedWave-v1.2.7.apk`
- Set appropriate metadata and content type

### Option B: Manual Upload via Firebase Console

1. Go to Firebase Console > Storage
2. Create folder structure: `downloads/apks/`
3. Upload `MedWave-v1.2.7.apk` to this location
4. Set content type to: `application/vnd.android.package-archive`

## Step 2: Deploy Firestore Rules and Indexes

Deploy the updated Firestore security rules and indexes:

```bash
# Deploy Firestore rules (allows public write to testflight_requests)
firebase deploy --only firestore:rules

# Deploy Firestore indexes (for email + requestedAt query)
firebase deploy --only firestore:indexes
```

## Step 3: Deploy Cloud Functions

The Cloud Function generates signed download URLs for the APK.

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy just the API function
firebase deploy --only functions:api
```

### Cloud Function Endpoint

```
GET https://us-central1-medx-ai.cloudfunctions.net/api/api/download/apk
```

Response:
```json
{
  "downloadUrl": "https://storage.googleapis.com/...",
  "version": "1.2.7",
  "size": "66.8 MB",
  "fileName": "MedWave-v1.2.7.apk",
  "expiresIn": "1 hour"
}
```

## Step 4: Install Dependencies

Install the new `http` package for API calls:

```bash
flutter pub get
```

## Step 5: Build and Deploy Web App

```bash
# Build web version
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting:medx-ai
```

## Step 6: Test the Implementation

### Test iOS TestFlight Form

1. Navigate to: `<your-domain>/download-app`
2. Click "Request TestFlight Access" on iOS card
3. Fill in the form with test data
4. Submit and verify:
   - Success dialog appears
   - Check Firestore collection `testflight_requests` for new document

### Test Android APK Download

1. Navigate to: `<your-domain>/download-app`
2. Click "Download App" on Android card
3. Read the installation instructions dialog
4. Click "Continue to Download"
5. Verify:
   - Download starts
   - APK file downloads correctly
   - File size matches (~67 MB)

### Test Cloud Function Directly

```bash
curl https://us-central1-medx-ai.cloudfunctions.net/api/api/download/apk
```

Should return JSON with signed download URL.

## Firestore Collection Structure

### testflight_requests Collection

```javascript
{
  firstName: string,
  lastName: string,
  contactNumber: string,
  email: string,
  status: "pending",
  requestedAt: timestamp
}
```

### Viewing Requests

Go to Firebase Console > Firestore > `testflight_requests` to see all iOS download requests.

## Troubleshooting

### APK Not Found Error

**Error**: `APK file not found in Firebase Storage`

**Solution**:
- Verify APK is uploaded: Check Firebase Console > Storage
- Verify path is correct: `downloads/apks/MedWave-v1.2.7.apk`
- Re-run upload script if needed

### Cloud Function Permission Error

**Error**: `Failed to generate download URL`

**Solution**:
- Ensure Firebase Admin SDK is initialized
- Check Cloud Function logs: `firebase functions:log`
- Verify Storage bucket name in functions/index.js

### Download Not Starting

**Error**: Download doesn't start in browser

**Solution**:
- Check browser console for errors
- Verify Cloud Function endpoint is accessible
- Test endpoint directly with curl
- Check CORS configuration in Cloud Function

### Form Submission Failed

**Error**: `Failed to submit request`

**Solution**:
- Check Firestore security rules
- Verify network connection
- Check browser console for errors
- Ensure Firestore is initialized in the app

## Security Considerations

1. **APK Storage**: File is kept private, accessible only via signed URLs
2. **Signed URLs**: Expire after 1 hour for security
3. **TestFlight Data**: Stored in Firestore, accessible only to authenticated admins
4. **CORS**: Configured to allow requests from your domain

## Maintenance

### Updating the APK

When a new version is available:

1. Update the APK file name in:
   - `upload_apk_to_storage.js` (line 31)
   - `functions/index.js` (line 54)
   - `lib/screens/download/download_app_screen.dart` (multiple locations)

2. Upload the new APK:
   ```bash
   node upload_apk_to_storage.js
   ```

3. Deploy updated Cloud Function:
   ```bash
   firebase deploy --only functions
   ```

4. Build and deploy web app:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### Managing TestFlight Requests

To view and manage TestFlight requests:

1. Go to Firebase Console > Firestore
2. Navigate to `testflight_requests` collection
3. View all pending requests
4. Manually update status field after inviting users:
   - `pending` → `invited` (after sending TestFlight invitation)
   - `pending` → `rejected` (if request is declined)

## URLs

### Production URLs

- **Download Page**: `https://medx-ai.web.app/download-app`
- **APK Endpoint**: `https://us-central1-medx-ai.cloudfunctions.net/api/api/download/apk`

### Local Testing URLs

- **Download Page**: `http://localhost:5000/download-app` (after `flutter run -d chrome`)
- **APK Endpoint**: `http://localhost:5001/medx-ai/us-central1/api/api/download/apk` (with emulator)

## Support

For issues or questions:
- Check Cloud Function logs: `firebase functions:log`
- Check Firestore data: Firebase Console > Firestore
- Check Storage: Firebase Console > Storage
- Email: support@medwave.com

---

## Quick Reference Commands

```bash
# 1. Upload APK
node upload_apk_to_storage.js

# 2. Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# 3. Deploy Cloud Functions
firebase deploy --only functions

# 4. Install Flutter dependencies
flutter pub get

# 5. Build web app
flutter build web --release

# 6. Deploy web app
firebase deploy --only hosting:medx-ai

# View logs
firebase functions:log

# Test locally
flutter run -d chrome
```

## Implementation Checklist

- [x] Created TestFlight service
- [x] Updated download_app_screen.dart with iOS form and Android instructions
- [x] Added Cloud Function for APK download
- [x] Created upload script for APK
- [x] Added http package to pubspec.yaml
- [x] Updated Firestore security rules (allow public write to testflight_requests)
- [x] Added Firestore index for email + requestedAt query
- [x] Route already configured at `/download-app`
- [ ] Upload APK to Firebase Storage
- [ ] Deploy Firestore rules and indexes
- [ ] Deploy Cloud Functions
- [ ] Run `flutter pub get`
- [ ] Build and deploy web app
- [ ] Test iOS form submission
- [ ] Test Android APK download

---

**Last Updated**: October 2025  
**Version**: 1.2.7

