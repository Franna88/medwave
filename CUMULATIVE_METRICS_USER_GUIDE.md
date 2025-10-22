# Cumulative Metrics Tracking - User Guide

## Overview

The MedWave application now supports **two view modes** for advertisement performance tracking:

1. **Snapshot View** (Default) - Shows current opportunities in each pipeline stage
2. **Cumulative View** (New) - Shows total opportunities that have ever reached each stage

## Key Differences

### Snapshot View
- **What it shows**: Current number of opportunities in each stage RIGHT NOW
- **Example**: 10 opportunities currently in "Booked" stage
- **Behavior**: Numbers decrease when opportunities move to the next stage
- **Use case**: See current pipeline state and active workload

### Cumulative View  
- **What it shows**: Total number of opportunities that have EVER reached each stage
- **Example**: 50 opportunities have reached "Booked" at some point
- **Behavior**: Numbers NEVER decrease, only accumulate
- **Use case**: Track ad effectiveness and historical conversion rates

## How to Use

### Switching Between Views

1. Open the **Advertisement Performance** screen (Admin > Adverts)
2. Look for the view mode toggle buttons below the header
3. Click either:
   - **Snapshot** button (camera icon) - for current pipeline state
   - **Cumulative** button (chart icon) - for historical totals

### First Time Setup (Cumulative View)

Before using cumulative view for the first time:

1. Click the **Sync** button (circular arrows icon) in the top-right corner
2. Wait for the sync to complete (shows a loading spinner)
3. The system will fetch all current opportunities from GoHighLevel
4. Only opportunities with UTM campaign data will be tracked
5. After sync completes, switch to Cumulative view

### Syncing Data

The **Sync** button does the following:
- Fetches all current opportunities from both Altus and Andries pipelines
- Stores stage transitions in Firestore for historical tracking
- Skips opportunities without campaign attribution
- Shows statistics: total, synced, skipped, errors

**When to sync:**
- Before viewing cumulative metrics for the first time
- After running new ad campaigns
- When you want to update historical data with recent changes
- Recommended: Once per day or when launching new campaigns

### Date Range Filtering

Both view modes support date filtering:
- **Last 7 Days**
- **Last 30 Days** (default)
- **Last 3 Months**
- **Last Year**

**Important:** Date filtering applies to when the opportunity was CREATED, not when it entered a specific stage.

## Understanding Cumulative Metrics

### Example Scenario

An opportunity "John Smith" progresses through the pipeline:

1. **Day 1**: Created with UTM campaign data → enters "Booked" stage
2. **Day 3**: Moved to "Call" stage
3. **Day 5**: Moved to "Deposit" stage

**Snapshot View (Day 5):**
- Booked: 0
- Call: 0  
- Deposit: 1

**Cumulative View (Day 5):**
- Booked: 1 (John entered this stage)
- Call: 1 (John entered this stage)
- Deposit: 1 (John entered this stage)

### Reading the Numbers

Cumulative numbers show:
- **Total reach**: How many opportunities reached each stage
- **Funnel progression**: Compare stages to see drop-off rates
- **Ad performance**: Track which campaigns generate opportunities that progress

## Technical Details

### What Gets Tracked

✅ **Included:**
- Opportunities from Altus pipeline
- Opportunities from Andries pipeline  
- Only opportunities with UTM campaign data (ads)
- Stage transitions (when an opportunity moves between stages)

❌ **Excluded:**
- Opportunities without campaign attribution
- Non-ad opportunities (manually created)
- Erich pipeline (separate tracking)

### Data Storage

- **Snapshot View**: Queries GoHighLevel API directly (real-time)
- **Cumulative View**: Reads from Firestore collection `opportunityStageHistory`
- **Sync Frequency**: On-demand only (manual sync button)
- **Data Retention**: All synced data is stored permanently in Firestore

### Limitations

1. **No Historical Backfill**: 
   - GoHighLevel audit logs are not accessible via API
   - Tracking starts from the first sync forward
   - Cannot retroactively track opportunities from before the first sync

2. **Manual Sync Required**:
   - Cumulative data updates only when sync button is clicked
   - Not automatic or webhook-based
   - Plan to sync regularly for accurate data

3. **Campaign Attribution Only**:
   - Only tracks opportunities with UTM parameters
   - Non-ad opportunities are excluded from cumulative view
   - Ensures accurate ad performance measurement

## Troubleshooting

### "0 opportunities" in Cumulative View

**Solution**: Click the Sync button to populate historical data for the first time.

### Numbers Don't Match Between Views

**This is expected!** 
- Snapshot = current state
- Cumulative = historical totals
- Cumulative numbers will always be equal to or higher than snapshot numbers

### Sync Button Shows Error

**Possible causes:**
- Network connection issue
- Firebase Functions not deployed
- GoHighLevel API issue

**Solutions:**
1. Check internet connection
2. Try refreshing the page
3. Wait a few minutes and try again
4. Contact system administrator if persists

### Missing Recent Opportunities

**Solution**: Click the Sync button to pull latest data from GoHighLevel.

## Best Practices

1. **Sync regularly**: Click sync button at least once per day
2. **Use snapshot for operations**: Day-to-day pipeline management
3. **Use cumulative for analytics**: Campaign performance and ROI analysis
4. **Compare timeframes**: Use date filters to analyze campaign periods
5. **Monitor both views**: Get complete picture of pipeline health

## FAQ

**Q: Which view should I use?**  
A: Use Snapshot for daily operations, Cumulative for campaign analysis and historical trends.

**Q: How often does data update?**  
A: Snapshot updates every 5 minutes automatically. Cumulative updates only when you click Sync.

**Q: Can I see data from last year?**  
A: Only if you've been syncing regularly. Cumulative tracking starts from your first sync.

**Q: Why don't I see all my opportunities?**  
A: Only opportunities with UTM campaign data are included in cumulative tracking.

**Q: Can I export cumulative data?**  
A: Not yet - feature coming soon. Currently view-only in the application.

## Support

For technical issues or questions:
- Check the Developer Implementation Checklist
- Review Firebase Functions logs
- Contact the development team
- Refer to CUMULATIVE_METRICS_SETUP.md for technical details

