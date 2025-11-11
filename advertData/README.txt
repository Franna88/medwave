================================================================================
ADVERTDATA COLLECTION - DOCUMENTATION
================================================================================

OVERVIEW
========
This folder contains documentation for the advertData collection system,
which automatically syncs Facebook ads and insights with GHL data.

WHAT IS ADVERTDATA?
===================
advertData is a Firebase Firestore collection that stores:

1. Facebook Ads (from last 6 months)
   - Campaign info, ad set info, ad details
   
2. Facebook Insights (weekly breakdown)
   - Subcollection: insights/{weekId}
   - Metrics: spend, impressions, clicks, reach, CPM, CPC, CTR
   
3. GHL Data (weekly breakdown)
   - Subcollection: ghlWeekly/{weekId}
   - Metrics: leads, booked appointments, deposits, cash collected

STRUCTURE
=========
advertData/
  {adId}/                          <- Main ad document
    - campaignId
    - campaignName
    - adSetId
    - adSetName
    - adId
    - adName
    - lastFacebookSync
    - lastGHLSync
    
    insights/                      <- Facebook weekly insights
      {weekId}/                    <- e.g., "2025-11-03_2025-11-09"
        - dateStart
        - dateStop
        - spend
        - impressions
        - reach
        - clicks
        - cpm, cpc, ctr
        
    ghlWeekly/                     <- GHL weekly data
      {weekId}/                    <- e.g., "2025-11-03_2025-11-09"
        - leads
        - bookedAppointments
        - deposits
        - cashCollected
        - cashAmount

AUTOMATED SYNC
==============
Cloud Function: scheduledFacebook6MonthSync
Schedule: Every 1 hour
Purpose: Fetch Facebook ads and insights from last 6 months

Features:
- ✅ Automatic hourly sync
- ✅ Rate limit handling with checkpoint/resume
- ✅ Duplicate prevention
- ✅ Progress tracking in Firestore
- ✅ No manual intervention needed

DOCUMENTATION FILES
===================
1. MONITORING_GUIDE.txt
   - Complete guide for monitoring the sync system
   - How to check logs, progress, errors
   - Troubleshooting steps
   
2. QUICK_REFERENCE.txt
   - Quick commands and links
   - Fast status checks
   - Essential information

3. README.txt (this file)
   - Overview and structure
   - Getting started

GETTING STARTED
===============
1. View current status:
   cd /Users/mac/dev/medwave
   python3 advertdata_final_status.py

2. Check if sync is running:
   firebase functions:log --only scheduledFacebook6MonthSync

3. View data in Firebase Console:
   https://console.firebase.google.com/project/medx-ai/firestore/data/~2FadvertData

MONITORING
==========
See MONITORING_GUIDE.txt for detailed monitoring instructions.

Quick check:
- Firestore checkpoint: system/facebook6MonthSyncCheckpoint
- Function logs: firebase functions:log --only scheduledFacebook6MonthSync
- Data collection: advertData (in Firestore)

SCRIPTS
=======
Located in: /Users/mac/dev/medwave/

Python Scripts:
- fetch_facebook_6_months.py - Manual sync script with checkpoint/resume
- advertdata_final_status.py - View current status and statistics
- verify_backfill_results.py - Verify data quality
- populate_ghl_data.py - Populate GHL data from API

Cloud Function:
- functions/lib/facebook6MonthSync.js - Automated sync service
- functions/index.js - Scheduled function definition

TIMELINE
========
Initial Setup: November 9, 2025
Estimated Completion: 1-2 days (15-25 hours)
Maintenance: Automatic (runs every hour)

STATUS
======
✅ Cloud Function deployed
✅ Checkpoint system active
✅ Automatic hourly sync running
✅ 90 ads processed (as of last checkpoint)
✅ Progress: Campaign 11/100

NEXT STEPS
==========
1. Monitor progress using MONITORING_GUIDE.txt
2. Wait for automatic completion (1-2 days)
3. Verify data quality after completion
4. System will continue updating hourly

SUPPORT
=======
Firebase Console: https://console.firebase.google.com/project/medx-ai
Function Logs: https://console.cloud.google.com/logs/query
Firestore Data: https://console.firebase.google.com/project/medx-ai/firestore

================================================================================
Last Updated: November 9, 2025
System Version: 1.0
Status: Active and Running
================================================================================

