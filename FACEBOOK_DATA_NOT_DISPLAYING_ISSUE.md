# 🔍 Issue: Facebook Spend Not Showing in UI

## Problem Description

User reports seeing **GHL data** (Leads, Bookings) but **NO Facebook spending data** in the UI, even though ads are marked as "matched".

## Investigation Results

### ✅ **Data IS in Firebase!**

Verified that **84 ads** have BOTH:
- Facebook spend > $0
- GHL leads > 0

Example ads found in Firebase:
1. **"Physiotherapists - Elmien"**: $321.97 spend, 28 leads, 9 bookings ✅
2. **"Obesity - Andries - DDM"**: $244 spend, 29 leads, 11 bookings ✅
3. **"Explainer (Afrikaans) - DDM"**: $935.40 spend, 51 leads, 17 bookings ✅

### ❌ **But UI Shows `-` for FB Spend**

Screenshot shows campaigns with GHL data but empty FB Spend column.

## Root Cause Analysis

The issue is in **how the UI aggregates and displays data**:

### Current UI Structure (from screenshot):
```
Campaign: "Obesity - Andries - DDM"
├─ Leads: 53
├─ Bookings: 21
└─ FB Spend: - (EMPTY!)
```

### Firebase Structure:
```
adPerformance/
├─ Ad 1: "Obesity - Andries - DDM" (variant A)
│  ├─ facebookStats.spend: $244.00
│  └─ ghlStats.leads: 29
├─ Ad 2: "Obesity - Andries - DDM" (variant B)
│  ├─ facebookStats.spend: $218.04
│  └─ ghlStats.leads: 29
└─ Ad 3: "Obesity - Andries - DDM" (variant C)
   ├─ facebookStats.spend: $147.14
   └─ ghlStats.leads: 29
```

**Total for campaign**: $609.18 spend across 3 ad variants, 87 total leads

## The Problem

The UI appears to be showing **campaign-level GHL data** but not **aggregating Facebook spend** from the individual ads in that campaign.

###  Check Where UI Gets Data

Looking at the code flow:

1. **`PerformanceCostProvider.mergeWithCumulativeData()`**
   - This method merges GHL pipeline data with Firebase ad performance
   - Returns `List<AdPerformanceWithProduct>`

2. **`AddPerformanceCostTable` widget**
   - Displays the merged data
   - Shows individual ads OR campaign summaries

The issue is likely in **how campaign-level summaries are calculated**.

## Solution Options

### Option 1: Show Individual Ads (RECOMMENDED)
**Change the UI to display individual ad variants instead of campaign summaries**

Benefits:
- Shows exact Facebook spend per ad
- Shows which specific ad creative is performing
- More granular data for optimization

Changes needed:
- Modify `AddPerformanceCostTable` to iterate through `adPerformanceWithProducts`
- Display each ad as a separate row
- Group by campaign for clarity

### Option 2: Aggregate Facebook Spend at Campaign Level
**Sum up all Facebook spend for ads in the same campaign**

Benefits:
- Keeps current campaign-level view
- Shows total campaign investment

Changes needed:
- When building campaign summaries, aggregate all matching ads' Facebook spend
- Group ads by `campaignName`
- Sum `facebookStats.spend` for all ads in campaign

### Option 3: Hybrid View
**Show campaigns with expandable ad details**

Benefits:
- Clean overview (campaigns)
- Detailed view when expanded (individual ads)
- Best of both worlds

## Recommended Fix

Implement **Option 1** first (show individual ads) because:
1. ✅ Data is already structured for this
2. ✅ No aggregation logic needed
3. ✅ More actionable for user
4. ✅ Faster to implement

Then add **Option 3** (grouping/expansion) as enhancement.

## Implementation Steps

1. **Modify the table to show individual ads:**
   ```dart
   // Instead of grouping by campaign, show each ad
   for (final adPerf in mergedData) {
     _buildAdRow(
       adName: adPerf.adName,
       campaignName: adPerf.campaignName,
       fbSpend: adPerf.facebookStats.spend,
       leads: adPerf.ghlStats?.leads ?? 0,
       bookings: adPerf.ghlStats?.bookings ?? 0,
       // ...
     );
   }
   ```

2. **Update the display to show ad-level metrics:**
   - Ad Name (primary)
   - Campaign Name (subtitle)
   - FB Spend (from facebookStats)
   - Leads, Bookings (from ghlStats)
   - CPL, CPB (calculated)

3. **Add grouping indicator:**
   ```dart
   // Group header
   if (isFirstAdInCampaign) {
     _buildCampaignHeader(campaignName);
   }
   
   // Ad row
   _buildAdRow(ad);
   ```

## Current Status

- ✅ Data confirmed in Firebase (84 ads with both FB + GHL data)
- ✅ Data structures correct
- ✅ Provider loading data correctly
- ❌ UI not displaying Facebook spend
- 🔧 **NEEDS FIX**: Update UI widget to show ad-level data properly

## Next Action

Update `AddPerformanceCostTable` widget to display individual ads with their Facebook spend instead of campaign-level summaries without Facebook data.

