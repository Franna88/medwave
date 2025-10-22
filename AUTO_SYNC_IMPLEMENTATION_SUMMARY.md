# Auto-Sync Firebase Implementation Summary

## Overview
Successfully implemented automatic background syncing of GoHighLevel opportunity data to Firebase every 2 minutes using Firebase Cloud Functions scheduled tasks. Made Cumulative mode the default experience while keeping Snapshot mode available for development/troubleshooting.

## What Was Implemented

### 1. Scheduled Cloud Function (Backend)

**File: `functions/index.js`**

- Added `onSchedule` import from `firebase-functions/v2/scheduler`
- Created new scheduled function `autoSyncGoHighLevel` that runs every 2 minutes
- Function independently fetches opportunities from both Altus and Andries pipelines
- Implements pagination to handle all opportunities (100 per page)
- Syncs data to Firebase `opportunityStageHistory` collection
- Runs completely independently of user logins or app state
- Logs detailed sync statistics for monitoring

**Key Features:**
- Automatic execution every 2 minutes
- No user authentication required (backend service)
- Handles up to 1000s of opportunities with pagination
- Intelligent stage change detection (only stores new/changed records)
- Comprehensive error logging for debugging

### 2. Default to Cumulative Mode (Frontend)

**File: `lib/providers/gohighlevel_provider.dart`**

Changed line 40:
```dart
// Before
String _viewMode = 'snapshot';

// After  
String _viewMode = 'cumulative'; // Default to cumulative mode
```

**Impact:**
- App now starts in Cumulative mode by default
- All analytics display cumulative metrics from Firebase
- Initialization loads cumulative data automatically

### 3. Hidden Snapshot Toggle (UI)

**File: `lib/screens/admin/admin_advert_performance_screen.dart`**

**Lines 163-221:** Wrapped view mode toggle in conditional visibility:
```dart
if (false) // Change to true to show toggle for admin testing
  Row(
    children: [
      // ... toggle UI ...
    ],
  ),
```

**Lines 2173:** Removed view mode indicator badge:
- Removed "Cumulative/Snapshot" badge
- Kept "Live Data" badge

**Impact:**
- Toggle is hidden from regular users
- Can be re-enabled by changing `if (false)` to `if (true)`
- Cleaner UI with cumulative as the assumed default

### 4. Manual Sync Button Enhancement

**File: `lib/screens/admin/admin_advert_performance_screen.dart`**

**Lines 129-153:** Upgraded from IconButton to ElevatedButton:
```dart
ElevatedButton.icon(
  onPressed: ghlProvider.isSyncing ? null : () => ghlProvider.syncOpportunityHistory(),
  icon: ghlProvider.isSyncing
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : const Icon(Icons.sync, size: 18),
  label: Text(ghlProvider.isSyncing ? 'Syncing...' : 'Manual Sync'),
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.secondaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
),
```

**Impact:**
- More prominent and descriptive button
- Shows "Manual Sync" label to clarify purpose
- Loading state shows "Syncing..." with spinner
- Better UX with disabled state during sync

## How It Works

### Background Sync Flow

1. **Every 2 Minutes (Automatic):**
   - Firebase Cloud Scheduler triggers `autoSyncGoHighLevel` function
   - Function fetches pipeline configurations and user data
   - Fetches all opportunities from both pipelines (with pagination)
   - Compares current stage with last known stage in Firestore
   - Only stores new opportunities or stage changes with campaign attribution
   - Updates `opportunityStageHistory` collection

2. **App Display (Real-time):**
   - App loads cumulative data from Firebase by default
   - Displays metrics calculated from `opportunityStageHistory` records
   - Auto-refresh timer (5 minutes) reloads data from Firebase
   - Manual sync button triggers immediate backend sync + refresh

3. **Ad Performance Cost Tracking:**
   - Budget entries stored in `adPerformanceCosts` collection
   - Real-time merging with latest cumulative data from Firebase
   - Calculations (CPL, CPB, CPA, Profit) update automatically
   - No changes needed - existing implementation already uses cumulative data

## Data Flow Diagram

```
GoHighLevel API
       ↓ (Every 2 minutes - Automatic)
Firebase Cloud Function (autoSyncGoHighLevel)
       ↓
Firestore (opportunityStageHistory)
       ↓ (Read on app load/refresh)
Flutter App (Cumulative Mode - Default)
       ↓
Display: Metrics, Charts, Ad Performance Costs
```

