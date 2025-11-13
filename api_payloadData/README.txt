================================================================================
API PAYLOAD DATA - COMPLETE ANALYSIS
================================================================================
Date: November 13, 2025
Purpose: Complete documentation of all available data from Facebook and GHL APIs

================================================================================
CONTENTS
================================================================================

FACEBOOK ADS API:
-----------------
1. FACEBOOK_AD_DATA_SUMMARY.txt
   - Complete analysis of Facebook Marketing API
   - All available fields and data structures
   - Sample payloads and recommendations
   - Integration guidance

2. facebook_ad_complete_payload.txt
   - Raw API responses from Facebook
   - Real ad data with performance metrics
   - Daily breakdown examples
   - Complete insights payload

3. inspect_facebook_ad_data.py
   - Script to inspect any Facebook ad
   - Fetches complete ad details and insights
   - Can be run anytime to check current data

4. inspect_ad_with_data.py
   - Script to find ads with performance data
   - Automatically selects ad with most spend
   - Shows daily breakdown and all metrics

GHL (GOHIGHLEVEL) API:
----------------------
1. GHL_API_DATA_SUMMARY.txt
   - Complete analysis of GHL APIs
   - Opportunities, Contacts, Form Submissions
   - Attribution data structures
   - Pipeline stage mappings
   - Integration guidance

2. ghl_opportunities_complete_payload.txt
   - Raw API responses from Opportunities API
   - Sample opportunities with monetary values
   - Pipeline and stage information
   - Attribution data examples

3. ghl_contacts_complete_payload.txt
   - Raw API responses from Contacts API
   - Contact details and basic attribution
   - Form submissions with complete attribution
   - Facebook ad_id extraction examples

4. inspect_ghl_opportunities.py
   - Script to inspect GHL opportunities
   - Fetches opportunities with monetary values
   - Shows complete field structure
   - Can be run anytime to check current data

5. inspect_ghl_contacts.py
   - Script to inspect GHL contacts and form submissions
   - Shows attribution data structure
   - Extracts ad_id from form submissions
   - Can be run anytime to check current data

================================================================================
KEY FINDINGS
================================================================================

FACEBOOK ADS API:
-----------------
✅ Provides complete performance metrics (impressions, clicks, spend, etc.)
✅ Includes conversion data via actions array
✅ Lead count available as action_type: "lead"
✅ Cost per lead in cost_per_action_type array
✅ Daily breakdown for trend analysis
✅ Video engagement metrics (25%, 50%, 75%, 100% completion)
✅ Complete targeting and creative information

GHL API:
--------
✅ Opportunities API: Pipeline stages, monetary values, limited attribution
✅ Contacts API: Contact details, basic attribution (rarely has ad_id)
✅ Form Submissions API: ⭐ SOURCE OF TRUTH for Facebook attribution
   - Contains ad_id, campaign_id, adset_id for ALL Facebook leads
   - 73.8% of opportunities can be matched using this API
   - 99.3% match rate for recent data (last 2 months)

CRITICAL INSIGHT:
-----------------
⭐ Form Submissions API is the ONLY reliable source for Facebook ad_id
⭐ Opportunities and Contacts APIs rarely have ad_id populated
⭐ Must use Form Submissions to match GHL opportunities to Facebook ads

================================================================================
HOW TO USE THESE SCRIPTS
================================================================================

FACEBOOK ADS:
-------------
# Inspect a specific ad
python3 inspect_facebook_ad_data.py

# Find ads with performance data
python3 inspect_ad_with_data.py

GHL:
----
# Inspect opportunities
python3 inspect_ghl_opportunities.py

# Inspect contacts and form submissions
python3 inspect_ghl_contacts.py

All scripts save output to .txt files for review.

================================================================================
INTEGRATION SUMMARY
================================================================================

CURRENT FLOW (WORKING):
------------------------
1. Facebook Lead Form → GHL Webhook → GHL Contact Created
2. GHL Forms Submissions API → Extract ad_id
3. Match GHL Opportunity to Facebook Ad using contactId → ad_id mapping
4. Store in Firebase ghlOpportunities collection with assignedAdId
5. Aggregate metrics at ad, ad set, and campaign levels
6. Display in Flutter UI with combined Facebook + GHL data

RESULT:
-------
✅ 960 opportunities matched (73.8% overall, 99.3% recent)
✅ NO cross-campaign duplicates
✅ Each opportunity assigned to exactly ONE ad
✅ Complete ROI calculation (Facebook spend + GHL revenue)
✅ Loading performance: <500ms (360x faster than old structure)

================================================================================
REFERENCE FILES
================================================================================

In ghl_info/ folder:
- pipeline_stage_mappings.json - Stage ID to stage name mappings
- QUICK_REFERENCE.txt - Quick API reference
- GHL_OPPORTUNITY_API_REFERENCE.txt - Complete API docs
- STAGE_MAPPING_SOLUTION.txt - Stage mapping implementation

In advertData/ folder:
- ADVERTDATA_IMPLEMENTATION_SESSION_SUMMARY.md - Complete implementation history

================================================================================
NEXT STEPS
================================================================================

If you need to:
1. Check what data is available from APIs → Read the SUMMARY.txt files
2. See actual API responses → Read the complete_payload.txt files
3. Inspect current data → Run the inspect_*.py scripts
4. Understand integration → Read ADVERTDATA_IMPLEMENTATION_SESSION_SUMMARY.md
5. Look up stage IDs → Check ghl_info/pipeline_stage_mappings.json

================================================================================
END OF README
================================================================================

