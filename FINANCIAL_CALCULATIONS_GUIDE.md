# Financial Calculations Guide - MedWave Analytics

**Date:** November 12, 2025  
**Status:** Critical Issue Identified - Requires Fix  
**Priority:** High

---

## 📊 Overview

This document explains how financial metrics (Total Spend, Total Revenue, Total Profit) are calculated across the MedWave advertising analytics system, identifies a critical bug in monthly aggregation, and provides detailed fix recommendations.

---

## 🏗️ System Architecture

### Data Collections in Firebase

```
Firebase Firestore Collections:
├── campaigns/           (Pre-aggregated lifetime + monthly totals)
├── adSets/             (Pre-aggregated lifetime + monthly totals)
├── ads/                (Individual ad data with lifetime totals)
└── ghlOpportunities/   (Revenue data from GoHighLevel CRM)
```

### Core Financial Formula

**The fundamental profit calculation at ALL levels (Campaign, Ad Set, Ad):**

```dart
totalProfit = totalCashAmount - totalSpend
```

Where:
- **`totalSpend`** = Facebook ad spend (from `ads.facebookStats.spend`)
- **`totalCashAmount`** = Revenue from GHL opportunities (deposits + cash collected)

---

## 💰 How `totalCashAmount` is Calculated

### Source: `ghlOpportunities` Collection

Each opportunity document has:
```javascript
{
  opportunityId: "abc123",
  adId: "linked_ad_id",          // Which ad generated this opportunity
  stageCategory: "deposits",      // Current stage: leads, bookedAppointments, deposits, cashCollected
  monetaryValue: 450.00,          // ⚠️ THE REVENUE VALUE
  createdAt: "2025-11-15T10:00:00Z",
  // ... other fields
}
```

### Stage Category Logic

**From:** `split_collections_schema/sync_ghl_monetary_values.py`

```python
def get_stage_category_from_name(stage_name):
    stage_lower = stage_name.lower()
    
    if 'booked' in stage_lower or 'appointment' in stage_lower:
        return 'bookedAppointments'
    elif 'deposit' in stage_lower:
        return 'deposits'
    elif 'cash' in stage_lower or 'collected' in stage_lower:
        return 'cashCollected'
    elif 'lost' in stage_lower or 'disqualified' in stage_lower:
        return 'lost'
    else:
        return 'leads'
```

### Revenue Calculation

**Only these stages contribute to `totalCashAmount`:**

```dart
// From campaign_service.dart and ad_set_service.dart
for (opportunity in ghlOpportunities) {
  if (opportunity.stageCategory == 'deposits' || 
      opportunity.stageCategory == 'cashCollected') {
    totalCashAmount += opportunity.monetaryValue;
  }
}
```

---

## 🔄 Data Flow & Aggregation

### Aggregation Hierarchy

```
ghlOpportunities (individual opportunities with dates)
    ↓ (aggregated by adId & filtered by createdAt date)
ads.ghlStats (LIFETIME totals per ad)
    ↓ (aggregated by adSetId)
adSets (LIFETIME totals + monthlyTotals)
    ↓ (aggregated by campaignId)
campaigns (LIFETIME totals + monthlyTotals)
```

### Python Scripts That Perform Aggregation

1. **`sync_ghl_monetary_values.py`**
   - Fetches opportunities from GHL API
   - Updates `monetaryValue` and `stageCategory` in Firebase
   - Run this first to ensure accurate data

2. **`reaggregate_ghl_to_ads.py`**
   - Queries `ghlOpportunities` collection
   - Aggregates to `ads.ghlStats` (LIFETIME totals)
   - Calculates profit = cashAmount - spend

3. **`populate_monthly_totals.py`** ⚠️ **HAS CRITICAL BUG**
   - Supposed to populate `monthlyTotals` field
   - Groups by month for date-specific filtering
   - **Currently broken** (details below)

4. **`recalculate_campaign_adset_totals.py`**
   - Rolls up totals from ads → ad sets → campaigns
   - Updates lifetime totals only

---

## 🚨 CRITICAL ISSUE IDENTIFIED

### The Problem

**File:** `populate_monthly_totals.py`  
**Lines:** 78-83 (campaign section) and 191-197 (ad set section)

