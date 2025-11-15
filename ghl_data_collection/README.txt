GHL Data Collection Scripts
===========================

This folder contains scripts to fetch GHL (GoHighLevel) form submissions and store them in Firestore.

COLLECTION STRUCTURE:
--------------------
Collection Name: ghl_data
Document ID: adId (Facebook Ad ID, e.g., "120235556204840335")

Each document contains:
- submissionId: GHL submission ID
- contactId: GHL contact ID
- formId: GHL form ID
- name: Contact name
- email: Contact email
- adId: Facebook ad ID (document ID)
- createdAt: Submission timestamp
- fullSubmission: Complete GHL API payload
- attribution: Extracted attribution data (campaign, adset, utm params)
- fetchedAt: When data was fetched
- month: Month name (e.g., "November")
- year: Year (e.g., 2025)
- dateRange: {start, end}

SUBCOLLECTIONS:
--------------
If multiple submissions exist for the same adId:
ghl_data/{adId}/submissions/{submissionId}

SCRIPTS:
--------
1. ghl_Nov.py - Fetches all form submissions for November 2025

PAYLOAD DOCUMENTATION:
---------------------
- ghl_contacts_complete_payload.txt - GHL Contacts API structure
- ghl_form_submissions_complete_payload.txt - GHL Form Submissions API structure (MAIN REFERENCE)
- ghl_opportunities_complete_payload.txt - GHL Opportunities API structure

USAGE:
------
1. Ensure you have valid GHL API credentials in the script
2. Run: python3 ghl_Nov.py
3. The script will:
   - Fetch all form submissions from November 2025
   - Filter submissions that have Facebook ad attribution
   - Extract adId from submissions
   - Store in ghl_data collection with adId as document ID

FUTURE MONTHS:
--------------
To fetch data for other months:
1. Copy ghl_Nov.py to ghl_Dec.py (or other month)
2. Update START_DATE and END_DATE
3. Update month name in the document data
4. Run the script

KEY FEATURES:
-------------
- Handles pagination automatically
- Rate limiting built in (0.5 second delay + 60s on rate limit)
- Stores complete payload for full data access
- Extracts attribution data for easy querying
- Only stores submissions with Facebook ad attribution
- Handles multiple submissions per ad (subcollections)

AD ID EXTRACTION:
-----------------
The script tries two locations for adId:
1. PRIMARY: others.lastAttributionSource.adId
2. FALLBACK: others.eventData.url_params.ad_id

FILTERING:
----------
Only submissions with adId are stored because:
- These are Facebook lead form submissions
- They can be linked to Facebook ads in fb_ads collection
- Website forms without adId are not relevant for ad performance

FIRESTORE LOCATION:
-------------------
Firebase Console: https://console.firebase.google.com/project/medx-ai/firestore
Collection Path: /ghl_data/{adId}

Example Document Path:
/ghl_data/120235556204840335

LINKING DATA:
-------------
To link GHL submissions to Facebook ads:
1. Query ghl_data collection by adId
2. Match with fb_ads collection (same adId)
3. Combine GHL lead data with Facebook ad performance

NOTES:
------
- Submissions without adId are counted but not stored
- These are typically website forms or manual entries
- The fullSubmission field contains the complete GHL API response
- Attribution data is extracted for easier querying

