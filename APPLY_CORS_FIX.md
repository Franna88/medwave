# Fix Image Loading Issue (CORS)

## Problem
Images from Firebase Storage are not loading in the admin panel on Flutter Web due to CORS restrictions.

## Solution
Apply CORS configuration to your Firebase Storage bucket.

## Steps

### 1. Install Google Cloud SDK (if not already installed)
```bash
# macOS
brew install google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install
```

### 2. Authenticate with Google Cloud
```bash
gcloud auth login
```

### 3. Set your project
```bash
gcloud config set project medx-ai
```

### 4. Apply CORS configuration
```bash
gsutil cors set cors.json gs://medx-ai.firebasestorage.app
```

### 5. Verify CORS configuration
```bash
gsutil cors get gs://medx-ai.firebasestorage.app
```

## Expected Output
You should see the CORS configuration applied:
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600,
    "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"]
  }
]
```

## After Applying
1. Restart your Flutter web app
2. Clear browser cache (Cmd+Shift+R on Chrome)
3. Images should now load correctly in the admin panel

## Note
The `cors.json` file has already been created in the project root with the correct configuration.

