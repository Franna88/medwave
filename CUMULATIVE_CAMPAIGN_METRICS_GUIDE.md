# Cumulative Campaign Metrics - User Guide

## ✅ Feature Status: **FULLY IMPLEMENTED**

Your request to show **cumulative totals for each ad campaign** is already complete and working!

---

## 🎯 What This Feature Does

When you switch to **Cumulative View**, the "Ad Campaign Performance by Stage" table shows **cumulative totals** for each campaign and ad:

### Cumulative Metrics Explained:
- **Total**: Total number of opportunities that entered the funnel from this campaign
- **Booked**: Total opportunities that reached "Booked Appointments" stage (cumulative, never decreases)
- **Call**: Total opportunities that reached "Call Completed" stage (cumulative)
- **No Show**: Total opportunities that reached "No Show/Cancelled/Disqualified" stage
- **Deposits**: Total opportunities that reached "Deposits" stage
- **Cash**: Total opportunities that reached "Cash Collected" stage

### Key Points:
✅ Numbers **never decrease** - once an opportunity reaches a stage, it's counted forever  
✅ Each campaign shows **all ads** within that campaign (click to expand)  
✅ Data is filtered by the **selected timeframe** (Last 7 Days, Last 30 Days, etc.)  
✅ Only tracks opportunities **with UTM campaign attribution** (from ads)

---

## 🚀 How to Use It

### Step 1: Sync Data (First Time Only)
1. Open the **Advertisement Performance** screen
2. Click the **Sync button** (🔄 icon in top-right corner)
3. Wait 10-30 seconds for sync to complete
4. You'll see: `✅ Synced: 149 opportunities`

### Step 2: Switch to Cumulative View
1. Click the **"Cumulative"** toggle button (next to "Snapshot")
2. The view changes to show cumulative metrics

### Step 3: View Campaign Performance
The **"Ad Campaign Performance by Stage"** table now shows:
- **Top 10 campaigns** sorted by total opportunities
- **Cumulative stage counts** for each campaign
- **Expandable rows** to see individual ads within each campaign

### Step 4: Filter by Timeframe
Use the **"Timeframe"** dropdown to filter data:
- Last 7 Days
- Last 30 Days
- Last 90 Days
- This Year
- All Time

---

## 📊 What You'll See

### Campaign Table Columns:
| Column | Description |
|--------|-------------|
| **Campaign Name** | Name of the ad campaign (e.g., "MedWave Image Ads") |
| **Total** | Total opportunities from this campaign |
| **Booked** | How many reached "Booked Appointments" |
| **Call** | How many reached "Call Completed" |
| **No Show** | How many reached "No Show/Cancelled" |
| **Deposits** | How many reached "Deposits" |
| **Cash** | How many reached "Cash Collected" |

### Example:
```
Campaign Name                               Total  Booked  Call  No Show  Deposits  Cash
────────────────────────────────────────────────────────────────────────────────────────
📢 MedWave Image Ads (2 ads)                 10     1       0      2        0        0
   📌 Ad: Matthys - 17092025 - ABOLEADFORM    8     7       0      0        0        0
   📌 Ad: Matthys - 01082025 - Medical Doc    5     0       0      1        0        0
```

---

## 🔄 Snapshot vs Cumulative

### Snapshot View (Default):
- Shows **current count** in each stage
- Numbers **can decrease** when opportunities move stages
- Reflects **right now** state

### Cumulative View:
- Shows **total count** that ever reached each stage
- Numbers **never decrease**
- Tracks **historical progress** of opportunities

---

## 💡 Management Benefits

With cumulative campaign metrics, management can now see:

1. **Campaign Effectiveness**: Which campaigns generate the most leads?
2. **Conversion Funnel**: How many opportunities progress through each stage?
3. **Ad Performance**: Which specific ads within a campaign perform best?
4. **ROI Tracking**: Track cumulative progress over time
5. **Historical Trends**: See how campaigns performed in different timeframes

---

## 🎨 Visual Features

- **Color-coded columns**: Each stage has a distinct color
- **Expandable campaigns**: Click any campaign to see individual ads
- **Live data badge**: Shows you're viewing real-time data
- **Campaign count**: See total number of campaigns and ads
- **Top 10 filter**: Focuses on best-performing campaigns

---

## 🔍 Example Use Cases

### Use Case 1: Evaluate Campaign ROI
**Question**: "How many leads did our September campaigns generate?"
1. Select "Last 30 Days" timeframe
2. Switch to "Cumulative" view
3. Look at "Total" column for each campaign
4. See which campaigns drove the most opportunities

### Use Case 2: Track Ad Performance
**Question**: "Which specific ad in our campaign converted best?"
1. Switch to "Cumulative" view
2. Click to expand the campaign
3. Compare "Booked" and "Call" numbers for each ad
4. Identify top-performing ads

### Use Case 3: Funnel Analysis
**Question**: "What percentage of booked appointments actually call?"
1. Switch to "Cumulative" view
2. Compare "Booked" vs "Call" columns
3. Calculate conversion rate: (Call / Booked) × 100%

---

## ⚙️ Technical Details

### Backend Implementation:
- **Firebase Function**: `/api/ghl/analytics/pipeline-performance-cumulative`
- **Firestore Collection**: `opportunityStageHistory`
- **Sync Endpoint**: `/api/ghl/sync-opportunity-history`
- **Data Source**: GoHighLevel API + Firestore tracking

### Data Flow:
1. **Sync**: Fetches opportunities from GoHighLevel API
2. **Store**: Saves stage transitions to Firestore
3. **Calculate**: Aggregates cumulative metrics by campaign
4. **Display**: Shows in Flutter UI table

### Attribution Data:
- **Campaign Name**: From `utmCampaign` parameter
- **Campaign Source**: From `utmSource` parameter
- **Campaign Medium**: From `utmMedium` parameter
- **Ad ID**: From `utmAdId` or `utmContent` parameter

---

## 🛠️ Troubleshooting

### Problem: "No campaign data available"
**Solution**: 
- Click the Sync button first
- Ensure opportunities have UTM campaign attribution
- Check that opportunities are within the selected timeframe

### Problem: Numbers seem low
**Reason**: 
- Cumulative view only tracks opportunities **with campaign attribution**
- Opportunities without UTM parameters are excluded
- This is intentional - it only tracks ad-driven leads

### Problem: Sync fails with 500 error
**Solution**: 
- Check Firebase Functions logs
- Ensure you're logged into the correct Firebase project
- Verify GoHighLevel API credentials are valid

---

## 📈 Future Enhancements (Optional)

Potential improvements for future consideration:
- Export campaign data to CSV/Excel
- Add date range picker for custom timeframes
- Show conversion rates as percentages
- Add monetary value tracking per campaign
- Create campaign comparison charts
- Email campaign performance reports

---

## ✅ Summary

**Your cumulative campaign metrics feature is fully functional!**

To use it:
1. Click **Sync button** (first time only)
2. Toggle to **Cumulative view**
3. Review **campaign performance** in the table
4. Expand campaigns to see **individual ads**
5. Filter by **timeframe** as needed

The system automatically tracks all stage transitions and calculates cumulative totals, giving management clear visibility into how each ad campaign performs over time.

**No additional setup required - it just works!** 🎉