```python
# ❌ WRONG CODE - Uses LIFETIME totals from ads
ghl_stats = ad.get('ghlStats', {})
monthly_data[month]['leads'] += ghl_stats.get('leads', 0)
monthly_data[month]['bookings'] += ghl_stats.get('bookings', 0)
monthly_data[month]['deposits'] += ghl_stats.get('deposits', 0)
monthly_data[month]['cashCollected'] += ghl_stats.get('cashCollected', 0)
monthly_data[month]['cashAmount'] += ghl_stats.get('cashAmount', 0)  # ❌ LIFETIME!
```

### Why This Is Wrong

1. **`ads.ghlStats` are LIFETIME totals**, not month-specific
2. An opportunity created in October 2025 will be counted in November's totals if the ad ran in both months
3. The script groups ads by `firstInsightDate` (when ad started), not by when opportunities were created
4. This causes **revenue inflation** for recent months and **incorrect monthly profit calculations**

### Example of the Bug

```
Scenario:
- Ad runs Oct 15 - Nov 30
- Opportunity created Oct 20 with monetaryValue = $500
- Ad's firstInsightDate = "2025-10-15"

Current Behavior (WRONG):
- October totals: cashAmount += $500 ✓ (correct)
- November totals: $0 (ad not counted because firstInsightDate is Oct)

Expected Behavior:
- October totals: cashAmount += $500 ✓
- November totals: $0 ✓ (opportunity was created in Oct, not Nov)
```

Actually, the bug is worse:

```
Better Example:
- Ad runs Oct 1 - Oct 31
- Ad's firstInsightDate = "2025-10-01"
- Opportunity created Nov 5 with monetaryValue = $500

Current Behavior (WRONG):
- October totals: cashAmount += $500 ❌ (WRONG! Opp created in Nov)
- November totals: $0 ❌ (WRONG! Opp created in Nov but ad ran in Oct)

Expected Behavior:
- October totals: $0 (no opps created in Oct)
- November totals: $0 (ad didn't run in Nov)
```

The script groups by ad's `firstInsightDate` (when ad started) but uses lifetime GHL totals, causing complete misattribution.

---

## ✅ RECOMMENDED FIXES

### Fix 1: Modify `populate_monthly_totals.py`

Replace the GHL aggregation logic to query opportunities directly.

**Location:** Lines 77-84 (campaign section) and 191-197 (ad set section)

**Replace with:**

```python
# ✅ CORRECT CODE - Query opportunities and filter by createdAt date
from datetime import datetime

# ... inside the ad loop, after determining the month ...

# Query ghlOpportunities for this ad and filter by creation date
ad_id = ad_doc.id
opportunities_ref = db.collection('ghlOpportunities').where('adId', '==', ad_id).stream()

for opp_doc in opportunities_ref:
    opp = opp_doc.to_dict()
    opp_created_at = opp.get('createdAt')
    
    # Parse createdAt (handle both Timestamp and string formats)
    opp_date = None
    if isinstance(opp_created_at, str):
        try:
            # Handle ISO format strings
            opp_date = datetime.fromisoformat(opp_created_at.replace('Z', '+00:00'))
        except:
            continue
    elif hasattr(opp_created_at, 'year'):  # Firestore Timestamp object
        opp_date = opp_created_at
    
    if not opp_date:
        continue
    
    # Extract month from opportunity creation date
    opp_month = opp_date.strftime('%Y-%m')
    
    # Only count if opportunity was created in the month we're aggregating
    if opp_month != month:
        continue
    
    # Get opportunity details
    stage_category = opp.get('stageCategory', 'leads')
    monetary_value = opp.get('monetaryValue', 0)
    
    # Count as lead (all opportunities are leads)
    monthly_data[month]['leads'] += 1
    
    # Count as booking if reached booking stage or beyond
    if stage_category in ['bookedAppointments', 'deposits', 'cashCollected']:
        monthly_data[month]['bookings'] += 1
    
    # Count as deposit if reached deposit stage or beyond
    if stage_category in ['deposits', 'cashCollected']:
        monthly_data[month]['deposits'] += 1
        monthly_data[month]['cashAmount'] += monetary_value
    
    # Count as cash collected if reached final stage
    if stage_category == 'cashCollected':
        monthly_data[month]['cashCollected'] += 1
```

