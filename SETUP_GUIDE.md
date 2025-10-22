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

### 4. Set Up API Keys Configuration
1. Copy the API keys template:
   ```bash
   cp lib/config/api_keys.template.dart lib/config/api_keys.dart
   ```
2. Edit `lib/config/api_keys.dart` and replace placeholder values with your actual API keys:
   - `openaiApiKey` - Get from [OpenAI Platform](https://platform.openai.com/api-keys)
   - `goHighLevelApiKey` - Get from [GoHighLevel Marketplace](https://marketplace.gohighlevel.com/)
   - `goHighLevelProxyUrl` - Use production URL or `http://localhost:3001/api/ghl` for local development

### 5. Set Up Node.js Proxy Server (ghl-proxy)
The proxy server handles GoHighLevel API requests and is required for web deployment.

1. Navigate to the proxy directory:
   ```bash
   cd ghl-proxy
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy the environment template:
   ```bash
   cp .env.template .env
   ```
4. Edit `.env` and add your GoHighLevel API key:
   ```
   GHL_API_KEY=your_gohighlevel_private_integration_token_here
   PORT=3001
   ```
5. Start the proxy server:
   ```bash
   npm start
   ```

### 6. Set Up Firebase Functions
Firebase Functions provide backend API endpoints and handle server-side operations.

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. For **local development**, copy the environment template:
   ```bash
   cp .env.template .env
   ```
4. Edit `functions/.env` and add your API key:
   ```
   GHL_API_KEY=your_gohighlevel_api_key_here
   ```
5. For **production deployment**, configure Firebase Functions secrets:
   ```bash
   firebase functions:config:set ghl.api_key="your_gohighlevel_api_key_here"
   ```
6. Test locally:
   ```bash
   firebase emulators:start --only functions
   ```

### 7. Set Up Firebase Admin SDK (Backend Services)
The Firebase Admin SDK keys are used for server-side Firebase operations.

1. **Files are already in the repository root** (gitignored, safe locally):
   - `bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json`
   - `bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json`

2. **For production/CI-CD**, Firebase Functions automatically have Admin SDK access (no additional setup needed)

3. **For enhanced security** (optional), see `FIREBASE_ADMIN_SDK_SETUP.md` for instructions on storing keys outside the repository

4. **To generate new keys** (if needed):
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project `bhl-obe`
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save securely (do NOT commit to git)

## 🔒 Security Features

The following files are **automatically excluded** from Git via `.gitignore`:

### API Keys & Secrets
- `lib/config/api_keys.dart` - OpenAI and GoHighLevel API keys
- `ghl-proxy/.env` - Proxy server environment variables
- `functions/.env` - Firebase Functions local environment variables

### Firebase & Google Services
- `google-services.json`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase_options.dart`
- `lib/firebase_options.dart`

### Firebase Admin SDK Keys
- `bhl-obe-firebase-adminsdk-*.json` - Private keys for server-side operations
- `scripts/firebase-key.json`
- `*firebase-adminsdk*.json`

### Local Configuration
- `android/key.properties` - Android app signing credentials
- `android/local.properties` - Local Android SDK paths
- `users.json` - Test user data with password hashes

### Environment Variables
- `.env*` files - All environment variable files

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
