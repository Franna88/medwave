# Cumulative Metrics - Quick Start Guide

## What's New?

MedWave now has **two ways** to view ad performance:

1. **Snapshot View** (Default) - Current pipeline state
2. **Cumulative View** (New) - Historical stage totals

## 5-Minute Setup

### Step 1: Open the App
Navigate to: **Admin** → **Adverts** (Advertisement Performance)

### Step 2: First-Time Sync
1. Click the **Sync** button (🔄 circular arrows icon) in top-right corner
2. Wait 10-30 seconds for sync to complete
3. You'll see a message showing how many opportunities were synced

### Step 3: Switch to Cumulative View
1. Look for the toggle buttons below the header
2. Click **Cumulative** (📊 chart icon)
3. View changes to show cumulative totals

### Step 4: Explore the Data
- Use timeframe dropdown (Last 7 Days, Last 30 Days, etc.)
- Compare Snapshot vs Cumulative by switching back and forth
- Sync regularly to keep cumulative data up-to-date

## Key Differences at a Glance

| Aspect | Snapshot View | Cumulative View |
|--------|--------------|-----------------|
| **What it shows** | Current opportunities in each stage | Total opportunities that ever reached each stage |
| **When numbers change** | Constantly (as opportunities move) | Only increases (never decreases) |
| **Data updates** | Automatic (every 5 min) | Manual (click sync button) |
| **Best for** | Daily operations & workload | Campaign analysis & ROI |
| **Example** | 10 in "Booked" right now | 50 have reached "Booked" total |

## Quick Example

Your ad generates 20 opportunities this month. They all start in "Booked" stage:

**Week 1**: All 20 in Booked
- Snapshot: Booked = 20
- Cumulative: Booked = 20

**Week 2**: 15 moved to Call, 5 still in Booked  
- Snapshot: Booked = 5, Call = 15
- Cumulative: Booked = 20, Call = 15

**Week 3**: 10 moved to Deposit, 5 still in Call, 5 still in Booked
- Snapshot: Booked = 5, Call = 5, Deposit = 10
- Cumulative: Booked = 20, Call = 15, Deposit = 10

**Key Insight**: Cumulative shows you that your ad successfully moved 15 people to call stage, even though only 5 are currently there!

## When to Use Each View

### Use Snapshot View When:
- Managing daily operations
- Assigning follow-ups to team members
- Checking current workload
- Seeing what needs attention NOW

### Use Cumulative View When:
- Analyzing ad campaign performance
- Calculating conversion rates
- Comparing different campaigns
- Reporting to stakeholders
- Tracking long-term trends

## Pro Tips

1. **Sync Daily**: Click sync button once per day to maintain accurate historical data
2. **Before Analysis**: Always sync before reviewing cumulative metrics
3. **Compare Timeframes**: Use date filters to analyze specific campaign periods
4. **Watch for Drops**: Large difference between stages shows where people drop off
5. **Campaign Attribution**: Only ad-driven opportunities (with UTM data) are tracked

## Troubleshooting

**Problem**: Cumulative view shows 0 opportunities  
**Solution**: Click the Sync button (first-time setup required)

**Problem**: Numbers look wrong  
**Solution**: Remember - cumulative numbers are ALWAYS higher than or equal to snapshot

**Problem**: Data seems old  
**Solution**: Click Sync button to pull latest data from GoHighLevel

## Need Help?

- 📖 Full User Guide: `CUMULATIVE_METRICS_USER_GUIDE.md`
- 🔧 Technical Details: `CUMULATIVE_METRICS_IMPLEMENTATION_COMPLETE.md`  
- 📋 Implementation Plan: `cumulative-ad-metrics-tracking.plan.md`

## That's It! 🎉

You're ready to use cumulative metrics tracking. Start with a sync, switch views, and explore your data!

