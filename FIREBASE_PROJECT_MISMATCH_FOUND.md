# 🚨 CRITICAL: Firebase Project Mismatch Discovered

## Problem Found

**Two different Firebase projects are being used:**

1. **Cloud Functions** → Deployed to `medx-ai`
   - From `.firebaserc`: `"default": "medx-ai"`
   - Facebook sync wrote 904 ads to `medx-ai` project
   
2. **Service Account Key** → Connects to `bhl-obe`
   - File: `bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json`
   - Python script reads from `bhl-obe` project
   - Flutter app likely also connects to `bhl-obe`

## Impact

- ✅ Facebook sync **succeeded** - wrote 904 ads
- ❌ Data written to **wrong project** (`medx-ai`)
- ❌ App is reading from **different project** (`bhl-obe`)
- ❌ Result: App shows empty data even though sync worked

## Evidence

```bash
# Firebase project for Cloud Functions
$ cat .firebaserc
{
  "projects": {
    "default": "medx-ai"
  }
}

# Service account project
$ cat bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json | grep project_id
  "project_id": "bhl-obe",
```

## Solution Options

### Option 1: Change Cloud Functions to use `bhl-obe` (RECOMMENDED)
**Pros:**
- Flutter app already configured for `bhl-obe`
- Service accounts already set up
- Less changes needed

**Steps:**
1. Update `.firebaserc` to use `bhl-obe` as default project
2. Redeploy Cloud Functions to `bhl-obe` project
3. Retrigger Facebook sync

### Option 2: Change Flutter app to use `medx-ai`
**Pros:**
- Cloud Functions already deployed there
- Data already exists (904 ads)

**Cons:**
- Need to update all service account keys
- Need to reconfigure Flutter app
- More complex migration

## Recommended Action

**Use Option 1** - Switch Cloud Functions to `bhl-obe`:

```bash
# 1. Update Firebase project
firebase use bhl-obe

# 2. Or if project doesn't exist in list, add it
firebase use --add

# 3. Deploy functions to correct project
firebase deploy --only functions

# 4. Trigger Facebook sync
curl -X POST https://us-central1-bhl-obe.cloudfunctions.net/api/api/facebook/sync-ads \
  -H "Content-Type: application/json" \
  -d '{"forceRefresh": true, "datePreset": "last_30d"}'
```

## Next Steps

1. Confirm which project the Flutter app uses
2. Choose the correct target project
3. Deploy/redeploy to that project
4. Verify data appears correctly

