================================================================================
GHL TO FACEBOOK ADS - MULTI-LEVEL MATCHING STRATEGY
================================================================================
Date: November 10, 2025
Status: PRODUCTION READY ✅

================================================================================
PROBLEM STATEMENT
================================================================================

ISSUE: Missing h_ad_id in GHL Attributions
-------------------------------------------
Facebook forms are configured to pass UTM parameters including h_ad_id:
  utm_source={{campaign.name}}&utm_medium={{adset.name}}&utm_campaign={{ad.name}}&fbc_id={{adset.id}}&h_ad_id={{ad.id}}

However, GHL is NOT consistently capturing the h_ad_id custom parameter.

DISCOVERY (November 10, 2025):
- Total opportunities: 6,676
- Andries & Davide pipelines: 934 opportunities
- WITH h_ad_id (utmAdId): 227 (24%)
- WITHOUT h_ad_id: 707 (76%) ❌

This means 76% of opportunities cannot be matched using h_ad_id alone!

ROOT CAUSE:
-----------
The h_ad_id custom parameter is being lost somewhere between:
1. Facebook form submission
2. GHL form processing
3. GHL opportunity creation

While the standard UTM parameters (utm_source, utm_medium, utm_campaign) ARE
being captured correctly by GHL.

================================================================================
SOLUTION: 4-TIER FALLBACK MATCHING STRATEGY
================================================================================

Instead of relying solely on h_ad_id, we use MULTIPLE matching methods in
order of specificity:

TIER 1: Direct Ad ID Match (Most Specific)
-------------------------------------------
Match using: utmAdId, h_ad_id, or adId fields
Source: opportunity.attributions[].utmAdId
Result: Matches to 1 specific Facebook ad
Coverage: 227 opportunities (24%)

Example:
```json
{
  "attributions": [{
    "utmAdId": "120235559827960335",  // ✅ Direct match!
    "utmSource": "facebook",
    "utmMedium": "Interests - Healthcare (DDM)",
    "utmCampaign": "05112025 - ABOLEADFORMZA (DDM)"
  }]
}
```

TIER 2: Campaign ID Match
--------------------------
Match using: utmCampaignId (Facebook Campaign ID)
Source: opportunity.attributions[].utmCampaignId
Result: Matches to ALL ads in that campaign
Coverage: 225 opportunities (24%)

Example:
```json
{
  "attributions": [{
    "utmCampaignId": "120235556205010335",  // ✅ Campaign match!
    "utmSource": "facebook",
    "utmMedium": "Interests - Healthcare (DDM)",
    "utmCampaign": "05112025 - ABOLEADFORMZA (DDM)"
  }]
}
```

Note: When matching by campaign, the GHL data is distributed to ALL ads
within that campaign. This is less precise but better than no match.

TIER 3: Ad Name Match
----------------------
Match using: utmCampaign field (contains Ad Name)
Source: opportunity.attributions[].utmCampaign
Result: Matches to all ads with that exact name
Coverage: 165 opportunities (18%)

Facebook UTM Configuration:
  utm_campaign={{ad.name}}  →  GHL stores as utmCampaign

Example:
```json
{
  "attributions": [{
    "utmCampaign": "05112025 - ABOLEADFORMZA (DDM) - Targeted Audiences",  // ✅ Ad name match!
    "utmMedium": "Interests - Healthcare (DDM)",
    "utmSource": "facebook"
  }]
}
```

TIER 4: AdSet Name Match
-------------------------
Match using: utmMedium field (contains AdSet Name)
Source: opportunity.attributions[].utmMedium
Result: Matches to all ads in that adset
Coverage: 0 opportunities (0% - all caught by earlier tiers)

Facebook UTM Configuration:
  utm_medium={{adset.name}}  →  GHL stores as utmMedium

Example:
```json
{
  "attributions": [{
    "utmMedium": "Interests - Healthcare and medical services (DDM)",  // ✅ AdSet match!
    "utmSource": "facebook"
  }]
}
```

================================================================================
IMPLEMENTATION RESULTS
================================================================================

BEFORE Multi-Level Matching:
-----------------------------
- Matched: 227 opportunities (24%)
- Unmatched: 707 opportunities (76%) ❌
- Coverage: POOR

AFTER Multi-Level Matching:
----------------------------
- Matched: 617 opportunities (66%) ✅
- Unmatched: 317 opportunities (34%)
- Coverage: GOOD