**Apply this fix to BOTH:**
- Campaign section (around line 77)
- Ad Set section (around line 191)

### Fix 2: Update Dart Service to Use Monthly Totals

**File:** `lib/providers/performance_cost_provider.dart`  
**Method:** `loadCampaignsWithDateRange` (around line 1173)

**Current code:**

```dart
_campaigns = await _campaignService.getCampaignsByDateRange(
  startDate: startDate,
  endDate: endDate,
  limit: limit,
  orderBy: orderBy,
  descending: descending,
);
```

**Replace with:**

```dart
// Detect if filtering by a single month
final isSingleMonth = startDate != null && 
                       endDate != null &&
                       startDate.year == endDate.year &&
                       startDate.month == endDate.month;

if (isSingleMonth) {
  // Use pre-aggregated monthly totals (FAST & ACCURATE)
  final monthStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
  
  if (kDebugMode) {
    print('📊 Using pre-aggregated monthly totals for month: $monthStr');
  }
  
  _campaigns = await _campaignService.getCampaignsWithMonthTotals(
    month: monthStr,
    limit: limit,
    orderBy: orderBy,
    descending: descending,
  );
} else {
  // Use date range query for custom ranges
  if (kDebugMode) {
    print('📊 Using date range query (slower, real-time calculation)');
  }
  
  _campaigns = await _campaignService.getCampaignsByDateRange(
    startDate: startDate,
    endDate: endDate,
    limit: limit,
    orderBy: orderBy,
    descending: descending,
  );
}
```

### Fix 3: Do the Same for Ad Sets

**File:** `lib/providers/performance_cost_provider.dart`  
**Method:** `loadAdSetsForCampaign` (around line 1251)

**Add similar logic:**

```dart
Future<void> loadAdSetsForCampaign(String campaignId) async {
  try {
    if (kDebugMode) {
      print('🔄 Loading ad sets for campaign: $campaignId');
    }
    
    // Detect if filtering by single month
    final isSingleMonth = _filterStartDate != null && 
                         _filterEndDate != null &&
                         _filterStartDate!.year == _filterEndDate!.year &&
                         _filterStartDate!.month == _filterEndDate!.month;

    if (isSingleMonth) {
      final monthStr = '${_filterStartDate!.year}-${_filterStartDate!.month.toString().padLeft(2, '0')}';
      
      if (kDebugMode) {
        print('📊 Using pre-aggregated monthly totals for ad sets: $monthStr');
      }
      
      _adSets = await _adSetService.getAdSetsWithMonthTotals(
        campaignId: campaignId,
        month: monthStr,
        orderBy: 'totalProfit',
        descending: true,
      );
    } else {
      // Use lifetime totals
      if (kDebugMode) {
        print('📊 Using lifetime totals for ad sets');
      }
      
      _adSets = await _adSetService.getAdSetsForCampaign(
        campaignId,
        orderBy: 'totalProfit',
        descending: true,
      );
    }
    
    // ... rest of method
```

---

## 🔍 How to Verify the Fix

### Step 1: Run Python Scripts in Order

```bash
# Navigate to project root
cd /path/to/medwave

# Step 1: Ensure GHL opportunities have correct monetary values
python split_collections_schema/sync_ghl_monetary_values.py

# Step 2: Re-aggregate GHL stats to ads (lifetime totals)
python split_collections_schema/reaggregate_ghl_to_ads.py

# Step 3: Populate monthly totals (WITH YOUR FIX!)
python populate_monthly_totals.py

# Step 4: Recalculate campaigns/ad sets from aggregated data
python recalculate_campaign_adset_totals.py
```

### Step 2: Manual Verification in Firebase Console

1. **Open Firebase Console** → Firestore Database

2. **Check a Campaign's Monthly Totals:**
   ```
   campaigns/{campaignId}/monthlyTotals/2025-11
   ```
   
   Expected fields:
   ```javascript
   {
     spend: 1234.56,
     cashAmount: 5678.90,
     profit: 4444.34,  // = cashAmount - spend
     leads: 25,
     bookings: 15,
     deposits: 8,
     cashCollected: 5,
     // ... other metrics
   }
   ```

