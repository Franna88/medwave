SUMMARY COLLECTION SCRIPTS
==========================

This folder contains all scripts related to building and managing the summary collection.

MAIN SCRIPT
-----------
rebuild_summary_from_firebase.py
  - Rebuilds summary collection using ONLY Firebase data (no API calls)
  - Data sources: fb_ads, ghl_data, ghl_opportunities
  - Processes October and November 2025
  - Creates exact same structure as existing summary collection

USAGE
-----

1. Dry Run (preview without writing):
   python3 rebuild_summary_from_firebase.py --dry-run

2. Process October only:
   python3 rebuild_summary_from_firebase.py --october

3. Process November only:
   python3 rebuild_summary_from_firebase.py --november

4. Process both months (default):
   python3 rebuild_summary_from_firebase.py

5. Process both with explicit flag:
   python3 rebuild_summary_from_firebase.py --all

DATA FLOW
---------

1. FB_ADS COLLECTION
   - Load all fb_ads documents
   - Extract insights array (daily data)
   - Group by week (Monday-Sunday)
   - Aggregate: spend, impressions, reach, clicks
   - Calculate: CPM, CPC, CTR

2. GHL_DATA COLLECTION
   - Load all ghl_data documents
   - Extract contactId -> adId mappings
   - Used for matching opportunities to ads

3. GHL_OPPORTUNITIES COLLECTION
   - Load all opportunities
   - Match to ads using:
     a) assignedAdId field (primary)
     b) contactId lookup in ghl_data (fallback)
   - Group by week based on createdAt date
   - Count by stage:
     - leads: all opportunities
     - bookedAppointments: stage contains "book" or "appointment"
     - deposits: stage contains "deposit"
     - cashCollected: stage contains "cash" or "collected"
   - Sum monetary values for deposits and cash collected

4. SUMMARY STRUCTURE
   - Campaign level (top)
     - Campaign ID and name
     - Weeks map:
       - Week ID (YYYY-MM-DD_YYYY-MM-DD)
       - Month name and date range
       - Campaign totals for week
       - Ad Sets map (aggregated from ads)
       - Ads map (individual ad data)

OUTPUT STRUCTURE
----------------

summary/{campaignId}
  campaignId: string
  campaignName: string
  weeks: {
    "2025-10-27_2025-11-02": {
      month: "October 2025"
      dateRange: "27 Oct 2025 - 02 Nov 2025"
      weekNumber: 5
      campaign: {
        campaignId: string
        campaignName: string
        facebookInsights: {
          spend: number
          impressions: number
          reach: number
          clicks: number
          cpm: number
          cpc: number
          ctr: number
        }
        ghlData: {
          leads: number
          bookedAppointments: number
          deposits: number
          cashCollected: number
          cashAmount: number
        }
      }
      adSets: {
        {adSetId}: {
          adSetId: string
          adSetName: string
          facebookInsights: {...}
          ghlData: {...}
        }
      }
      ads: {
        {adId}: {
          adId: string
          adName: string
          facebookInsights: {...}
          ghlData: {...}
        }
      }
    }
  }

ADVANTAGES OF THIS APPROACH
----------------------------

1. No API calls - faster and no rate limits
2. Uses existing Firebase data
3. Consistent with current data structure
4. Can be run multiple times (idempotent)
5. Supports dry-run for testing
6. Processes specific months or all months
7. Automatically handles missing data gracefully

RELATED FILES
-------------

Original scripts (for reference):
- create_weekly_summary_collection.py (uses API calls)
- update_summary_with_ghl_data.py (updates existing summary)
- investigate_ghl_summary_data.py (diagnostic tool)

Dart service:
- lib/services/firebase/summary_service.dart (reads summary collection)

