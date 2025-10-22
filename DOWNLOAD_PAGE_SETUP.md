# Download Page Setup Guide

## Current Status

✅ **Download button added** to Welcome Screen and Login Screen
✅ **Beautiful download page created** with iOS and Android options
✅ **Local file path configured** for testing

---

## What the Download Page Includes

### Visual Design:
- 🎨 **Modern gradient background** (purple to blue)
- 📱 **Two prominent download cards**: iOS (blue) and Android (green)
- 🎯 **Platform-specific icons** and colors
- 📖 **Tabbed installation instructions**
- 🔒 **Security notices** and warnings
- 💡 **Troubleshooting sections**
- 📊 **App information** (version, size, requirements)

### iOS Section Features:
- ✅ What is TestFlight explanation
- ✅ Step-by-step installation (5 steps)
- ✅ TestFlight download link
- ✅ Invitation acceptance guide
- ✅ Update notifications info
- ✅ 90-day expiration warning

### Android Section Features:
- ✅ APK download button
- ✅ "Unknown Sources" enable guide (Android 8.0+ and earlier)
- ✅ Installation steps (5 steps)
- ✅ Security recommendations
- ✅ Troubleshooting common issues
- ✅ Update process explanation

---

## Testing the Download Page

### Step 1: Hot Reload Your App
In your terminal where Flutter is running:
```bash
# Press 'r' for hot reload
r
```

### Step 2: Click "Download App" Button
- The button is in the top-right corner
- It should open your default browser
- You'll see the beautiful download page with iOS and Android options

### Step 3: Test Both Platforms
- **iOS Button**: Will show placeholder (needs TestFlight link)
- **Android Button**: Will download the APK file
- **Tab Navigation**: Switch between iOS and Android instructions

---

## Next Steps: Add Your Links

### 1. Add TestFlight Invitation Link

**File to Edit:** `downloads_public/index.html`
**Line:** ~353

**Find this:**
```html
<a href="[TESTFLIGHT_URL_PLACEHOLDER]" class="download-btn ios-btn" target="_blank">
```

**Replace with your TestFlight link:**
```html
<a href="https://testflight.apple.com/join/YOUR_CODE_HERE" class="download-btn ios-btn" target="_blank">
```

**How to get TestFlight link:**
1. Go to App Store Connect (https://appstoreconnect.apple.com)
2. Select your app → TestFlight
3. Click "External Testing" or "Internal Testing"
4. Create or select a test group
5. Copy the "Public Link" or invitation link

### 2. Deploy to Production (When Ready)

When you're ready to deploy, update the URLs:

**Files to Update:**
- `lib/screens/auth/welcome_screen.dart` (Line ~55)
- `lib/screens/auth/login_screen.dart` (Line ~136)

**Change from:**
```dart
const downloadUrl = 'file:///Users/mac/dev/medwave/downloads_public/index.html';
```

**To your production URL:**
```dart
const downloadUrl = 'https://yourdomain.com/downloads/';
// OR
const downloadUrl = 'https://medwave.app/downloads/';
```

---

## Deployment Options

### Option A: Firebase Hosting (Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting
firebase init hosting

# Select your project
# Set public directory to: downloads_public

# Deploy
firebase deploy --only hosting
```

You'll get a URL like: `https://your-project.web.app/`

### Option B: GitHub Pages
1. Create a new repository or use existing
2. Upload `downloads_public/` folder
3. Enable GitHub Pages in repository settings
4. Access at: `https://yourusername.github.io/repository-name/`

### Option C: Your Own Web Server
1. Upload `downloads_public/` folder to your server
2. Make sure it's accessible via HTTPS
3. Use the full URL in your Flutter code

---

## File Structure

```
downloads_public/
├── index.html                 # Main download page
└── MedWave-v1.2.7.apk        # Android APK file
```

**Important:** Make sure both files are uploaded together!

---

## Customization

### Update App Version
**File:** `downloads_public/index.html`
**Lines:** ~336-350

```html
<div class="info-item">
    <strong>Version</strong>
    <span>1.2.7 (Build 9)</span>  <!-- Update this -->
</div>
```

### Update Support Email
**File:** `downloads_public/index.html`
**Line:** ~709

```html
📧 Email: <a href="mailto:support@medwave.com">support@medwave.com</a>
```

### Change Colors
Edit the CSS in `downloads_public/index.html`:
- iOS button: `.ios-btn` (currently blue)
- Android button: `.android-btn` (currently green)
- Background gradient: `body` (currently purple to blue)

---

## Testing Checklist

- [ ] Hot reload app to see button
- [ ] Click "Download App" button
- [ ] Verify download page opens in browser
- [ ] Check iOS card displays correctly
- [ ] Check Android card displays correctly
- [ ] Test tab switching (iOS ↔ Android)
- [ ] Verify Android APK download works
- [ ] Check responsive design on mobile
- [ ] Test on different browsers
- [ ] Verify all instructions are clear

---

## Troubleshooting

### Button Click Shows Error
**Issue:** "Could not open download page"
**Solution:** 
- Check the URL is correct in the code
- Verify the file path exists
- Try hot restart instead of hot reload

### Download Page Doesn't Load
**Issue:** Blank page or 404 error
**Solution:**
- Verify `downloads_public/index.html` exists
- Check file permissions
- Try opening the file directly in browser

### iOS Button Doesn't Work
**Issue:** TestFlight link not working
**Solution:**
- Replace `[TESTFLIGHT_URL_PLACEHOLDER]` with actual link
- Verify TestFlight invitation is active
- Test link in browser first

### Android APK Won't Download
**Issue:** APK file not found
**Solution:**
- Verify `MedWave-v1.2.7.apk` is in `downloads_public/` folder
- Check file path in HTML is correct
- Ensure file permissions allow download

---

## Production Deployment Steps

### 1. Prepare Files
```bash
cd /Users/mac/dev/medwave/downloads_public
```

### 2. Update TestFlight Link
Edit `index.html` and replace `[TESTFLIGHT_URL_PLACEHOLDER]`

### 3. Deploy to Hosting
Choose your hosting method (Firebase, GitHub Pages, etc.)

### 4. Update Flutter Code
Replace file path with production URL in:
- `lib/screens/auth/welcome_screen.dart`
- `lib/screens/auth/login_screen.dart`

### 5. Test Production
- Build and deploy Flutter app
- Test download button
- Verify both download options work

### 6. Update Documentation
Update `DOWNLOAD_APP_BUTTON_IMPLEMENTATION.md` with production URLs

---

## Support

### Common Questions

**Q: Can I use Google Play Store link instead of APK?**
A: Yes! Once approved, update the Android button href to your Play Store link.

**Q: How often should I update the download page?**
A: Update whenever you release a new app version.

**Q: Can I add more platforms?**
A: Yes! The design is flexible. Add more cards for web, desktop, etc.

**Q: Is the download page mobile-friendly?**
A: Yes! It's fully responsive and works on all devices.

---

**Last Updated:** October 16, 2025
**Status:** ✅ Ready for Testing
**Next:** Add TestFlight link and deploy to production



