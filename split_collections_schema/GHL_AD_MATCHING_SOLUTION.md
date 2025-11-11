# GHL Opportunity to Facebook Ad Matching - Solution Documentation

**Date:** November 11, 2025  
**Project:** MedWave Split Collections Migration  
**Issue:** Accurate matching of GHL opportunities to Facebook Ad IDs

---

## Problem Discovery

### Initial Issue
After migrating to the `advertData` collection structure, we experienced:
- **Loading times increased from instant to 3-5 minutes**
- **Inaccurate GHL opportunity attribution** - opportunities were being matched to multiple ads
- **Data duplication** - the same opportunity's metrics were counted across multiple ads

### Root Cause Investigation
We discovered that the GHL Opportunities API and Contacts API do **NOT** consistently provide the `adId` for Facebook Lead Forms:

1. **Direct Form Submissions** (website forms): ✅ `adId` is present in `attributionSource`
2. **Facebook Lead Forms**: ❌ `adId` is `null` in `attributionSource`, only `adSetId` and `campaignId` are provided

This meant that ~700+ opportunities from Facebook Lead Forms could not be accurately matched to specific ads.

---

## Solution: GHL Forms Submissions API

### Discovery
After extensive investigation, we found that the **GHL Forms Submissions API** contains the complete attribution data, including `adId`, even for Facebook Lead Forms.

### API Endpoint
```
GET https://services.leadconnectorhq.com/forms/submissions
```

### Parameters
- `locationId`: Your GHL location ID
- `startAt`: Start date (YYYY-MM-DD)
- `endAt`: End date (YYYY-MM-DD)
- `limit`: 100 (max per page)

### Where the Ad ID is Located
The Ad ID can be found in **two places** within the form submission response:

1. **`others.lastAttributionSource.adId`**
   ```json
   {
     "others": {
       "lastAttributionSource": {
         "adId": "120235560268260335",
         "adSetId": "120235556204830335",
         "campaignId": "120235556205010335"
       }
     }
   }
   ```

2. **`others.eventData.url_params.ad_id`**
   ```json
   {
     "others": {
       "eventData": {
         "url_params": {
           "ad_id": "120235560268260335",
           "adset_id": "120235556204830335",
           "campaign_id": "120235556205010335"
         }
       }
     }
   }
   ```

---

## Implementation

### Script: `update_ghl_with_form_submissions.py`

This script performs the following steps:

#### STEP 1: Fetch Form Submissions
- Fetches all form submissions for the last 120 days (4 months)
- Extracts `adId`, `adSetId`, and `campaignId` from each submission
- Creates a `contact_id` → `ad_id` mapping

#### STEP 2: Load Ads Collection
- Loads all ads from the `ads` collection
- Validates that extracted Ad IDs exist in our database

#### STEP 3: Fetch GHL Opportunities
- Fetches all opportunities from GHL API
- Filters to relevant pipelines (Andries & Davide)

#### STEP 4: Update ghlOpportunities
- For each opportunity with a `contactId`:
  - Looks up the contact in the form submissions mapping
  - Updates the `ghlOpportunities` document with:
    - `assignedAdId`
    - `assignmentMethod: 'form_submission_ad_id'`
    - `adSetId`
    - `adSetName`
    - `campaignId`
    - `campaignName`

#### STEP 5: Cleanup
- Deletes the `ghlOpportunityMapping` collection (no longer needed)
- All data is now stored directly in `ghlOpportunities`

---

## Results

### Before Fix
- **Form submissions fetched:** 100 (only 1 page due to pagination bug)
- **Contacts with Ad IDs:** 94
- **Opportunities updated:** 40
- **Unmatched opportunities:** 1,894

### After Fix (All Pages)
- **Form submissions fetched:** 3,353
- **Contacts with Ad IDs:** 1,718
- **Opportunities updated:** 921
- **Unmatched opportunities:** 341

### By Date Range
- **Last 2 months (Oct-Nov 2025):** Only **7 unmatched** ✅
- **September 2025:** 4 unmatched
- **August 2025:** 141 unmatched
- **July 2025:** 153 unmatched
- **June 2025:** 40 unmatched

### Match Rate
- **Recent data (last 2 months): 99.3%** (960 matched out of 967 total)
- **Overall: 73.8%** (960 matched out of 1,301 total)

---

## Key Learnings

### 1. Pagination Bug
The initial script only fetched 1 page (100 submissions) because it relied on the API's `total` field, which was unreliable. 

**Fix:** Check if `len(submissions) < 100` to determine the last page.

### 2. Facebook Lead Forms Limitation
Facebook's native Lead Form integration with GHL does **NOT** pass `ad_id` in the webhook payload to the Contacts API, but it **IS** captured in the Forms Submissions API.

### 3. Date Range Matters
The Forms Submissions API has a practical limit. Fetching 120 days (4 months) of data is reliable, but older data may require multiple requests or may not be available.

### 4. Multiple Data Sources Required
To get complete attribution data, you need to query:
- ❌ **Opportunities API** - Missing `adId` for Facebook Lead Forms
- ❌ **Contacts API** - `adId` is `null` for Facebook Lead Forms
- ✅ **Forms Submissions API** - Contains complete attribution data

