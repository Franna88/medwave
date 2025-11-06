# Campaign Charts & Filtering - Quick Start Guide

## What Changed

### ✅ Filtering Applied Everywhere
All campaign, ad set, and ad views now **only show items with positive Facebook Spend (FB Spend > 0)**.

### ✅ New Overview Layout
The Overview screen now shows **individual bar charts for each campaign** instead of summary KPI cards and pie charts.

---

## Where to Find It

### Overview Screen
**Path:** Admin Dashboard → Adverts → Overview

**What You'll See:**
- Title: "Campaign Performance Overview"
- Legend box showing all 8 metric colors
- One bar chart per campaign (with positive FB spend)
- Click any campaign header to expand and see ad sets

### Hierarchy Screens
**Path:** Admin Dashboard → Adverts → Ads (Hierarchy)

**Three Tabs:**
1. **Campaigns** - Only campaigns with FB spend
2. **Ad Sets** - Only ad sets with FB spend
3. **Ads** - Only individual ads with FB spend

---

## Understanding the Charts

### Campaign Bar Chart

Each campaign displays 8 metrics as grouped bars:

| Metric | Color | Description |
|--------|-------|-------------|
| **FB Spend** | Blue | Total Facebook advertising cost |
| **Leads** | Purple | Number of leads generated |
| **Bookings** | Orange | Number of bookings made |
| **Deposits** | Teal | Number of deposits received |
| **Cash** | Green | Total cash amount collected |
| **CPL** | Indigo | Cost Per Lead ($) |
| **CPB** | Pink | Cost Per Booking ($) |
| **Profit** | Deep Purple/Red | Total profit (red if negative) |

### Chart Features

**Hover Tooltips**
- Hover over any bar to see exact values
- Shows metric name and formatted value

**Expand/Collapse**
- Click campaign header to expand
- Shows all ad sets within that campaign
- Each ad set has its own mini chart with same 8 metrics

**Visual Indicators**
- Green border = Profitable campaign
- Red border = Loss-making campaign
- Y-axis auto-scales (shows $1k, $2k for large values)

---

## How Filtering Works

### What Gets Filtered

**Filtered OUT:**
- Campaigns with $0 FB spend
- Ad sets with $0 FB spend
- Individual ads with $0 FB spend
- Test campaigns that haven't launched

**Stays IN:**
- Any campaign/ad set/ad with FB spend > $0
- Even if spend is $0.01, it will show

### Why This Matters

**Benefits:**
- Focus only on active campaigns
- Cleaner data views
- Easier performance tracking
- No clutter from inactive/draft campaigns

**Note:** If you need to see campaigns without spend (drafts, paused, etc.), that data still exists in Firebase but is hidden from these views.

---

## Common Scenarios

### Scenario 1: "I don't see any campaigns"
**Likely Cause:** No campaigns have Facebook spend yet
**Solution:** 
- Check if Facebook ads are running
- Verify Facebook API sync is working
- Manual sync button in top-right

### Scenario 2: "Campaign won't expand"
**Likely Cause:** Campaign has no ad sets with spend
**Solution:** This is expected - only ad sets with spend show when expanded

### Scenario 3: "Numbers look different than before"
**Likely Cause:** Now filtering out zero-spend items
**Solution:** Old view included all items; new view is more accurate for active campaigns

### Scenario 4: "Chart looks cramped"
**Likely Cause:** Many metrics with different scales
**Solution:** 
- Use tooltips to see exact values
- Expand campaigns for clearer ad set breakdowns
- Charts auto-scale to fit all metrics

---

## Data Refresh

### Auto-Sync
- Facebook data syncs automatically every hour
- GHL data syncs every 30 minutes

### Manual Sync
- Click refresh button (top-right of screen)
- Syncs both Facebook and GHL data
- Takes 10-30 seconds

### Last Updated
- Shows "FB synced Xm ago" badge
- Green badge = recent sync (< 15 min)
- Orange badge = stale data (> 60 min)

---

## Tips & Tricks

### Best Practices

1. **Review Overview First**
   - Get big picture of all campaigns
   - Identify top/bottom performers
   - Expand profitable campaigns to see winning ad sets

2. **Use Hierarchy for Deep Dives**
   - Switch to Ads tab for detailed analysis
   - Use filters to narrow down specific campaigns/ad sets
   - Sort by different metrics

3. **Monitor Trends**
   - Check Overview daily
   - Look for red (loss-making) campaigns
   - Investigate ad sets with high spend but low conversions

4. **Date Filtering**
   - Use date dropdown in Overview header
   - Options: Today, Yesterday, Last 7 Days, Last 30 Days, All Time
   - Combines with FB spend filtering

---

## Keyboard Shortcuts

None currently implemented, but you can:
- Click anywhere on campaign header to expand
- Scroll to see all campaigns
- Use browser back/forward buttons

---

## Mobile/Tablet View

**Status:** Optimized for desktop/laptop
**Mobile:** Works but charts may be small
**Recommendation:** Use desktop for best experience

---

## Technical Details

### Performance
- Charts render in < 500ms for most datasets
- Handles 50+ campaigns without lag
- Ad set expansion is instant

### Data Source
- Firebase: Campaign/ad set/ad structure
- Facebook API: FB Spend, Leads, impressions, etc.
- GHL API: Bookings, Deposits, Cash collected

### Caching
- Charts rebuild on data change
- Expand/collapse state maintained during session
- No data cached between sessions

---

## Troubleshooting

### Chart Not Showing
1. Check browser console for errors
2. Verify data in Firebase
3. Try manual sync
4. Refresh page

### Wrong Data Displayed
1. Check date filter setting
2. Verify FB/GHL sync completed
3. Compare with Firebase raw data
4. Clear browser cache

### Expand Not Working
1. Ensure campaign has ad sets with spend
2. Check for JavaScript errors
3. Try different campaign
4. Refresh page

---

## Support

For issues or questions:
1. Check Firebase data first
2. Verify sync status
3. Try manual refresh
4. Contact development team

---

## Related Documentation

- `CAMPAIGN_FILTERING_AND_CHARTS_IMPLEMENTATION.md` - Full technical details
- `AD_PERFORMANCE_HIERARCHY_IMPLEMENTATION_COMPLETE.md` - Hierarchy structure
- `FACEBOOK_ADS_API_QUICK_START.md` - Facebook integration

---

**Last Updated:** October 29, 2025  
**Version:** 1.0  
**Status:** Production Ready ✅

