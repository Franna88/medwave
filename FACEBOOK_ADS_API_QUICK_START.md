# Facebook Ads API Integration - Quick Start Guide

## 🎉 Integration Complete!

Your MedWave Superadmin Portal now automatically pulls Facebook ad performance data and combines it with GoHighLevel conversion tracking for unified campaign analytics.

---

## 🚀 How to Use

### 1. View Ad Performance

**Steps:**
1. Open your Superadmin Portal
2. Navigate to **Advertisement Performance**
3. Find **"Add Performance Cost (Detailed View)"** section
4. Expand if collapsed

**What You'll See:**
- **Sync Status Badge** (blue) - Shows when Facebook data was last updated
- **Refresh Button** (🔄) - Click to manually fetch latest data
- **Ad Cards** - Each ad now shows:
  - **Spend (FB)** in blue = Using live Facebook data
  - **Facebook Metrics Row** with impressions, CPM, CPC, CTR

---

### 2. Read the Metrics

#### Main Metrics Row (Top):
- **Leads** - From GoHighLevel
- **Bookings** - From GoHighLevel  
- **Deposits** - From GoHighLevel
- **Spend (FB)** - 💙 **NEW!** Live Facebook spend data
- **CPL** - Cost per lead (now uses Facebook spend)
- **CPB** - Cost per booking (now uses Facebook spend)
- **CPA** - Cost per acquisition (now uses Facebook spend)
- **Profit** - Revenue minus Facebook spend

#### Facebook Metrics Row (Bottom - when available):
- **Impressions** - How many times ad was shown
- **Reach** - Unique people who saw ad
- **Clicks** - Total clicks on ad
- **CPM** - Cost per 1000 impressions
- **CPC** - Cost per click
- **CTR** - Click-through rate %

---

### 3. Refresh Data

**Automatic:** Data refreshes on page load (uses 5-min cache)

**Manual:**
1. Click the **refresh button** (🔄) in the header
2. Wait for loading spinner
3. Data updates to latest from Facebook

**How Often:** Cache lasts 5 minutes to respect API limits

---

## 🎯 Key Benefits

### Before (Manual Entry):
- ❌ Manually entered budget numbers
- ❌ No Facebook ad metrics
- ❌ Couldn't see CPM, CPC, impressions
- ❌ Data could be outdated

### Now (Automated):
- ✅ **Live Facebook spend** replaces manual budget
- ✅ **Real-time ad metrics** (impressions, CPM, CPC, CTR)
- ✅ **Accurate CPL/CPB/CPA** calculated from actual spend
- ✅ **One dashboard** for Facebook data + GHL conversions
- ✅ **Auto-refresh** on page load

---

## 📊 Example Display

```
┌─────────────────────────────────────────────────────────────────┐
│ Add Performance Cost (Detailed View)            [FB synced 2m ago] [🔄] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Obesity - Andries - DDM                           [Edit] [Delete] │
│  Matthys - 15102025 - ABOLEADFORMZA (DDM)                      │
│                                                                 │
│  Leads  Bookings  Deposits  Spend (FB)  CPL   CPB    CPA   Profit │
│   50      21        0       R1000      R20   R48    -     -R1000  │
│  (-)    (42.0%)   (0.0%)   (50.0%)    (2.0%)(4.8%) (0.0%) (-100%) │
│                                                                 │
│  📘 Facebook Metrics:                                           │
│     Impressions  Reach   Clicks  CPM     CPC    CTR             │
│       15234     4821     589    $16.66  $0.39  4.25%           │
└─────────────────────────────────────────────────────────────────┘
```

**Notice:**
- "Spend (FB)" in blue = Using Facebook data
- Facebook metrics section shows actual ad performance
- All calculations (CPL, CPB) use Facebook spend

---

## ⚙️ How It Works

### Behind the Scenes:

1. **On Page Load:**
   - Fetches campaigns from Facebook API
   - Matches to your GHL campaigns by ID
   - Updates spend data automatically

2. **Data Matching:**
   - Uses `campaignKey` field to link Facebook campaign to GHL campaign
   - If match found: Shows "Spend (FB)" + Facebook metrics
   - If no match: Shows "Budget" (manual entry)

3. **Caching:**
   - Caches data for 5 minutes
   - Reduces API calls
   - Click refresh to force update

---

## 🔧 Configuration

### Facebook Account:
**Currently Connected:** MedWave Master Ads Account (`act_220298027464902`)

