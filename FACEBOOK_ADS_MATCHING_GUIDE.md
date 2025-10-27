# Facebook Ads Data Matching Guide

## Overview

The Ad Performance Cost table now shows **live Facebook ad spend** instead of manual budget entries, and displays all Facebook advertising metrics alongside your GHL (GoHighLevel) lead/booking data.

**IMPORTANT: Only ads with matching Facebook campaigns will be displayed. Ads without a Facebook match are automatically hidden.**

## What Changed

### ✅ **Removed**
- ❌ **Deposits column** - Completely removed from the main metrics row

### ✅ **Added**
- ✨ **FB Spend column** - Shows the actual amount Facebook is charging to run your ads
- 📊 **Facebook Campaign List** - Displays available Facebook campaigns at the top of the page
- 🔑 **Campaign Key Display** - Shows the campaignKey for each ad to help with matching
- 💙 **"Live FB Data" badge** - Indicates when an ad is successfully linked to Facebook
- 🔍 **Filtered View** - Only displays ads that have matching Facebook campaigns (unmatched ads are hidden)

## How Facebook Data Matching Works

### The Matching Key: `campaignKey`

The system matches your ads to Facebook campaigns using the **`campaignKey`** field in Firebase. This field should contain the **Facebook Campaign ID** (not the campaign name).

### Example:

If you have a Facebook campaign:
- **Name**: "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences"
- **ID**: `120234497185340335`
- **Spend**: $1885.66

You need to set the `campaignKey` in your Firebase `ad_performance_costs` document to `120234497185340335`.

## Step-by-Step: How to Link Your Ads

### 1. **View Available Facebook Campaigns**

When you open the Ad Performance screen, you'll see a blue box at the top showing:

```
📘 Facebook Campaigns Available (25)
To link ads, use the Campaign ID as the "campaignKey" in Firebase:
• Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences (ID: 120234497185340335) - $1885.66
• Matthys - 16102025 - ABOLEADFORMZA (DDM) - Physiotherapist (ID: 120234487479280335) - $284.20
...
```

### 2. **Find the Campaign ID You Need**

Look through the list and find the Facebook campaign that corresponds to your ad. Copy the **ID** (the long number in parentheses).

### 3. **Update Firebase**

Go to your Firebase Console:

1. Navigate to **Firestore Database**
2. Open the `ad_performance_costs` collection
3. Find the document for the ad you want to link
4. Edit the `campaignKey` field
5. Paste the Facebook Campaign ID (e.g., `120234497185340335`)
6. Save

### 4. **Refresh the Page**

Click the **Refresh** button (🔄) in the Ad Performance Cost header to reload Facebook data. You should now see:

- 💙 **"Live FB Data"** badge on the ad card
- **FB Spend** showing the actual Facebook ad cost (in blue)
- **Facebook Metrics** section showing Impressions, Reach, Clicks, CPM, CPC, CTR

## Current Ads Status

Based on the logs, here are your current ads:

| Ad Name | Current Campaign Key | Status | Action Needed |
|---------|---------------------|--------|---------------|
| Obesity - Andries - DDM | (check Firebase) | ❌ No FB data | Match to FB Campaign ID |
| Health Providers | (check Firebase) | ❌ No FB data | Match to FB Campaign ID |
| 120232883487010335 | 120232883487010335 | ❌ No FB data | Verify this is correct Campaign ID |

## Available Facebook Campaigns (Sample)

From the terminal logs, here are some of the active Facebook campaigns:

```
120234497185340335 - Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences ($1885.66)
120234487479280335 - Matthys - 16102025 - ABOLEADFORMZA (DDM) - Physiotherapist ($284.20)
120234485362420335 - Matthys - 16102025 - ABOLANDER (DDM) - Retargeting ($187.81)
120234435129520335 - Matthys - 15102025 - ABOLEADFORMZA (DDM) - Afrikaans ($842.04)
120234319834310335 - Matthys - 13102025 - ABOLANDERZA - Grouped ($623.88)
120233712403260335 - Matthys | 03102025 ABOLEADFORM (DDM) ($7812.23)
120232883487010335 - (Check Facebook for name) ($?)
```

## What You'll See When Matched

Once an ad is matched to a Facebook campaign:

### Main Metrics Row:
- **Leads**: From GHL
- **Bookings**: From GHL  
- **FB Spend**: 💙 Real-time Facebook cost (replaces manual budget)
- **CPL, CPB, CPA**: Calculated using FB Spend
- **Profit**: Revenue minus FB Spend

### Facebook Metrics Row (below main metrics):
- **Impressions**: How many times the ad was shown
- **Reach**: How many unique people saw it
- **Clicks**: How many clicks the ad received
- **CPM**: Cost per 1000 impressions ($)
- **CPC**: Cost per click ($)
- **CTR**: Click-through rate (%)

## Troubleshooting

### "I don't see any ads at all!"

**This is expected behavior.** Ads without matching Facebook campaigns are now automatically hidden.

**To make ads visible:**
1. Check the blue "Facebook Campaigns Available" box at the top of the page
2. Copy a Facebook Campaign ID from that list
3. Go to Firebase and update the `campaignKey` field for your ad to match that ID
4. Click the Refresh button (🔄)
5. Your ad should now appear with live Facebook data

### "I don't see any Facebook data"

**Check:**
1. Is the Facebook sync status showing at the top? (Should say "FB synced Xm ago")
2. Is the `campaignKey` in Firebase set to the correct Facebook Campaign ID?
3. Try clicking the Refresh button (🔄)

### "My campaignKey matches but no data shows"

**Possible reasons:**
- The Facebook campaign might have no spend in the date range
- The Campaign ID might be incorrect (double-check the exact number)
- The campaign might be paused or deleted in Facebook

### "I see a campaign in Facebook but not in the list"

The list shows the top 5 campaigns. There might be more - check the Facebook Ads Manager directly, or look at the full terminal output after refresh.

## Important Notes

1. **FB Spend replaces Budget**: When Facebook data is available, the "Budget" field is replaced with "FB Spend" showing the actual cost from Facebook.

2. **Automatic Calculations**: CPL, CPB, and CPA are automatically recalculated using the Facebook spend (not the manual budget).

3. **Real-time Updates**: Click the Refresh button to fetch the latest data from Facebook. Data is cached for 5 minutes to avoid rate limits.

4. **Campaign vs Ad Level**: Currently matching at the campaign level. All ads in a GHL campaign will share the same Facebook campaign data.

## Next Steps

1. **Review the Facebook campaign list** in the blue box at the top of the Ad Performance screen
2. **Copy the Campaign IDs** for your active campaigns
3. **Update Firebase** `ad_performance_costs` documents with the correct `campaignKey`
4. **Refresh the page** to see live Facebook data appear

---

**Need Help?** Check the terminal logs for detailed Facebook API responses, or review the `lib/services/facebook/facebook_ads_service.dart` file to see how the matching works.