BREAKDOWN BY METHOD:
--------------------
✅ By Ad ID: 227 (37% of matched)
✅ By Campaign ID: 225 (36% of matched)
✅ By Ad Name: 165 (27% of matched)
✅ By AdSet Name: 0 (0% of matched)

IMPROVEMENT: 2.7x increase in match rate! (24% → 66%)

================================================================================
CODE IMPLEMENTATION
================================================================================

PYTHON IMPLEMENTATION (populate_ghl_data.py):
----------------------------------------------

```python
# Step 1: Build lookup maps
ad_map = {}
campaign_to_ads = defaultdict(list)
ad_name_to_ads = defaultdict(list)
adset_name_to_ads = defaultdict(list)

for ad in all_ads:
    ad_id = ad.id
    ad_data = ad.to_dict()
    
    # Store ad info
    ad_map[ad_id] = {
        'month': month_id,
        'ref': ad.reference,
        'campaign_id': ad_data.get('campaignId'),
        'ad_name': ad_data.get('adName'),
        'adset_name': ad_data.get('adSetName')
    }
    
    # Build lookup maps (case-insensitive)
    campaign_to_ads[ad_data.get('campaignId')].append(ad_id)
    ad_name_to_ads[ad_data.get('adName', '').lower()].append(ad_id)
    adset_name_to_ads[ad_data.get('adSetName', '').lower()].append(ad_id)

# Step 2: Match opportunities using 4-tier strategy
for opp in opportunities:
    target_ad_ids = []
    match_method = None
    
    # TIER 1: Try Ad ID
    identifier = extract_h_ad_id_from_attributions(opp)
    if identifier and identifier in ad_ids:
        target_ad_ids = [identifier]
        match_method = 'ad_id'
    
    # TIER 2: Try Campaign ID
    elif identifier and identifier in campaign_to_ads:
        target_ad_ids = campaign_to_ads[identifier]
        match_method = 'campaign_id'
    
    # TIER 3: Try Ad Name
    if not target_ad_ids:
        attributions = opp.get('attributions', [])
        for attr in reversed(attributions):
            utm_campaign = attr.get('utmCampaign', '').strip()
            if utm_campaign and utm_campaign.lower() in ad_name_to_ads:
                target_ad_ids = ad_name_to_ads[utm_campaign.lower()]
                match_method = 'ad_name'
                break
    
    # TIER 4: Try AdSet Name
    if not target_ad_ids:
        attributions = opp.get('attributions', [])
        for attr in reversed(attributions):
            utm_medium = attr.get('utmMedium', '').strip()
            if utm_medium and utm_medium.lower() in adset_name_to_ads:
                target_ad_ids = adset_name_to_ads[utm_medium.lower()]
                match_method = 'adset_name'
                break
    
    # If matched, update all target ads
    if target_ad_ids:
        for target_ad_id in target_ad_ids:
            # Update GHL weekly data for this ad
            update_ghl_weekly_data(target_ad_id, opp)
```

JAVASCRIPT IMPLEMENTATION (for Cloud Functions):
-------------------------------------------------

```javascript
// functions/lib/ghlMatchingService.js

/**
 * Match GHL opportunity to Facebook ads using multi-level strategy
 * @param {Object} opportunity - GHL opportunity object
 * @param {Map} adMap - Map of ad_id -> ad_data
 * @param {Map} campaignToAds - Map of campaign_id -> [ad_ids]
 * @param {Map} adNameToAds - Map of ad_name -> [ad_ids]
 * @param {Map} adsetNameToAds - Map of adset_name -> [ad_ids]
 * @returns {Array} Array of matched ad IDs
 */
function matchOpportunityToAds(opportunity, adMap, campaignToAds, adNameToAds, adsetNameToAds) {
  const attributions = opportunity.attributions || [];
  
  // TIER 1: Try Ad ID (most specific)
  for (const attr of attributions.reverse()) {
    const adId = attr.h_ad_id || attr.utmAdId || attr.adId;
    if (adId && adMap.has(adId)) {
      return { adIds: [adId], method: 'ad_id' };
    }
    
    // TIER 2: Try Campaign ID
    const campaignId = attr.utmCampaignId;
    if (campaignId && campaignToAds.has(campaignId)) {
      return { adIds: campaignToAds.get(campaignId), method: 'campaign_id' };
    }
  }
  
  // TIER 3: Try Ad Name
  for (const attr of attributions.reverse()) {
    const adName = (attr.utmCampaign || '').trim().toLowerCase();
    if (adName && adNameToAds.has(adName)) {
      return { adIds: adNameToAds.get(adName), method: 'ad_name' };
    }
  }
  
  // TIER 4: Try AdSet Name
  for (const attr of attributions.reverse()) {
    const adsetName = (attr.utmMedium || '').trim().toLowerCase();
    if (adsetName && adsetNameToAds.has(adsetName)) {
      return { adIds: adsetNameToAds.get(adsetName), method: 'adset_name' };
    }
  }
  
  return { adIds: [], method: 'unmatched' };
}

module.exports = { matchOpportunityToAds };
```