This is the account that showed:
- $23,067.82 spend
- 1.38M impressions
- 492K reach
- 58,802 clicks

### Access Token:
**Status:** Active and working
**Stored In:** `lib/services/facebook/facebook_ads_service.dart`

**Note:** Token is currently hardcoded. For production, it should be moved to Firebase Remote Config for security.

---

## 🆘 Troubleshooting

### Problem: No Facebook Data Showing

**Check:**
1. Look for sync status badge in header
2. Check browser console for errors (F12 > Console)
3. Click refresh button to retry

**Possible Causes:**
- Access token expired (unlikely, just generated)
- Campaign IDs don't match
- Network/API error

**Solution:**
- Wait a moment and refresh
- Check that `campaignKey` in Firestore matches Facebook Campaign ID

---

### Problem: Shows "Budget" Instead of "Spend (FB)"

**This means:** Campaign not matched to Facebook

**Why:**
- `campaignKey` field doesn't match Facebook Campaign ID
- Campaign doesn't exist in Facebook account

**Solution:**
1. Get Facebook Campaign ID from Ads Manager
2. Update `campaignKey` in Firestore for that campaign
3. Refresh the page

---

### Problem: Refresh Button Not Working

**Check:**
- Look for loading spinner (should appear briefly)
- Check console for error messages
- Verify internet connection

**If Stuck:**
- Reload the page completely
- Check Facebook app is still in Live mode

---

## 📈 What's Next?

### Recommended:
1. **Test with your campaigns** - Verify data accuracy
2. **Check calculations** - CPL/CPB should use Facebook spend now
3. **Monitor for a week** - Ensure stable operation
4. **Request Advanced Access** - After 1500+ API calls, get higher rate limits

### Future Enhancements:
- Date range picker (currently fixed at 30 days)
- Campaign mapping UI (to link GHL↔️Facebook)
- Individual ad-level breakdown (currently campaign-level)
- Scheduled auto-refresh
- Email alerts for campaign performance

---

## 📚 Documentation

**Detailed Guides:**
- `FACEBOOK_ADS_API_INTEGRATION_COMPLETE.md` - Full technical documentation
- `FACEBOOK_ADS_API_TESTING_GUIDE.md` - Testing checklist
- `facebook-ads-api-integration.plan.md` - Original implementation plan

**Facebook Resources:**
- [Marketing API Docs](https://developers.facebook.com/docs/marketing-api)
- [Insights API](https://developers.facebook.com/docs/marketing-api/insights)
- [App Dashboard](https://developers.facebook.com/apps/1579668440071828)

---

## 💡 Pro Tips

1. **Check Sync Time:** The "synced Xm ago" badge tells you data freshness
2. **Use Manual Refresh:** Click 🔄 to get immediate updates (ignores 5min cache)
3. **Look for Blue:** "Spend (FB)" in blue means live Facebook data is being used
4. **Compare to Facebook:** Cross-check numbers in Facebook Ads Manager to verify accuracy
5. **Monitor Console:** Keep browser console open during first use to catch any issues

---

## ✅ Success Indicators

**Your integration is working if:**
- ✅ Sync status badge shows recent time
- ✅ At least one campaign shows "Spend (FB)" in blue
- ✅ Facebook metrics section displays with numbers
- ✅ Refresh button updates the sync time
- ✅ CPL/CPB calculations reflect Facebook spend

---

## 🎯 Summary

**What Changed:**
- Manual "Budget" → Automatic "Spend (FB)" from Facebook
- Added Facebook ad metrics (impressions, CPM, CPC, CTR)
- CPL/CPB/CPA now calculated from real Facebook spend
- One unified view: Facebook data + GHL conversions

**What Stayed the Same:**
- GHL data (leads, bookings, deposits)
- UI layout and navigation
- Existing manual budgets still work

**What To Do:**
1. Load the Advertisement Performance screen
2. Look for "FB synced" badge
3. Verify your campaigns show Facebook data
4. Use refresh button to update

---

**Status:** ✅ **READY TO USE**  
**Last Updated:** October 27, 2025

---

## Questions?

**Check:**
1. Browser console (F12) for error messages
2. Facebook App Dashboard for token/permissions
3. Firestore for `campaignKey` values
4. Full documentation in `FACEBOOK_ADS_API_INTEGRATION_COMPLETE.md`

**Enjoy your automated ad performance tracking! 🚀**


