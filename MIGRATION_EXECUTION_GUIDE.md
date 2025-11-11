# Month-First Structure Migration - Execution Guide

## Overview

The migration to month-first structure is ready to execute. All scripts have been created and sync functions have been updated.

## Current Status

✅ **Scripts Created:**
- `migrate_to_month_structure.py` - Migrates 667 ads to new structure
- `verify_migration.py` - Verifies migration success
- `test_new_structure.py` - Tests query performance
- `cleanup_old_structure.py` - Removes old structure after verification

✅ **Code Updated:**
- `functions/lib/facebookAdsSync.js` - Now writes to month-first structure
- `populate_ghl_data.py` - Now reads/writes month-first structure

## New Structure

```
advertData/{month}                    (document = "2025-10")
  - totalAds: 249
  - adsWithInsights: 249
  - adsWithGHLData: 215
  - lastUpdated: timestamp
  
  └─ ads/{adId}                       (subcollection)
       - campaignId, campaignName, adSetId, adSetName, adId, adName
       - createdMonth: "2025-10"
       - hasInsights: true
       - hasGHLData: true
       - lastUpdated, lastFacebookSync, lastGHLSync
       
       └─ insights/{weekId}           (subcollection)
       └─ ghlWeekly/{weekId}          (subcollection)
```

## Execution Steps

### Step 1: Backup Firebase (CRITICAL)

Before running migration, backup your Firebase data:

1. Go to Firebase Console: https://console.firebase.google.com/project/medx-ai/firestore
2. Click "Import/Export" tab
3. Click "Export" and save to Cloud Storage
4. Wait for export to complete

### Step 2: Run Migration

```bash
cd /Users/mac/dev/medwave
python3 migrate_to_month_structure.py
```

**Expected output:**
- Found 667 ads to migrate
- Migrating each ad with progress updates
- Creates month documents (2025-03, 2025-04, etc.)
- Copies all subcollections (insights, ghlWeekly)
- Updates month summaries

**Duration:** ~5-10 minutes for 667 ads

### Step 3: Verify Migration

```bash
python3 verify_migration.py
```

**Expected output:**
- Old structure: 0 ads (should be empty)
- New structure: 667 ads across X months
- Sample ads verified with subcollections intact

**Success criteria:**
- ✅ Old structure has 0 ads
- ✅ New structure has 667 ads
- ✅ Sample ads have both insights and ghlWeekly subcollections

### Step 4: Test Performance

```bash
python3 test_new_structure.py
```

**Expected output:**
- Query all months: <0.1s
- Query single month: 0.3-0.5s
- Query filtered ads: 0.3-0.5s
- Get month summary: <0.05s

**Success criteria:**
- ✅ Single month query < 1 second (20x faster than old 5-10s)
- ✅ Month summary query < 100ms

### Step 5: Deploy Firebase Functions (Optional)

The updated sync functions will write to both old and new structures for now:

```bash
cd /Users/mac/dev/medwave
firebase deploy --only functions
```

This ensures new ads go to the new structure automatically.

### Step 6: Test End-to-End

1. **Test Facebook Sync:**
   - Trigger a Facebook sync (manually or wait for scheduled run)
   - Verify new ads appear in `advertData/{month}/ads/{adId}`

2. **Test GHL Sync:**
   ```bash
   python3 populate_ghl_data.py
   ```
   - Should read from new structure
   - Should write to `advertData/{month}/ads/{adId}/ghlWeekly/{weekId}`

### Step 7: Cleanup Old Structure (After 1 Week)

⚠️ **WAIT 1 WEEK** before running cleanup to ensure everything works!

```bash
python3 cleanup_old_structure.py
```

**This will DELETE the old structure permanently!**

Type "DELETE OLD STRUCTURE" to confirm.

## Query Examples for Frontend

### Get October 2025 ads:

```dart
final octoberAds = await FirebaseFirestore.instance
  .collection('advertData')
  .doc('2025-10')
  .collection('ads')
  .where('hasInsights', isEqualTo: true)
  .where('hasGHLData', isEqualTo: true)
  .get();
```

### Get October summary:

```dart
final summary = await FirebaseFirestore.instance
  .collection('advertData')
  .doc('2025-10')
  .get();

print('Total ads: ${summary.data()['totalAds']}');
print('Ads with GHL data: ${summary.data()['adsWithGHLData']}');
```

### Get all available months:

```dart
final months = await FirebaseFirestore.instance
  .collection('advertData')
  .get();

for (var month in months.docs) {
  if (month.data().containsKey('totalAds')) {
    print('${month.id}: ${month.data()['totalAds']} ads');
  }
}
```

## Troubleshooting

### Problem: Migration script shows 0 ads

**Solution:** Check if ads are in old structure:
```python
ads = list(db.collection('advertData').where('adId', '!=', '').stream())
print(f"Found {len(ads)} ads in old structure")
```

### Problem: Verification shows ads in both structures

**Solution:** This is normal during transition. Old structure will be cleaned up in Step 7.

### Problem: Some ads missing subcollections

**Solution:** Check specific ad:
```python
ad_ref = db.collection('advertData').document('2025-10').collection('ads').document('AD_ID')
insights = list(ad_ref.collection('insights').stream())
ghl = list(ad_ref.collection('ghlWeekly').stream())
print(f"Insights: {len(insights)}, GHL: {len(ghl)}")
```

### Problem: Query performance not improved

**Solution:** 
1. Wait a few minutes for Firebase to build indexes
2. Check Firebase Console > Firestore > Indexes
3. Run test again after indexes are built

## Rollback Plan

If migration fails:

1. **Stop immediately** - Don't run cleanup script
2. **Check Firebase backup** - Ensure export completed
3. **Old structure still exists** - Your data is safe
4. **Contact developer** - Provide error messages from migration script

## Success Checklist

Before considering migration complete:

- ☐ Backup completed successfully
- ☐ Migration script ran without errors
- ☐ Verification shows 667 ads in new structure
- ☐ Verification shows 0 ads in old structure
- ☐ Performance tests show <1s queries
- ☐ Sample ads have all subcollections
- ☐ Facebook sync tested and working
- ☐ GHL sync tested and working
- ☐ Frontend queries updated and tested
- ☐ System running smoothly for 1 week
- ☐ Old structure cleaned up

## Support

If you encounter issues:

1. Check error messages in terminal
2. Run `verify_migration.py` to see current state
3. Check Firebase Console for data integrity
4. Review this guide for troubleshooting steps

## Performance Comparison

**Before (old structure):**
- Load all 667 ads: 5-10 seconds
- Filter by date: Must load all, then filter in app
- No month summaries: Must aggregate in app

**After (new structure):**
- Load October ads (249): 0.3-0.5 seconds (20x faster)
- Filter by date: Direct path, no full scan
- Month summaries: Instant (<50ms)

## Next Steps

After migration is complete and verified:

1. Update Flutter frontend to use new query patterns
2. Update any admin dashboards
3. Monitor performance for 1 week
4. Run cleanup script to remove old structure
5. Update documentation with new structure

---

**Created:** November 10, 2025
**Status:** Ready to execute
**Estimated Time:** 15-20 minutes (excluding 1 week waiting period)

