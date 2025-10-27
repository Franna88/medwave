# Facebook Ads API Integration - Testing Guide

## Quick Testing Checklist

### Prerequisites
- ✅ App running in development/web mode
- ✅ Access to Superadmin Portal
- ✅ Facebook Ad Account has active campaigns
- ✅ Internet connection available

---

## Step-by-Step Testing

### 1. Initial Load Test

**Steps:**
1. Launch the app: `flutter run -d chrome` or `flutter run`
2. Log in to Superadmin Portal
3. Navigate to **Advertisement Performance** screen
4. Look at **"Add Performance Cost (Detailed View)"** section

**Expected Results:**
- ✅ Page loads without errors
- ✅ Facebook sync status badge appears if data fetched
- ✅ Refresh button (🔄) visible in header
- ✅ Loading spinner appears briefly during fetch

**Check Console Output:**
Look for these messages:
```
🌐 Fetching Facebook campaigns from API...
✅ Fetched X Facebook campaigns
   • Campaign Name: $XXX spend, XXX impressions
```

---

### 2. Facebook Data Display Test

**What to Check:**

#### Header Area:
- [ ] **Sync Status Badge** appears with "FB synced Xm ago"
- [ ] Badge has blue background with cloud icon
- [ ] Time updates correctly

#### Ad Cards:
For each ad that has Facebook data:
- [ ] **"Spend (FB)"** label shows in BLUE (instead of "Budget" in black)
- [ ] Spend amount matches Facebook data
- [ ] Second row appears with Facebook metrics section

#### Facebook Metrics Section:
- [ ] Blue-tinted background with Facebook icon
- [ ] Displays: **Impressions**, **Reach**, **Clicks**
- [ ] Displays: **CPM**, **CPC**, **CTR**
- [ ] Values are numbers (not all dashes)

---

### 3. Manual Refresh Test

**Steps:**
1. Note the current "synced Xm ago" timestamp
2. Click the **refresh button** (🔄) in header
3. Wait for loading spinner

**Expected Results:**
- ✅ Loading spinner appears
- ✅ Timestamp updates to "synced just now"
- ✅ Data refreshes (may or may not change if no new ad activity)
- ✅ No error messages in console

---

### 4. Data Accuracy Test

**Compare Facebook Dashboard to App:**