## Deployment

### To Deploy the Scheduled Function:

```bash
cd /Users/mac/dev/medwave
firebase deploy --only functions:autoSyncGoHighLevel
```

### Verify Deployment:

1. Check Firebase Console → Functions → autoSyncGoHighLevel
2. Monitor logs: `firebase functions:log --only autoSyncGoHighLevel`
3. Verify data in Firestore → opportunityStageHistory collection
4. Check timestamps on documents (should update every 2 minutes)

## Testing Checklist

- [x] Scheduled function code added to functions/index.js
- [x] Default view mode changed to 'cumulative' in provider
- [x] Snapshot toggle hidden in UI (but accessible via flag)
- [x] View mode indicator badge removed
- [x] Manual sync button updated with better label
- [ ] Deploy scheduled function to Firebase
- [ ] Monitor function logs for successful execution
- [ ] Verify Firestore updates every 2 minutes
- [ ] Confirm app displays cumulative data by default
- [ ] Test manual sync still works
- [ ] Verify Ad Performance Cost calculations update automatically

## Monitoring & Maintenance

### Check Function Execution:
```bash
firebase functions:log --only autoSyncGoHighLevel --limit 10
```

### View Sync Statistics:
Look for logs with format:
```
✅ Auto-sync completed: { synced: X, skipped: Y, errors: Z }
```

### Troubleshooting:

**If sync fails:**
1. Check GHL API key is configured: `firebase functions:config:get ghl.api_key`
2. Verify GoHighLevel API access (rate limits, permissions)
3. Check Firebase Functions logs for error details

**If data seems stale:**
1. Verify scheduled function is deployed and active
2. Check Firestore for recent timestamp updates
3. Ensure no errors in function logs

**If app shows wrong data:**
1. Verify viewMode is 'cumulative' (check provider initialization)
2. Clear app cache and restart
3. Check that cumulative API endpoint is being called

## Key Benefits

✅ **Always Fresh Data:** Firebase updates every 2 minutes automatically
✅ **No Manual Sync Required:** Users see current data without intervention
✅ **Independent of User Activity:** Syncs even when no one is logged in
✅ **Cumulative by Default:** Proper historical tracking is the primary experience
✅ **Ad Performance Tracking:** Budget calculations update automatically
✅ **Scalable:** Handles pagination for large datasets
✅ **Intelligent Storage:** Only stores new/changed opportunities (efficient)
✅ **Monitoring Ready:** Comprehensive logging for troubleshooting

## Migration Notes

### What Changed for Users:
- App now opens in Cumulative mode (shows historical metrics)
- Snapshot/Cumulative toggle is hidden (cleaner UI)
- Manual sync button is more prominent with clearer label
- Data updates automatically in background (no action needed)

### What Stayed the Same:
- Ad Performance Cost tracking works identically
- All calculations (CPL, CPB, CPA, Profit) still accurate
- Manual refresh button still available
- Timeframe filters work the same way
- Manual sync still available for immediate updates

### For Developers:
- To re-enable Snapshot toggle: Change `if (false)` to `if (true)` on line 164 of admin_advert_performance_screen.dart
- To adjust sync interval: Change `'every 2 minutes'` in functions/index.js (line 963)
- To add more pipelines: Add pipeline IDs to scheduled function

## Future Enhancements

**Possible Improvements:**
1. Add sync status indicator in UI (last sync time from scheduled function)
2. Create admin panel to manually trigger sync
3. Add webhook fallback for real-time updates between scheduled syncs
4. Implement sync health monitoring/alerting
5. Add ability to adjust sync interval via Firebase Remote Config
6. Create analytics dashboard for sync performance

## Files Modified

1. **functions/index.js** - Added scheduled function
2. **lib/providers/gohighlevel_provider.dart** - Changed default view mode
3. **lib/screens/admin/admin_advert_performance_screen.dart** - Hidden toggle, updated sync button

## Dependencies

- `firebase-functions` v5.0.0 (already installed)
- Firebase Cloud Scheduler (enabled automatically)
- Firestore database (already configured)
- GoHighLevel API access (already configured)

---

**Implementation Date:** October 22, 2025
**Status:** Ready for deployment
**Next Step:** Deploy scheduled function with `firebase deploy --only functions:autoSyncGoHighLevel`

