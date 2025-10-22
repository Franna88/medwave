# Firebase Admin SDK Keys - Secure Storage Guide

## ⚠️ IMPORTANT: These files contain private keys and must NEVER be committed to git

## Current Status
The Firebase Admin SDK key files (`bhl-obe-firebase-adminsdk-*.json`) are already in `.gitignore` and will not be committed.

## Local Development Setup

### Option 1: Keep in Repository Root (Recommended for Local Dev)
The files are already gitignored, so you can keep them in the repository root for local development:
- `bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json`
- `bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json`

**These files are safe locally** because they're in `.gitignore`.

### Option 2: Store Outside Repository (More Secure)
For additional security, move these files to a secure location:

```bash
# Create secure directory
mkdir -p ~/.firebase/medwave-admin-sdk

# Move the files
mv bhl-obe-firebase-adminsdk-*.json ~/.firebase/medwave-admin-sdk/

# Reference them via environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.firebase/medwave-admin-sdk/bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json"
```

## Production/CI-CD Setup

### Firebase Functions (Automatic)
Firebase Functions automatically have access to Firebase Admin SDK when deployed. No additional configuration needed.

### GitHub Actions / CI-CD
Store the JSON content as a GitHub Secret:

1. Go to repository Settings → Secrets and variables → Actions
2. Create a new secret: `FIREBASE_ADMIN_SDK_KEY`
3. Paste the entire JSON file content
4. In your CI workflow, write it to a file:
   ```yaml
   - name: Setup Firebase Admin SDK
     run: echo '${{ secrets.FIREBASE_ADMIN_SDK_KEY }}' > firebase-admin-sdk.json
   ```

## Security Checklist
- [x] Files are in `.gitignore`
- [x] Files are NOT tracked by git (`git ls-files` confirms)
- [ ] Team members have their own copies stored securely
- [ ] CI/CD configured with secrets (if applicable)
- [ ] Old versions in git history are noted (but not removed per project decision)

## Getting New Keys
If you need to generate new Firebase Admin SDK keys:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `bhl-obe`
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Save the JSON file securely (do NOT commit to git)
6. Update the filename in your local environment

## Questions?
See `SETUP_GUIDE.md` for complete project setup instructions.