1. Open [Facebook Ads Manager](https://adsmanager.facebook.com/)
2. Select MedWave Master Ads Account
3. View last 30 days data
4. Compare to app display:

| Metric | Facebook Ads Manager | MedWave App | Match? |
|--------|---------------------|-------------|--------|
| Spend | $___.__ | R___.__ | ☐ |
| Impressions | _____ | _____ | ☐ |
| Clicks | _____ | _____ | ☐ |
| CPM | $___.__ | $___.__ | ☐ |
| CPC | $___.__ | $___.__ | ☐ |
| CTR | __.__% | __.__% | ☐ |

**Note:** Currency conversion may affect spend display ($ vs R)

---

### 5. Campaign Matching Test

**Purpose:** Verify Facebook campaigns link to GHL campaigns

**Steps:**
1. In Facebook Ads Manager, note the Campaign IDs and names
2. In MedWave app, check which campaigns show "Spend (FB)"
3. Verify they match by name

**Check:**
- [ ] Campaigns with matching `campaignKey` show Facebook data
- [ ] Campaigns without match show "Budget" (not "Spend (FB)")
- [ ] Campaign names match between Facebook and app

**Debugging:**
If no matches:
- Check `campaignKey` field in Firestore
- Verify it contains Facebook Campaign ID
- Check console for matching errors

---

### 6. Calculation Verification Test

**For an ad WITH Facebook data:**

**Manual Calculation:**
1. Note: **Spend (FB)** = `$spend_value`
2. Note: **Leads** = `X`
3. Calculate: CPL = spend / leads = `$_____`
4. Compare to displayed CPL

**Check:**
- [ ] CPL = Spend / Leads
- [ ] CPB = Spend / Bookings
- [ ] CPA = Spend / Deposits
- [ ] Calculations use Facebook spend (blue "Spend (FB)") not manual budget

---

### 7. Error Handling Test

**Test A: Network Disconnect**
1. Disconnect internet
2. Click refresh button
3. Expected: Falls back to cached data, shows error in console

**Test B: Invalid Token**
1. Temporarily modify access token in `facebook_ads_service.dart`
2. Click refresh
3. Expected: Error in console, cached data still displays

**Test C: API Rate Limit (Hard to Test)**
- If you see "rate limit" errors, cache should prevent constant retries

---

### 8. Performance Test

**Metrics to Monitor:**

**Load Time:**
- [ ] Initial page load < 3 seconds
- [ ] Facebook data fetch < 2 seconds (first time)
- [ ] Subsequent loads < 1 second (cached)

**Responsiveness:**
- [ ] No UI freezing during data fetch
- [ ] Refresh button doesn't hang
- [ ] Scroll works smoothly with multiple ads

---

### 9. Edge Cases Test

**Test Different Scenarios:**

#### Scenario A: No Facebook Data
1. Create a test campaign in GHL
2. Don't add Facebook Campaign ID to `campaignKey`
3. Expected: Shows "Budget" (not "Spend (FB)"), no FB metrics section

#### Scenario B: Facebook Data Without GHL Data
- If Facebook campaign has no GHL tracking
- Should still pull spend data but may not calculate CPL/CPB

#### Scenario C: Multiple Campaigns
- Test with 3+ campaigns
- Verify each shows correct data
- No cross-contamination of metrics

---

## Console Log Checklist

**During successful operation, you should see:**

```
🔄 Performance Cost Provider: Initializing...
✅ Performance Cost Provider: Initialized successfully
🌐 Fetching Facebook campaigns from API...
✅ Fetched 3 Facebook campaigns
   • MedWave - Obesity Campaign: $120.50 spend, 15234 impressions
   • MedWave - Physiotherapy Campaign: $85.30 spend, 9821 impressions
   • MedWave - General Campaign: $200.00 spend, 28934 impressions
✅ Facebook Ads data fetched successfully
   - Campaigns: 3
   - Total ads: 12
🔄 Merging ad costs with cumulative data and Facebook data...
✅ Merged 12 ad performance entries
```

**Error Messages (Handle Gracefully):**
```
❌ Error fetching Facebook campaigns: [error details]
⚠️ Returning stale cached data due to error
```

---

## Known Issues / Limitations

### 1. Campaign Matching
**Issue:** Requires `campaignKey` to exactly match Facebook Campaign ID

**Workaround:** 
- Manually update `campaignKey` in Firestore
- Or create mapping UI (future enhancement)

### 2. Currency Display
**Issue:** Facebook returns $ but app displays R

**Note:** This is expected - conversion may be needed

### 3. Date Range
**Current:** Fixed to last 30 days

**Future:** Add date picker to UI

### 4. Cache Timing
**Current:** 5-minute cache

**Behavior:** Refreshing within 5 minutes returns cached data unless "force refresh" clicked

---

## Troubleshooting

### Problem: No "Spend (FB)" Showing

**Check:**
1. Open browser DevTools > Console
2. Look for Facebook API errors
3. Check network tab for API calls to `graph.facebook.com`

**Solution:**
```dart
// In facebook_ads_service.dart
// Verify access token is valid:
static const String _accessToken = 'EAAc9pw8rgA0BPzX...';
```

### Problem: Wrong Campaign Data

**Check:**
1. Open Firestore console
2. Navigate to `adPerformanceCosts` collection
3. Check `campaignKey` field value
4. Compare to Facebook Campaign ID

**Solution:**
Update `campaignKey` to match Facebook Campaign ID exactly

### Problem: "Feature Unavailable" Error

**This means:** Facebook Login isn't fully propagated

**Solution:**
- Wait 24-48 hours
- Verify Facebook Login for Business is added
- Check app is in Live mode

---

## Success Criteria

### ✅ Integration Working If:
1. Facebook sync status badge shows recent sync time
2. At least one campaign shows "Spend (FB)" in blue
3. Facebook metrics section displays with real numbers
4. CPL/CPB/CPA calculations use Facebook spend
5. Manual refresh updates timestamp
6. No console errors during normal operation

### ⚠️ Needs Investigation If:
1. All campaigns show "Budget" (not "Spend (FB)")
2. Facebook metrics always show dashes (---)
3. Sync timestamp never updates
4. Console shows persistent API errors
5. Refresh button doesn't trigger loading spinner

---

## Test Data Record

**Test Date:** _________________  
**Tester:** _________________

**Results:**

| Test | Pass | Fail | Notes |
|------|------|------|-------|
| Initial load | ☐ | ☐ | |
| Facebook data display | ☐ | ☐ | |
| Manual refresh | ☐ | ☐ | |
| Data accuracy | ☐ | ☐ | |
| Campaign matching | ☐ | ☐ | |
| Calculations | ☐ | ☐ | |
| Error handling | ☐ | ☐ | |
| Performance | ☐ | ☐ | |

**Overall Status:** ☐ Pass ☐ Fail

**Issues Found:**
1. _________________
2. _________________
3. _________________

---

## Next Steps After Testing

### If All Tests Pass:
1. ✅ Mark integration as production-ready
2. Deploy to live environment
3. Monitor API usage for 7 days
4. Consider requesting Advanced Access after 1500+ calls

### If Tests Fail:
1. Document specific failures
2. Check console errors
3. Verify Facebook app configuration
4. Review campaign matching logic
5. Re-test after fixes

---

**Testing Guide Version:** 1.0  
**Last Updated:** October 27, 2025