---

## Data Structure

### ghlOpportunities Collection
Each document now contains:
```javascript
{
  id: "h3IE85OPsqwuBK2dPgmU",
  name: "Yolandi Nel",
  contactId: "Itp8xcPYfTXFyWDp1pms",
  assignedAdId: "120235560268260335",  // ← From Forms Submissions API
  assignmentMethod: "form_submission_ad_id",
  adSetId: "120235556204830335",
  adSetName: "Interests - Healthcare and medical services (DDM)",
  campaignId: "120235556205010335",
  campaignName: "05112025 - ABOLEADFORMZA (DDM) - Targeted Audiences",
  pipelineId: "XeAGJWRnUGJ5tuhXam2g",
  status: "open",
  monetaryValue: 0,
  createdAt: "2025-11-10T08:53:25.953Z",
  updatedAt: "2025-11-10T08:56:17.233Z"
}
```

---

## Remaining Issues

### 7 Unmatched Opportunities (Last 2 Months)
All 7 recent unmatched opportunities have **NO attribution data** and are named "Unknown":

| Opportunity ID | Created Date | Contact ID | Name |
|---|---|---|---|
| 9pSST9D8T9sXbc0UE3TE | 2025-10-31 | 9DG8oh9slOEO7k1a8Ir5 | Unknown |
| S7EIEHgGOXveSOc6oI6J | 2025-10-10 | gphYPLIjjGwtvCguNX4s | Unknown |
| hkDLuzVBrtWvg8k6llPu | 2025-10-02 | 9QJRw96QpLuN1So19EOx | Unknown |
| 70fAPccPEMYz573hjpI2 | 2025-09-29 | VvlK2U5zVhv13E708zD6 | Unknown |
| dLujAaES4Pn2ZsBhV9QS | 2025-09-25 | EyL3rgzKUJA9wBSMUzrV | Unknown |
| tXDpjz17dl4bRRJKNpbV | 2025-09-24 | vbpyproGe7BfSmjMYdeg | Unknown |
| rlNpH8mOv2ijTJd8UD3P | 2025-09-16 | 2xcb7DLXQefmhgyb4PFK | Unknown |

**Likely Causes:**
1. **Test/Junk Data:** All have "Unknown" as name, suggesting they may be test entries
2. **Manual Entries:** Created manually without form submission
3. **Incomplete Data:** Created before attribution tracking was properly configured
4. **API Access Issue:** Investigation script returned 401 errors (expired API key)

**Next Steps:**
1. Refresh GHL API key and re-run `investigate_7_unmatched.py`
2. Check GHL UI to see if these are real opportunities or test data
3. If test data, consider deleting them from `ghlOpportunities` collection
4. If real opportunities without forms, they should remain unmatched (legitimate non-Facebook leads)

**Investigation Script:** `investigate_7_unmatched.py`

### 294 Older Unmatched (June-August 2025)
These are likely outside the 120-day window of form submissions we fetched. Options:
1. Extend the date range to 180 days (6 months)
2. Accept that older data may not be matchable
3. Implement a one-time historical backfill

---

## Maintenance

### Regular Updates
The `update_ghl_with_form_submissions.py` script should be run:
- **After initial migration** (done ✅)
- **Periodically** (weekly/monthly) to catch any new opportunities that weren't matched in real-time
- **When investigating discrepancies** in ad performance data

### Real-Time Matching
For ongoing operations, the Cloud Functions should handle real-time matching:
- `opportunityHistoryService.js` - Matches new opportunities as they're created
- `opportunityMappingService.js` - Implements the multi-level matching strategy

However, the Forms Submissions API provides the **most accurate** Ad IDs and should be considered the source of truth.

---

## Future Improvements

1. **Extend Date Range:** Fetch form submissions for 180+ days to match older opportunities
2. **Automated Backfill:** Schedule a Cloud Function to periodically backfill unmatched opportunities
3. **Alert System:** Notify when unmatched opportunities exceed a threshold
4. **Form Validation:** Ensure all forms capture UTM parameters correctly
5. **API Monitoring:** Track when GHL API changes affect attribution data availability

---

## Technical Notes

### API Rate Limits
- GHL API: ~120 requests/minute
- Form Submissions: Paginated at 100 per page
- Script includes 0.2s delay between requests

### Error Handling
- Graceful handling of missing fields
- Fallback to multiple data sources (`lastAttributionSource` → `eventData.url_params`)
- Validation against `ads` collection before assignment

### Data Integrity
- No duplicates: Each opportunity is assigned to exactly one ad
- Audit trail: `assignmentMethod` field tracks how the match was made
- Reversible: Original opportunity data is preserved

---

## Contact
For questions or issues, refer to:
- Main migration plan: `NEW_DATA_STRUCTURE.txt`
- Migration script: `migrate_to_split_collections.py`
- Update script: `update_ghl_with_form_submissions.py`
- Investigation tools: `investigate_7_unmatched.py`, `analyze_unmatched_opportunities.py`

