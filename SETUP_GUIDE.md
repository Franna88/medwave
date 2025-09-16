# MedWave Setup Guide

This guide helps you set up the MedWave project safely with all sensitive configurations.

## ⚠️ IMPORTANT SECURITY NOTICE

This project contains sensitive Firebase keys and configuration files that are **excluded from Git** for security reasons. You must set up these files locally after cloning the repository.

## 🚀 Quick Setup

### 1. Clone the Repository
```bash
git clone <your-repository-url>
cd medwave
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Set Up Firebase Configuration

#### A. Firebase Options (Dart)
1. Copy the template file:
   ```bash
   cp lib/firebase_options.template.dart lib/firebase_options.dart
   ```
2. Edit `lib/firebase_options.dart` and replace all `YOUR_*` placeholders with your actual Firebase project values
3. You can get these values from the Firebase Console > Project Settings > General tab

#### B. Google Services (Android)
1. Copy the template file:
   ```bash
   cp google-services.template.json android/app/google-services.json
   ```
2. **OR** Download the actual `google-services.json` from Firebase Console:
   - Go to Firebase Console > Project Settings > General tab
   - Under "Your apps" section, click the Android app
   - Click "Download google-services.json"
   - Place the file in `android/app/` directory

#### C. Android Signing Keys (if needed for release builds)
1. Copy the template file:
   ```bash
   cp android/key.template.properties android/key.properties
   ```
2. Edit `android/key.properties` with your actual keystore information

### 4. Set Up Firebase Admin SDK (if using server-side features)
1. Go to Firebase Console > Project Settings > Service Accounts
2. Generate a new private key for the "Firebase Admin SDK"
3. Save the downloaded JSON file as `scripts/firebase-key.json`

## 🔒 Security Features

The following files are **automatically excluded** from Git via `.gitignore`:

### Firebase & Google Services
- `google-services.json`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase_options.dart`
- `lib/firebase_options.dart`

### Firebase Admin SDK Keys
- `bhl-obe-firebase-adminsdk-*.json`
- `scripts/firebase-key.json`
- `*firebase-adminsdk*.json`

### Local Configuration
- `android/key.properties`
- `android/local.properties`
- `users.json`

### Environment Variables
- `.env*` files

## 🛠️ Development

### Running the App
```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

### Building for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS (requires Xcode on macOS)
flutter build ios --release
```

## 🔧 Troubleshooting

### Firebase Connection Issues
1. Verify your `firebase_options.dart` has correct values
2. Ensure `google-services.json` is in the right location (`android/app/`)
3. Check Firebase project settings match your app's package name

### Build Issues
1. Run `flutter clean && flutter pub get`
2. Check that all template files have been copied and configured
3. Verify Android signing configuration if building release APK

### Missing Files
If you get errors about missing files:
1. Check that you've copied all template files as described above
2. Ensure the `.gitignore` file exists and contains the security rules
3. Contact the development team for the actual configuration files

## 📞 Support

For setup assistance or access to configuration files, contact the development team.

## ⚠️ Security Reminders

- **NEVER** commit actual Firebase keys or configuration files to Git
- **ALWAYS** use the template files as starting points
- **VERIFY** that sensitive files are listed in `.gitignore` before pushing
- **USE** environment variables for additional secrets when possible