================================================================================
FACEBOOK UTM CONFIGURATION
================================================================================

The Facebook ads are configured with these URL parameters:

Campaign source: {{campaign.name}}
Campaign medium: {{adset.name}}
Campaign name: {{ad.name}}

Custom parameters:
- fbc_id = {{adset.id}}
- h_ad_id = {{ad.id}}

MAPPING TO GHL FIELDS:
----------------------
Facebook Parameter          →  GHL Attribution Field
------------------             --------------------
utm_source={{campaign.name}} → utmSource (but shows "facebook" instead!)
utm_medium={{adset.name}}    → utmMedium ✅
utm_campaign={{ad.name}}     → utmCampaign ✅
fbc_id={{adset.id}}          → NOT CAPTURED ❌
h_ad_id={{ad.id}}            → utmAdId (sometimes) ⚠️

================================================================================
WHEN TO USE EACH TIER
================================================================================

TIER 1 (Ad ID): Use when available
-----------------------------------
✅ Most accurate
✅ Matches to exact ad
✅ No ambiguity
❌ Only available 24% of the time

TIER 2 (Campaign ID): Good fallback
------------------------------------
✅ Available more often (24%)
✅ Still relatively specific
⚠️  Distributes data to ALL ads in campaign
⚠️  Less precise if campaign has many ads

TIER 3 (Ad Name): Acceptable fallback
--------------------------------------
✅ Available frequently (18%)
✅ Matches by actual ad content
⚠️  Multiple ads can have same name
⚠️  Distributes data to all matching ads

TIER 4 (AdSet Name): Last resort
---------------------------------
✅ Catches remaining opportunities
⚠️  Very broad matching
⚠️  Many ads in same adset
⚠️  Least precise

================================================================================
BEST PRACTICES
================================================================================

1. ALWAYS try all 4 tiers in order
   - Don't skip to lower tiers
   - Each tier is progressively less specific

2. TRACK which method was used
   - Log match_method for analytics
   - Helps identify data quality issues

3. HANDLE multiple matches gracefully
   - Tiers 2-4 can match multiple ads
   - Distribute GHL data to all matched ads
   - Mark data as "shared" if needed

4. CASE-INSENSITIVE matching for Tiers 3-4
   - Ad names may have inconsistent casing
   - Always .toLowerCase() before comparing

5. TRIM whitespace
   - UTM fields may have leading/trailing spaces
   - Always .trim() before matching

6. PREFER last attribution
   - Use reversed() to check most recent first
   - Last touch attribution is most relevant

================================================================================
LIMITATIONS & EDGE CASES
================================================================================

LIMITATION 1: Campaign-level matching is imprecise
---------------------------------------------------
When matching by campaign ID, ALL ads in that campaign receive the GHL data.
This means if a campaign has 10 ads, all 10 will show the same leads/deposits.

Mitigation: Accept this as better than no data. The UI can show a warning
that data is "campaign-level" rather than "ad-level".

LIMITATION 2: Ad name collisions
---------------------------------
Multiple ads can have the same name (e.g., "B2B October 2025").
When matching by ad name, all ads with that name receive the data.

Mitigation: Encourage unique ad names. Or accept shared data.

LIMITATION 3: 34% still unmatched
----------------------------------
Even with 4-tier matching, 317 opportunities (34%) remain unmatched.

Possible reasons:
- Ads not in advertData (deleted, paused, or from earlier months)
- UTM data completely missing
- Different ad account
- Manual opportunity creation (no UTM)

Mitigation: Periodically fetch more Facebook ads from earlier months.

LIMITATION 4: Historical data only
-----------------------------------
This strategy is for BACKFILLING historical data. New opportunities should
ideally have h_ad_id captured correctly going forward.

Mitigation: Investigate why h_ad_id is not being captured and fix at source.

================================================================================
MONITORING & ANALYTICS
================================================================================