3. **Manually Calculate to Verify:**
   ```
   Query: ghlOpportunities
   Where: adId in [list of ad IDs for this campaign]
   AND: createdAt >= "2025-11-01"
   AND: createdAt < "2025-12-01"
   AND: stageCategory in ["deposits", "cashCollected"]
   
   Sum: monetaryValue
   
   Compare to: campaigns/{id}/monthlyTotals/2025-11/cashAmount
   ```

### Step 3: Test in Flutter UI

1. Launch the app
2. Navigate to **Campaign Performance** screen
3. Select **"This Month"** filter
4. Verify:
   - Total Spend matches Firebase
   - Total Profit = Cash - Spend
   - Numbers don't change when switching between "This Month" and back
5. Click into a campaign → ad set → ad
6. Verify numbers are consistent at each level

### Step 4: Compare Before/After

**Create a snapshot before fixing:**

```bash
# Export current November totals
firebase firestore:export gs://your-bucket/backup-before-fix
```

**After applying fix:**

```bash
# Export new November totals
firebase firestore:export gs://your-bucket/backup-after-fix

# Compare campaigns with significant spend
# Look for changes in monthlyTotals/2025-11/cashAmount
```

---

## 📈 Expected Impact of Fix

### Before Fix (Current State)
- ❌ Monthly revenue is incorrectly attributed based on ad start date
- ❌ Opportunities from previous months inflate current month's profit
- ❌ Filtering by "This Month" shows incorrect profit
- ❌ Can't trust monthly reports for decision-making

### After Fix
- ✅ Monthly revenue accurately reflects when opportunities were created
- ✅ Each month shows only that month's revenue
- ✅ Profit calculations are accurate for any month selected
- ✅ Historical analysis becomes reliable

### Example Fix Impact

```
Campaign: "Medical Checkup Nov 2025"
Ad: "Get Your Health Check" (ran Oct 20 - Nov 15)

Before Fix:
- Oct totals: $2,500 revenue (includes Nov opportunities!)
- Nov totals: $0 revenue (ad's firstInsightDate was Oct)

After Fix:
- Oct totals: $1,200 revenue (only Oct opportunities)
- Nov totals: $1,300 revenue (only Nov opportunities)
```

---

## 🎯 UI Display Logic

### Where Financial Data is Displayed

**File:** `lib/widgets/admin/performance_tabs/three_column_campaign_view.dart`

The UI shows three columns:
1. **Campaigns** - Shows `totalSpend`, `totalProfit`, `totalCashAmount`
2. **Ad Sets** - Shows the same metrics, filtered by selected campaign
3. **Ads** - Shows individual ad performance

### How Data Flows to UI

```dart
// 1. Campaign Service fetches from Firebase
Campaign campaign = await campaignService.getCampaignsWithMonthTotals(month: "2025-11");

// 2. Provider converts to UI model
CampaignAggregate uiCampaign = campaignToCampaignAggregate(campaign);

// 3. UI model computes profit on-the-fly
double get totalProfit {
  return totalCashAmount - totalFbSpend;  // Computed getter
}

// 4. Widget displays
Text('Profit: \$${campaign.totalProfit.toStringAsFixed(2)}')
```

### Current Filters

**File:** `lib/screens/admin/adverts/admin_adverts_campaigns_screen.dart`

Available filters:
- **Month Filter** (Primary): This Month, Last Month, Last 3 Months, etc.
- **Date Filter** (Secondary): Today, Yesterday, Last 7 Days, Last 30 Days, All Dates

**Filter behavior:**
- Month filter determines which pre-aggregated data to load
- Date filter applies additional client-side filtering
- Both filters work together for precise date ranges

---

## 🔧 Alternative Approaches Considered

### Option A: Real-Time Calculation (Current Deprecated Method)
```dart
// Uses calculateCampaignTotalsForDateRange()
// Queries ads + ghlOpportunities on every page load
// Pro: Always accurate, no pre-aggregation needed
// Con: VERY SLOW (30+ seconds for large campaigns)
```

### Option B: Pre-Aggregated Monthly Totals (Recommended - WITH FIX)
```dart
// Uses getCampaignsWithMonthTotals()
// Reads from campaigns.monthlyTotals field
// Pro: FAST (<1 second), efficient
// Con: Requires periodic aggregation script
```

