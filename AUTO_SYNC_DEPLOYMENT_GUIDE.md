# Auto-Sync Deployment Guide - Alternative Approach

## Current Status

✅ **Frontend changes deployed successfully:**
- Cumulative mode is now the default
- Snapshot toggle is hidden
- Manual sync button updated with better label

✅ **Backend API function deployed:**
- The `/api/ghl/sync-opportunity-history` endpoint is live and working
- URL: `https://us-central1-medx-ai.cloudfunctions.net/api/ghl/sync-opportunity-history`

⚠️ **Scheduled function deployment issue:**
- Firebase CLI had issues deploying the scheduled function due to gen 1/gen 2 compatibility
- Alternative approach: Use Google Cloud Scheduler directly to call the existing API endpoint

## Alternative Setup: Google Cloud Scheduler

Since the scheduled function deployment had compatibility issues, we'll use Google Cloud Scheduler to call the existing sync endpoint every 2 minutes. This is actually a more robust approach.

### Setup Steps:

#### 1. Access Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select project: **medx-ai**
3. Navigate to: **Cloud Scheduler** (search for "Cloud Scheduler" in the top search bar)

#### 2. Create a New Scheduled Job

Click "**CREATE JOB**" and configure as follows:

**Basic Configuration:**
- **Name:** `auto-sync-gohighlevel`
- **Region:** `us-central1` (same as your functions)
- **Description:** `Automatically syncs GoHighLevel opportunity data to Firebase every 2 minutes`
- **Frequency (cron):** `*/2 * * * *` (every 2 minutes)
- **Timezone:** `Africa/Johannesburg` (or your preferred timezone)

**Configure the execution:**
- **Target type:** HTTP
- **URL:** `https://us-central1-medx-ai.cloudfunctions.net/api/ghl/sync-opportunity-history`
- **HTTP method:** POST
- **Auth header:** Add OIDC token
  - **Service account:** App Engine default service account (or create a new one)
  
**Advanced settings (Retry configuration):**
- **Max retry attempts:** 3
- **Max retry duration:** 5 minutes
- **Min/Max backoff duration:** 5s / 1 hour

Click "**CREATE**" to finish.

#### 3. Test the Job

After creating:
1. Find your job in the list
2. Click the **▶ RUN NOW** button to test it immediately
3. Check the logs to verify it worked:
   - Click on the job name
   - View "Logs" tab
   - Look for success messages

#### 4. Monitor the Job

**View Execution History:**
- Go to Cloud Scheduler → Select your job
- Click "View logs" to see all executions
- You should see entries every 2 minutes

**Check Firestore:**
- Firebase Console → Firestore Database
- Look at `opportunityStageHistory` collection
- Timestamps should update every 2 minutes

### Alternative: Simpler 5-Minute Sync

If 2-minute intervals cause too many API calls, you can change the frequency:

**Every 5 minutes:** `*/5 * * * *`
**Every 10 minutes:** `*/10 * * * *`
**Every 15 minutes:** `*/15 * * * *`

Just edit the job in Cloud Scheduler and update the "Frequency" field.

## Benefits of Cloud Scheduler Approach

✅ **More Reliable:** Direct Cloud Scheduler is more stable than Firebase scheduled functions
✅ **Better Monitoring:** Easy to view execution history and logs
✅ **Flexible:** Easy to pause, resume, or change frequency
✅ **Cost Effective:** Only pay for actual executions
✅ **No Code Changes:** Works with existing API endpoint

## Current System Behavior

### What's Working Now:

1. **Frontend (Flutter App):**
   - Opens in Cumulative mode by default ✅
   - Loads data from Firebase `opportunityStageHistory` ✅
   - Auto-refreshes every 5 minutes ✅
   - Manual sync button available ✅
   - Ad Performance Cost tracking merges with live data ✅

2. **Backend (Firebase Functions):**
   - API endpoint `/api/ghl/sync-opportunity-history` is live ✅
   - Fetches all opportunities from GoHighLevel ✅
   - Syncs to Firestore with intelligent stage tracking ✅
   - Returns sync statistics ✅

### What Needs Manual Setup:

- [ ] Create Cloud Scheduler job (see steps above)
- [ ] Test the scheduled job
- [ ] Monitor first few executions

## Verification Steps

After setting up Cloud Scheduler:

### 1. Check Cloud Scheduler
```
Go to: Cloud Console → Cloud Scheduler
Verify: Job shows "Success" status
```

### 2. Check Firestore
```
Go to: Firebase Console → Firestore → opportunityStageHistory
Verify: Documents have recent timestamps
```

### 3. Check App
```
Open: MedWave App → Admin → Advert Performance
Verify: Data is current and updates automatically
```

### 4. Check Logs
```
Go to: Cloud Console → Logging
Filter: resource.type="cloud_scheduler_job"
Verify: Executions every 2 minutes with success status
```

## Troubleshooting

### Job Fails with Authentication Error:
- Check that OIDC token auth is configured
- Verify service account has `Cloud Functions Invoker` role

### Job Succeeds but No Data Updates:
- Check Firebase Functions logs for errors
- Verify GoHighLevel API key is configured
- Test the endpoint manually: `curl -X POST [ENDPOINT_URL]`

### Too Many API Calls:
- Increase interval to 5 or 10 minutes
- Check GoHighLevel API rate limits

### Data Seems Stale:
- Verify Cloud Scheduler job is running
- Check last execution time in Cloud Scheduler
- Manually trigger sync from app to force update

## Cost Implications

**Cloud Scheduler:**
- First 3 jobs free per month
- Additional jobs: $0.10 per job per month
- This job: **FREE** (within free tier)

**Cloud Functions Executions:**
- Every 2 minutes = 720 executions per day
- Every 5 minutes = 288 executions per day
- Likely within free tier (2M invocations/month)

**GoHighLevel API:**
- Check your plan's API rate limits
- Consider increasing interval if needed

## Manual Sync Option

Users can still trigger sync manually:
1. Open MedWave App
2. Go to Admin → Advert Performance  
3. Click "Manual Sync" button
4. Wait for sync to complete

## Files Modified

1. **functions/index.js** - Removed scheduled function, kept API endpoint
2. **lib/providers/gohighlevel_provider.dart** - Default to cumulative mode
3. **lib/screens/admin/admin_advert_performance_screen.dart** - Hidden toggle, updated button

## Next Steps

1. ✅ Deploy frontend changes (already running)
2. ✅ Deploy backend API (already deployed)
3. ⏳ **ACTION REQUIRED:** Set up Cloud Scheduler job (see steps above)
4. ⏳ Test and monitor the scheduled job
5. ⏳ Verify data updates every 2 minutes

---

**Deployment Date:** October 22, 2025
**Status:** Partial deployment complete - Cloud Scheduler setup pending
**Function URL:** https://us-central1-medx-ai.cloudfunctions.net/api/ghl/sync-opportunity-history

