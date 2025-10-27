# Google Cloud Project Setup Guide for MedWave Calendar Sync

**Required Before:** Testing Google Calendar integration  
**Time Estimate:** 15-20 minutes  
**Date:** October 27, 2025

---

## Overview

This guide walks you through setting up Google Calendar API access for MedWave. You'll create OAuth 2.0 credentials that allow practitioners to securely connect their personal Google Calendars.

---

## Prerequisites

- Google Account (Gmail)
- Access to [Google Cloud Console](https://console.cloud.google.com)
- Firebase project already set up (medx-ai)

---

## Step-by-Step Instructions

### Step 1: Access Google Cloud Console

1. Go to: [https://console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with your Google account
3. Select your Firebase project: **medx-ai**
   - If you don't see it, click the project dropdown at the top
   - Search for "medx-ai" or your Firebase project ID

---

### Step 2: Enable Google Calendar API

1. In the left sidebar, navigate to: **APIs & Services** → **Library**
   - Or use the search bar: type "API Library"

2. In the API Library search bar, type: **Google Calendar API**

3. Click on **Google Calendar API** from the results

4. Click the blue **ENABLE** button

5. Wait for activation (takes a few seconds)

✅ **Verification:** You should see "API enabled" with a green checkmark

---

### Step 3: Configure OAuth Consent Screen

1. Navigate to: **APIs & Services** → **OAuth consent screen**

2. **Choose User Type:**
   - Select: **External** (allows any Google user)
   - Click **CREATE**

3. **App Information:**
   - **App name:** `MedWave`
   - **User support email:** Your email address
   - **App logo:** (Optional) Upload MedWave logo
   - **Application home page:** `https://medx-ai.web.app`
   - **Application privacy policy:** `https://medx-ai.web.app/privacy-policy.html`
   - **Application terms of service:** (Optional)
   - **Authorized domains:** Add `medx-ai.web.app` and `medx-ai.firebaseapp.com`
   - **Developer contact information:** Your email address

4. Click **SAVE AND CONTINUE**

5. **Scopes:**
   - Click **ADD OR REMOVE SCOPES**
   - Search for: `calendar`
   - Select these scopes:
     - ✅ `.../auth/calendar.events` - See, edit, share, and permanently delete all calendars
     - ✅ `.../auth/calendar.readonly` - See and download any calendar you can access using your Calendar
   - Click **UPDATE**
   - Click **SAVE AND CONTINUE**

6. **Test Users** (Optional for development):
   - Click **+ ADD USERS**
   - Add email addresses of practitioners who will test the feature
   - Click **SAVE AND CONTINUE**

7. **Summary:**
   - Review your settings
   - Click **BACK TO DASHBOARD**

✅ **Verification:** OAuth consent screen shows as "Configured"

---

### Step 4: Create OAuth 2.0 Credentials for Web

1. Navigate to: **APIs & Services** → **Credentials**

2. Click **+ CREATE CREDENTIALS** at the top
   - Select: **OAuth 2.0 Client ID**

3. **Application type:** Select **Web application**

4. **Name:** `MedWave Web Client`

5. **Authorized JavaScript origins:**
   - Click **+ ADD URI**
   - Add: `https://medx-ai.web.app`
   - Click **+ ADD URI** again
   - Add: `https://medx-ai.firebaseapp.com`
   - (For local testing) Add: `http://localhost:3000`

6. **Authorized redirect URIs:**
   - Click **+ ADD URI**
   - Add: `https://medx-ai.web.app/auth/google`
   - Click **+ ADD URI** again
   - Add: `https://medx-ai.firebaseapp.com/auth/google`
   - (For local testing) Add: `http://localhost:3000/auth/google`

7. Click **CREATE**

8. **IMPORTANT:** Copy the credentials shown:
   - **Your Client ID:** `xxxxx.apps.googleusercontent.com`
   - **Your Client Secret:** `xxxxx` (keep this secret!)

9. Click **OK** to close the dialog

✅ **Verification:** You now have a Web client credential listed

---

### Step 5: Create OAuth 2.0 Credentials for Android (Optional)

1. Click **+ CREATE CREDENTIALS** → **OAuth 2.0 Client ID**

2. **Application type:** Select **Android**

3. **Name:** `MedWave Android Client`

4. **Package name:** `com.medwave.app`
   - Check your `android/app/src/main/AndroidManifest.xml` for the correct package name

5. **SHA-1 certificate fingerprint:**
   
   **Get Debug Certificate:**
   ```bash
   cd android
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   
   **Get Release Certificate:**
   ```bash
   keytool -list -v -keystore /path/to/your/release-keystore.jks -alias your-key-alias
   ```
   
   Copy the **SHA-1** value (looks like: `A1:B2:C3:...`)

6. Click **CREATE**

7. Copy the **Client ID**

✅ **Verification:** Android client credential listed

---

### Step 6: Create OAuth 2.0 Credentials for iOS (Optional)

1. Click **+ CREATE CREDENTIALS** → **OAuth 2.0 Client ID**

2. **Application type:** Select **iOS**

3. **Name:** `MedWave iOS Client`

4. **Bundle ID:** `com.medwave.app`
   - Check your `ios/Runner/Info.plist` for the correct bundle identifier

5. Click **CREATE**

6. Copy the **Client ID**

✅ **Verification:** iOS client credential listed

---

### Step 7: Update MedWave Configuration

Now that you have your OAuth client IDs, update the MedWave code:

1. Open file: `lib/config/google_calendar_config.dart`

2. Replace the placeholder values:

```dart
/// Web Client ID for OAuth authentication
static const String webClientId = 'YOUR_ACTUAL_WEB_CLIENT_ID.apps.googleusercontent.com';

/// Android Client ID for OAuth authentication  
static const String androidClientId = 'YOUR_ACTUAL_ANDROID_CLIENT_ID.apps.googleusercontent.com';

/// iOS Client ID for OAuth authentication
static const String iosClientId = 'YOUR_ACTUAL_IOS_CLIENT_ID.apps.googleusercontent.com';
```

3. **IMPORTANT:** Replace `YOUR_ACTUAL_*` with the actual client IDs you copied

4. Save the file

✅ **Verification:** No placeholder values remain in the config file

---

### Step 8: Add OAuth Client ID to Flutter

For proper Google Sign-In integration on web, you may need to update your `web/index.html`:

1. Open `web/index.html`

2. Add this meta tag in the `<head>` section:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

3. Replace `YOUR_WEB_CLIENT_ID` with your actual web client ID

---

## Testing the Setup

### 1. Install Dependencies

```bash
cd /Users/mac/dev/medwave
flutter pub get
```

### 2. Run the App

```bash
# For web
flutter run -d chrome

# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

### 3. Test OAuth Flow

1. Navigate to **Settings** or **Profile**
2. Look for **Google Calendar Sync** option
3. Click **Connect Google Calendar**
4. You should see Google's OAuth consent screen
5. Sign in and authorize MedWave
6. You should return to the app with "Connected" status

---

## Troubleshooting

### Error: "Feature Unavailable" or "App Not Verified"

**Solution:** Your app is in testing mode. Add test users in OAuth consent screen, or publish your app.

### Error: "redirect_uri_mismatch"

**Solution:** 
- Check that your redirect URIs match exactly in Google Cloud Console
- Make sure you added both `medx-ai.web.app` and `medx-ai.firebaseapp.com`

### Error: "invalid_client"

**Solution:** 
- Verify your client ID is correct in `google_calendar_config.dart`
- Make sure you're using the right client ID for the platform (web/android/ios)

### Error: "Access blocked: Authorization Error"

**Solution:**
- Your app needs to be verified by Google for production use
- For testing, add users to the "Test users" list in OAuth consent screen

---

## Security Best Practices

1. **Never commit secrets:**
   - Add `google_calendar_config.dart` to `.gitignore` if it contains secrets
   - Use environment variables for sensitive data in production

2. **Restrict API keys:**
   - In Google Cloud Console → Credentials
   - Click on your API keys
   - Add application restrictions (HTTP referrers, Android apps, iOS apps)

3. **Monitor usage:**
   - Check Google Cloud Console → APIs & Services → Dashboard
   - Monitor quota usage and errors

4. **Keep credentials secure:**
   - Store refresh tokens encrypted in Firestore (already implemented)
   - Implement token rotation (already implemented)

---

## Production Checklist

Before launching to production:

- [ ] Verify OAuth consent screen is complete
- [ ] Add all necessary test users
- [ ] (Optional) Submit app for Google verification
- [ ] Test on all platforms (web, Android, iOS)
- [ ] Verify redirect URIs work in production
- [ ] Monitor API quota and usage
- [ ] Set up billing alerts in Google Cloud
- [ ] Review and test error handling
- [ ] Prepare user documentation

---

## Additional Resources

- [Google Calendar API Documentation](https://developers.google.com/calendar/api)
- [OAuth 2.0 for Mobile & Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google Cloud Console](https://console.cloud.google.com)
- [Firebase Console](https://console.firebase.google.com)

---

## Support

If you encounter issues:

1. Check the [Google Calendar API Forum](https://stackoverflow.com/questions/tagged/google-calendar-api)
2. Review Google Cloud Console → APIs & Services → Dashboard for errors
3. Check Firebase Functions logs for backend errors
4. Enable debug logging in Flutter for detailed error messages

---

**Setup Complete!** 🎉

Your MedWave app is now configured to sync with Google Calendar. Make sure to test the OAuth flow on all platforms before deploying to production.

---

**Last Updated:** October 27, 2025  
**Guide Version:** 1.0