### Option C: Hybrid Approach (Current Implementation)
```dart
// Use monthly totals for single month selection
// Use real-time calculation for custom date ranges
// Pro: Fast for common case, accurate for custom ranges
// Con: Inconsistent performance
```

**Decision: Stick with Option C, but fix the monthly aggregation bug**

---

## 📚 Related Files

### Backend (Python Aggregation Scripts)
- `populate_monthly_totals.py` - ⚠️ Needs fix
- `recalculate_campaign_adset_totals.py` - Lifetime totals
- `split_collections_schema/reaggregate_ghl_to_ads.py` - GHL to ads
- `split_collections_schema/sync_ghl_monetary_values.py` - Sync from GHL API

### Frontend (Flutter/Dart Services)
- `lib/services/firebase/campaign_service.dart` - Campaign queries
- `lib/services/firebase/ad_set_service.dart` - Ad Set queries
- `lib/services/firebase/ad_service.dart` - Ad queries
- `lib/services/firebase/ghl_opportunity_service.dart` - GHL queries

### Frontend (Flutter/Dart Providers & UI)
- `lib/providers/performance_cost_provider.dart` - Main data provider
- `lib/screens/admin/adverts/admin_adverts_campaigns_screen.dart` - Main screen
- `lib/widgets/admin/performance_tabs/three_column_campaign_view.dart` - Campaign list

### Models
- `lib/models/performance/campaign.dart` - Campaign model
- `lib/models/performance/ad_set.dart` - Ad Set model
- `lib/models/performance/ad.dart` - Ad model
- `lib/models/performance/ghl_opportunity.dart` - GHL Opportunity model
- `lib/models/performance/campaign_aggregate.dart` - UI aggregate model

---

## 🚦 Implementation Checklist

- [ ] **Read and understand this document**
- [ ] **Backup current Firebase data** (export monthlyTotals)
- [ ] **Apply Fix 1:** Modify `populate_monthly_totals.py`
  - [ ] Update campaign section (lines 77-84)
  - [ ] Update ad set section (lines 191-197)
  - [ ] Test the script on a single campaign first
- [ ] **Apply Fix 2:** Modify `performance_cost_provider.dart`
  - [ ] Update `loadCampaignsWithDateRange` method
  - [ ] Add month detection logic
- [ ] **Apply Fix 3:** Modify ad set loading
  - [ ] Update `loadAdSetsForCampaign` method
  - [ ] Add month detection logic
- [ ] **Run aggregation scripts in order**
  - [ ] `sync_ghl_monetary_values.py`
  - [ ] `reaggregate_ghl_to_ads.py`
  - [ ] `populate_monthly_totals.py` (with fix)
  - [ ] `recalculate_campaign_adset_totals.py`
- [ ] **Verify in Firebase Console**
  - [ ] Check monthlyTotals for November 2025
  - [ ] Manually calculate and compare
- [ ] **Test in Flutter UI**
  - [ ] Filter by "This Month"
  - [ ] Check if numbers are consistent
  - [ ] Drill down through campaign → ad set → ad
- [ ] **Compare before/after** (export both datasets)
- [ ] **Document any issues found**
- [ ] **Deploy to production**

---

## 📞 Questions or Issues?

If you encounter problems:

1. **Check Firebase Console** - Verify data structure
2. **Check Python script output** - Look for errors or warnings
3. **Check Flutter debug console** - Look for API errors
4. **Compare with this document** - Ensure fix was applied correctly

Common issues:
- **"No monthlyTotals field"** - Run `populate_monthly_totals.py`
- **"Profit is negative"** - Check if `monetaryValue` is populated in GHL opportunities
- **"Numbers don't match"** - Verify opportunity `createdAt` dates are correct
- **"Filter doesn't work"** - Check if Dart fix was applied to use monthly totals

---

## 📝 Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-12 | 1.0 | Initial documentation - Issue identified and fixes recommended |

---

**Next Steps:** Implement the fixes outlined in this document, test thoroughly, and update this document with results.

---

*Document created by: AI Analysis*  
*Last updated: November 12, 2025*  
*Review this document before making any changes to financial calculation logic.*

