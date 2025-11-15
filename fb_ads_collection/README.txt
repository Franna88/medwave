Facebook Ads Collection Scripts
================================

This folder contains scripts to fetch Facebook ads data and store them in Firestore.

COLLECTION STRUCTURE:
--------------------
Collection Name: fb_ads
Document ID: adId (e.g., "120233712971960335")

Each document contains:
- adId: The Facebook ad ID
- adName: Name of the ad
- status: Ad status
- effectiveStatus: Effective status
- adDetails: Complete ad details (campaign, adset, creative, targeting, tracking specs)
- insights: Array of insight records with all metrics (impressions, spend, clicks, etc.)
- fetchedAt: Timestamp when data was fetched
- month: Month name (e.g., "November")
- year: Year (e.g., 2025)
- dateRange: {start: "YYYY-MM-DD", end: "YYYY-MM-DD"}

SCRIPTS:
--------
1. facebook_Nov.py - Fetches all ads for November 2025

USAGE:
------
1. Ensure you have a valid Facebook access token in the script
2. Run: python3 facebook_Nov.py
3. The script will:
   - Validate the token
   - Fetch all ads that ran in November 2025
   - Fetch complete details and insights for each ad
   - Store everything in the fb_ads collection

FUTURE MONTHS:
--------------
To fetch data for other months:
1. Copy facebook_Nov.py to facebook_Dec.py (or other month)
2. Update START_DATE and END_DATE in the script
3. Update the month name in the complete_ad_data dictionary
4. Run the script

NOTES:
------
- Each ad is stored with its full payload from Facebook API
- Insights include daily breakdown of all metrics
- Ad details include campaign, adset, creative, and targeting information
- The script handles pagination automatically
- Rate limiting is built in (0.5 second delay between requests)
- Token validation happens before fetching data

FIRESTORE LOCATION:
-------------------
Firebase Console: https://console.firebase.google.com/project/medx-ai/firestore
Collection Path: /fb_ads/{adId}

Example Document Path:
/fb_ads/120233712971960335

TOKEN MANAGEMENT:
-----------------
If you get a token error:
1. Go to: https://developers.facebook.com/tools/explorer/
2. Select your app
3. Generate new token with permissions: ads_read, read_insights
4. Update FB_ACCESS_TOKEN in the script

