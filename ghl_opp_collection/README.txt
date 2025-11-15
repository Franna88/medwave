====================================================================================================
GHL OPPORTUNITIES COLLECTION - NOVEMBER 2025
====================================================================================================

OVERVIEW:
---------
This script fetches all GHL opportunities for November 2025 and stores the complete payload
in Firestore collection "ghl_opportunities" with contactId as the document ID.

SCRIPT:
-------
ghl_opportunities_Nov.py

FIRESTORE COLLECTION:
---------------------
Collection Name: ghl_opportunities
Document ID: contactId (e.g., "srKrKjdbJeF9LG5LEK5b")

DATA SOURCE:
------------
API Endpoint: https://services.leadconnectorhq.com/opportunities/search
Method: GET
Pagination: Page-based (page parameter)
Date Filtering: Client-side (by createdAt field)

WHAT IT DOES:
-------------
1. Fetches ALL opportunities from GHL Opportunities API
2. Filters for opportunities created in November 2025 (by createdAt)
3. Filters for ONLY Andries and Davide pipelines (excludes Erich and others)
4. Adds stageName field with human-readable stage name
5. Stores each opportunity with contactId as document ID
6. Includes complete GHL opportunity payload in fullOpportunity field

KEY FIELDS EXTRACTED:
---------------------
- opportunityId: Unique opportunity ID
- contactId: Contact ID (used as document ID)
- name: Opportunity name
- contactName: Associated contact name
- contactEmail: Contact email
- contactPhone: Contact phone
- monetaryValue: Opportunity value in cents
- pipelineId: Pipeline ID (Andries or Davide)
- pipelineStageId: Current stage ID
- stageName: Human-readable stage name (e.g., "Deposit Received", "Cash Collected")
- status: Opportunity status (open/won/lost)
- source: Opportunity source
- createdAt: Creation timestamp
- updatedAt: Last update timestamp
- attributions: Attribution data array
- fullOpportunity: Complete GHL API response

CONFIGURATION:
--------------
API Key: pit-22f8af95-3244-41e7-9a52-22c87b166f5a
Location ID: QdLXaFEqrdF0JbVbpKLw
API Version: 2021-07-28
Date Range: 2025-11-01 to 2025-11-30
Pipelines: 
  - Andries: XeAGJWRnUGJ5tuhXam2g
  - Davide: AUduOJBB2lxlsEaNmlJz

HOW TO RUN:
-----------
cd /Users/mac/dev/medwave/ghl_opp_collection
python3 ghl_opportunities_Nov.py

IMPORTANT NOTES:
----------------
1. ONLY stores Andries and Davide pipeline opportunities (Erich excluded)
2. Uses contactId as document ID (one opportunity per contact)
3. If a contact has multiple opportunities, only the last one will be stored
4. Opportunities without contactId are skipped
5. Client-side filtering by createdAt date
6. Complete payload stored in fullOpportunity field
7. Monetary values in cents (divide by 100 for currency)
8. stageName field automatically mapped from pipelineStageId

REFERENCE FILES:
----------------
- ghl_opportunities_complete_payload.txt: Complete API payload structure
- STRUCTURE_EXAMPLE.txt: Firestore document structure example

RELATED COLLECTIONS:
--------------------
- ghl_data: Form submissions (by contactId)
- ghl_contacts: Contacts (by contactId)
- fb_ads: Facebook ads (by adId)

LINKING DATA:
-------------
To link opportunities with form submissions and contacts:
1. Use contactId to match across collections
2. ghl_opportunities[contactId] ↔ ghl_data[contactId] ↔ ghl_contacts[contactId]
3. Use adId from ghl_data to link to Facebook ads

====================================================================================================

