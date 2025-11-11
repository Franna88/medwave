# GHL AdvertData Sync - Instructions

## Overview

This implementation syncs GHL opportunities directly from the GHL API to the `advertData` collection in Firebase. It extracts **all 5 UTM parameters** and matches opportunities to Facebook ads using the `h_ad_id` parameter.

## UTM Structure

The system extracts these 5 UTM parameters from GHL:

```
utm_source={{campaign.name}}      → Campaign Name
utm_medium={{adset.name}}         → Ad Set Name
utm_campaign={{ad.name}}          → Ad Name
fbc_id={{adset.id}}              → Ad Set ID
h_ad_id={{ad.id}}                → Facebook Ad ID (PRIMARY MATCHING KEY)
```

## Data Flow

```
GHL API → Extract UTM Params → Match by h_ad_id → Group by Week → Write to advertData
```

**IMPORTANT**: Data is fetched ONLY from GHL API, NOT from any Firebase collections.

## Scripts

### 1. Test Script (Run First)
**File**: `functions/testGHLSync.js`

Tests the sync logic without writing data:
- Verifies all 5 UTM parameters are extracted
- Checks ad matching with advertData collection
- Tests weekly grouping logic

```bash
cd /Users/mac/dev/medwave
node functions/testGHLSync.js
```

**Expected Output**:
- ✅ All 5 UTM parameters extracted from sample opportunities
- ✅ Ads found in advertData collection
- ✅ Weekly grouping works correctly

### 2. Dry Run Sync (Recommended)
**File**: `functions/syncGHLToAdvertData.js`

Processes all opportunities but doesn't write to Firebase:

```bash
node functions/syncGHLToAdvertData.js --dry-run
```

**What it does**:
- Fetches ALL opportunities from GHL API (last 6 months)
- Extracts all 5 UTM parameters
- Groups by Facebook Ad ID and week
- Shows what would be written (but doesn't write)

**Review the output**:
- Check UTM parameter completeness statistics
- Verify sample UTM data looks correct
- Confirm number of ads and weeks to be updated

### 3. Full Sync (Production)
**File**: `functions/syncGHLToAdvertData.js`

Runs the full sync and writes data to Firebase:

```bash
node functions/syncGHLToAdvertData.js
```

**What it does**:
- Fetches ALL opportunities from GHL API (last 6 months)
- Extracts all 5 UTM parameters
- Matches opportunities by h_ad_id to advertData ads
- Groups by week (Monday-Sunday)
- Writes weekly metrics to `advertData/{adId}/ghlWeekly/{weekId}`
- Updates `lastGHLSync` timestamp on each ad

**Duration**: 5-15 minutes depending on number of opportunities

### 4. Verification Script
**File**: `functions/verifyGHLAdvertDataSync.js`

Verifies the sync results:

```bash
node functions/verifyGHLAdvertDataSync.js
```

**What it checks**:
- How many opportunities have h_ad_id
- How many ads in advertData have GHL data
- UTM parameter completeness statistics
- Sample weekly breakdown for verification

## Cloud Function API Endpoint

### Trigger Sync via API
**Endpoint**: `POST /api/advertdata/sync-ghl`

```bash
curl -X POST https://us-central1-medx-ai.cloudfunctions.net/api/advertdata/sync-ghl
```

**Response**:
```json
{
  "success": true,
  "message": "GHL data synced to advertData successfully",
  "stats": {
    "totalOpportunities": 1234,
    "withHAdId": 856,
    "withAllUTMParams": 820,
    "adsUpdated": 145,
    "weeksWritten": 892,
    "errors": 0
  },
  "timestamp": "2025-11-09T..."
}
```

## Recommended Workflow

### First Time Setup

1. **Test the extraction logic**:
   ```bash
   node functions/testGHLSync.js
   ```
   - Verify all 5 UTM params are extracted
   - Check sample opportunities look correct

2. **Run dry-run to preview**:
   ```bash
   node functions/syncGHLToAdvertData.js --dry-run
   ```
   - Review UTM completeness statistics
   - Check how many ads will be updated
   - Verify sample data looks correct

3. **Run full sync**:
   ```bash
   node functions/syncGHLToAdvertData.js
   ```
   - Wait for completion (5-15 minutes)
   - Review final statistics

4. **Verify results**:
   ```bash
   node functions/verifyGHLAdvertDataSync.js
   ```
   - Check match rate
   - Review sample weekly data
   - Verify totals look correct

### Regular Updates

Run the full sync periodically to update with new opportunities:

```bash
node functions/syncGHLToAdvertData.js
```

Or trigger via API endpoint for automated updates.

## Monetary Value Extraction

The `cashAmount` field is extracted from GHL opportunities in the following priority order:

1. **`opportunity.monetaryValue`** - Standard GHL opportunity value field (primary source)
2. **Custom fields from contact** - `Contract Value` or `Cash Collected` fields
3. **Default R1500** - Only applied for deposits/cash collected stages if no value found

This ensures we capture the actual monetary value from the opportunity as set in GHL Contacts.

## Data Structure

### Firebase Structure

```
advertData/
  {facebookAdId}/
    campaignId: string
    campaignName: string
    adSetId: string
    adSetName: string
    adId: string
    adName: string
    lastGHLSync: timestamp
    
    ghlWeekly/
      {weekId}/  (e.g., "2025-11-04_2025-11-10")
        leads: number
        bookedAppointments: number
        deposits: number
        cashCollected: number
        cashAmount: number
        lastUpdated: timestamp
```

### Week ID Format

Weeks run Monday-Sunday:
- Format: `YYYY-MM-DD_YYYY-MM-DD`
- Example: `2025-11-04_2025-11-10`

## Troubleshooting

### No opportunities with h_ad_id

**Issue**: All opportunities are skipped because h_ad_id is missing.

**Solution**:
1. Check that UTM parameters are configured in GHL
2. Verify the UTM structure matches:
   ```
   utm_source={{campaign.name}}&utm_medium={{adset.name}}&utm_campaign={{ad.name}}&fbc_id={{adset.id}}&h_ad_id={{ad.id}}
   ```
3. Check a sample opportunity in GHL to see what attribution data exists

### Ads not found in advertData

**Issue**: Opportunities have h_ad_id but ads don't exist in advertData.

**Solution**:
1. Run Facebook sync first:
   ```bash
   node functions/populateAdvertData.js
   ```
2. Verify ads exist in Firebase Console: `advertData` collection

### Low match rate

**Issue**: Many opportunities don't match to ads.

**Solution**:
1. Check that h_ad_id values match Facebook Ad IDs
2. Verify Facebook ads are synced to advertData
3. Review sample opportunities to see UTM data quality

## Statistics to Monitor

### UTM Completeness
- **Target**: >80% of opportunities should have h_ad_id
- **Target**: >70% should have all 5 UTM parameters

### Match Rate
- **Target**: >80% of opportunities with h_ad_id should match ads in advertData
- **Target**: Each ad should have multiple weeks of data

### Data Quality
- Weekly totals should be reasonable (not all zeros)
- Cash amounts should match expected values (R1500 default)
- No duplicate counting of opportunities

## Support

If you encounter issues:
1. Check the console output for error messages
2. Run the test script to isolate the problem
3. Review sample opportunities in GHL to verify UTM data
4. Check Firebase Console to verify data structure

## Files Created

- `functions/syncGHLToAdvertData.js` - Main sync script
- `functions/verifyGHLAdvertDataSync.js` - Verification script
- `functions/testGHLSync.js` - Test suite
- `functions/index.js` - Added API endpoint `/api/advertdata/sync-ghl`