METRICS TO TRACK:
-----------------
1. Match rate by tier
   - % matched by ad_id
   - % matched by campaign_id
   - % matched by ad_name
   - % matched by adset_name
   - % unmatched

2. Data quality over time
   - Is h_ad_id capture improving?
   - Are newer opportunities more likely to have utmAdId?

3. Accuracy indicators
   - How many ads receive "shared" data?
   - Average ads per campaign (affects Tier 2 precision)
   - Average ads per ad name (affects Tier 3 precision)

RECOMMENDED ALERTS:
-------------------
- Alert if match rate drops below 50%
- Alert if ad_id match rate drops below 20%
- Alert if unmatched rate exceeds 40%

================================================================================
TESTING & VERIFICATION
================================================================================

TEST CASE 1: Opportunity with utmAdId
--------------------------------------
Input: Opportunity with attributions[].utmAdId = "120235559827960335"
Expected: Matches to ad 120235559827960335 via Tier 1
Method: ad_id

TEST CASE 2: Opportunity with utmCampaignId only
-------------------------------------------------
Input: Opportunity with attributions[].utmCampaignId = "120235556205010335"
Expected: Matches to all ads in campaign 120235556205010335 via Tier 2
Method: campaign_id

TEST CASE 3: Opportunity with utmCampaign only
-----------------------------------------------
Input: Opportunity with attributions[].utmCampaign = "B2B October 2025"
Expected: Matches to all ads named "B2B October 2025" via Tier 3
Method: ad_name

TEST CASE 4: Opportunity with utmMedium only
---------------------------------------------
Input: Opportunity with attributions[].utmMedium = "Interests - Healthcare (DDM)"
Expected: Matches to all ads in that adset via Tier 4
Method: adset_name

TEST CASE 5: Opportunity with no UTM data
------------------------------------------
Input: Opportunity with empty or missing attributions
Expected: No match
Method: unmatched

================================================================================
DEPLOYMENT CHECKLIST
================================================================================

✅ COMPLETED (November 10, 2025):
---------------------------------
- [x] Implemented in populate_ghl_data.py
- [x] Tested with 934 opportunities
- [x] Verified 66% match rate (617/934)
- [x] Confirmed data written to Firebase
- [x] Documented strategy

⏳ PENDING:
-----------
- [ ] Implement in Cloud Functions (opportunityHistoryService.js)
- [ ] Update scheduledSync function
- [ ] Add match_method tracking to ghlWeekly documents
- [ ] Create monitoring dashboard
- [ ] Set up alerts for match rate drops
- [ ] Investigate h_ad_id capture issue at source

================================================================================
FUTURE IMPROVEMENTS
================================================================================

1. FIX ROOT CAUSE
   - Investigate why h_ad_id is not being captured by GHL
   - Work with GHL support if needed
   - Update form configuration if necessary
   - Goal: 100% h_ad_id capture rate

2. MACHINE LEARNING MATCHING
   - Train model on successfully matched opportunities
   - Use contact name, email, phone for fuzzy matching
   - Predict most likely ad for unmatched opportunities

3. CONFIDENCE SCORES
   - Tier 1 (ad_id): 100% confidence
   - Tier 2 (campaign_id): 80% confidence
   - Tier 3 (ad_name): 60% confidence
   - Tier 4 (adset_name): 40% confidence
   - Store confidence score with GHL data

4. SMART DISTRIBUTION
   - For Tiers 2-4, use Facebook insights to weight distribution
   - Ads with more impressions get more weight
   - More accurate than equal distribution

================================================================================
REFERENCES
================================================================================

Scripts:
- /Users/mac/dev/medwave/populate_ghl_data.py (implementation)
- /Users/mac/dev/medwave/check_ad_name_matching.py (testing)
- /Users/mac/dev/medwave/check_actual_deposit_stages.py (discovery)

Documentation:
- /Users/mac/dev/medwave/ghl_info/GHL_OPPORTUNITY_API_REFERENCE.txt
- /Users/mac/dev/medwave/ghl_info/QUICK_REFERENCE.txt
- /Users/mac/dev/medwave/advertData/ADVERTDATA_IMPLEMENTATION_SESSION_SUMMARY.md

================================================================================
CONTACT & SUPPORT
================================================================================

For questions or issues with this matching strategy:
1. Review this document first
2. Check populate_ghl_data.py for implementation details
3. Test with check_ad_name_matching.py
4. Review GHL API responses for attribution data

Last Updated: November 10, 2025
Status: Production Ready ✅
Version: 1.0

================================================================================

