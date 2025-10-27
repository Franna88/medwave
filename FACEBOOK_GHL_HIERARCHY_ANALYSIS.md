# Facebook vs GHL Data Hierarchy Analysis

## Date: October 27, 2025

---

## Facebook Ads Hierarchy (3 Levels)

Based on your screenshots, Facebook has a **3-tier structure**:

```
📊 Campaign
    └── 🎯 Ad Set
        └── 📢 Ad
```

### Example from Your Account:

**Campaign:**
- Name: `Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences`
- ID: `120234497185340335`

**Ad Sets (within that campaign):**
- `Interests - Business (DDM)`
- `Interests - Everything Doctor (DDM)`
- `Interests - General Hospital (DDM)`
- `Interests - Healthcare and medical services (DDM)`

**Ads (within "Interests - Business" ad set):**
- `Obesity - DDM`
- `AI Jab - DDM`
- `COLIN LAGRANGE (DDM)`
- `Metabolic Weight Loss (2) | DDM`
- `AI Proof - DDM`
- `Obesity - Andries - DDM`

---

## GHL Data Structure (What We're Actually Tracking)

Based on the code analysis (`ghl-proxy/server.js` lines 540-552):

```javascript
const campaignName = lastAttribution?.utmCampaign || '';
const adId = lastAttribution?.utmAdId || lastAttribution?.utmContent || lastAttribution?.utmTerm || 'Unknown Ad';
const adName = lastAttribution?.utmContent || lastAttribution?.utmTerm || adId;
```

### GHL Tracks:
1. **Campaign Name** (from UTM parameter `utm_campaign`)
2. **Ad ID** (from UTM parameter `utm_ad_id` or `utm_content` or `utm_term`)
3. **Ad Name** (from UTM parameter `utm_content` or `utm_term`)

### Key Insight:
**GHL is tracking at the INDIVIDUAL AD level**, not Campaign or Ad Set level!

---

## The Missing Link: Ad Sets

### Current Problem:

```
Facebook:                    GHL:
Campaign                     ✅ Campaign Name (from utm_campaign)
  └── Ad Set                 ❌ NOT TRACKED
      └── Ad                 ✅ Ad ID/Name (from utm_content)
```

**Ad Sets are NOT being tracked in GHL!**

This is because:
1. Facebook doesn't automatically include Ad Set information in UTM parameters
2. GHL only captures what's in the UTM parameters
3. UTM parameters typically include: `utm_campaign`, `utm_source`, `utm_medium`, `utm_content`, `utm_term`

---

## How Facebook UTM Parameters Work

When someone clicks a Facebook ad, the URL typically looks like:

```
https://yourwebsite.com/?
  utm_source=facebook&
  utm_medium=cpc&
  utm_campaign=Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences&
  utm_content=Obesity - DDM&
  fbclid=IwAR1234567890
```

**Notice:** There's NO `utm_adset` parameter by default!

---

## Solution Options

### Option 1: Fetch Ad Set Data from Facebook API (Recommended)

**What to do:**
1. Implement Ad Set fetching in Facebook API service
2. When matching, use the complete hierarchy:
   - Match GHL Campaign Name → Facebook Campaign
   - Fetch all Ad Sets for that campaign
   - Fetch all Ads for each Ad Set
   - Match GHL Ad ID/Name → Facebook Ad
3. Display the complete hierarchy in the UI

**Pros:**
- Complete visibility into campaign structure
- Better analytics (can see Ad Set performance)
- More accurate matching

**Cons:**
- More API calls (but we have caching)
- Slightly more complex matching logic

### Option 2: Add Ad Set to UTM Parameters (Manual Setup)

**What to do:**
1. In Facebook Ads Manager, manually add Ad Set name to UTM parameters
2. Use a custom parameter like `utm_adset={{adset.name}}`
3. Update GHL to capture this parameter

**Pros:**
- More accurate tracking from the source
- GHL would have Ad Set data

**Cons:**
- Requires manual setup for every campaign
- Retroactive - won't help with existing data
- Facebook doesn't support `{{adset.name}}` dynamic parameter by default

### Option 3: Infer Ad Set from Ad Name Pattern (Workaround)

**What to do:**
1. Look for patterns in Ad names that might indicate Ad Set
2. Use fuzzy matching to group ads by similarity

**Pros:**
- Works with existing data
- No additional API calls

**Cons:**
- Unreliable
- Won't work if naming isn't consistent

---

## Recommended Implementation: Option 1

### Step 1: Add Ad Set Support to Facebook API

**File:** `lib/services/facebook/facebook_ads_service.dart`

Add methods:
- `fetchAdSetsForCampaign(campaignId)` - Get all ad sets for a campaign
- `fetchAdsForAdSet(adSetId)` - Get all ads for an ad set
- `fetchCompleteHierarchy()` - Get Campaign → Ad Sets → Ads

### Step 2: Update Data Models

**File:** `lib/models/facebook/facebook_ad_data.dart`

Add:
- `FacebookAdSetData` class
- Add `adSetId` and `adSetName` to `FacebookAdData`

### Step 3: Update Matching Logic

**File:** `lib/providers/performance_cost_provider.dart`

New matching flow:
1. Match GHL Campaign Name → Facebook Campaign (existing)
2. Fetch all Ad Sets for matched campaign
3. Fetch all Ads for each Ad Set
4. Match GHL Ad ID/Name → Facebook Ad
5. Include Ad Set information in the matched data

### Step 4: Update UI

**File:** `lib/widgets/admin/add_performance_cost_table.dart`

Display hierarchy:
```
Campaign: Matthys - 17102025 - ABOLEADFORMZA (DDM)
  Ad Set: Interests - Business (DDM)
    ├── Ad: Obesity - DDM (GHL: 50 leads, FB: $500 spend)
    ├── Ad: AI Jab - DDM (GHL: 30 leads, FB: $300 spend)
    └── Ad: COLIN LAGRANGE (DDM) (GHL: 20 leads, FB: $200 spend)
  Ad Set: Interests - Everything Doctor (DDM)
    └── ...
```

---

## Current vs. Proposed Matching

### Current Matching (Incomplete):

```
GHL Campaign: "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Afrikaans"
    └── GHL Ad: "Obesity - DDM"

Facebook Campaign: "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences"
    └── ??? (no Ad Set visibility)
        └── ??? (can't match individual ads)
```

**Result:** ❌ Can't match GHL ads to Facebook ads because we're missing the Ad Set level

### Proposed Matching (Complete):

```
GHL Campaign: "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Afrikaans"
    └── GHL Ad: "Obesity - DDM"
        ↓ (match by name)
Facebook Campaign: "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences"
    └── Facebook Ad Set: "Interests - Business (DDM)"
        └── Facebook Ad: "Obesity - DDM" ✅ MATCHED!
```

**Result:** ✅ Complete matching with full hierarchy visibility

---

## Data Flow

### Current Flow:
1. GHL captures: Campaign Name + Ad Name (from UTM)
2. Facebook API returns: Campaign-level metrics only
3. Matching: Campaign Name fuzzy match
4. Result: Campaign-level metrics only (no individual ad performance)

### Proposed Flow:
1. GHL captures: Campaign Name + Ad Name (from UTM)
2. Facebook API returns: Campaign → Ad Sets → Ads (complete hierarchy)
3. Matching: 
   - Step 1: Campaign Name fuzzy match
   - Step 2: Ad Name exact match within matched campaign
4. Result: Individual ad performance with full context

---

## Implementation Priority

### Phase 1: Add Ad Set API Support (HIGH PRIORITY)
- [ ] Create `FacebookAdSetData` model
- [ ] Add `fetchAdSetsForCampaign()` method
- [ ] Add `fetchAdsForAdSet()` method
- [ ] Add `fetchCompleteHierarchy()` method
- [ ] Test API endpoints

### Phase 2: Update Matching Logic (HIGH PRIORITY)
- [ ] Update matching to use complete hierarchy
- [ ] Match GHL ads to Facebook ads (not just campaigns)
- [ ] Store Ad Set information in matched data

### Phase 3: Update UI (MEDIUM PRIORITY)
- [ ] Display Campaign → Ad Set → Ad hierarchy
- [ ] Show Ad Set-level metrics
- [ ] Show individual ad metrics with GHL + Facebook data

### Phase 4: Analytics Enhancement (LOW PRIORITY)
- [ ] Ad Set performance comparison
- [ ] Best performing ads within ad sets
- [ ] ROI calculation at ad level

---

## Questions Answered

### Q: Why aren't GHL campaigns matching Facebook campaigns?
**A:** Because we're trying to match at the wrong level. GHL tracks individual ads, but we're only fetching campaign-level data from Facebook.

### Q: What is the Ad Set in Facebook?
**A:** An Ad Set is a group of ads that share the same targeting, budget, and schedule. It sits between Campaign and Ad in the hierarchy.

### Q: Does GHL track Ad Sets?
**A:** No, GHL only tracks what's in the UTM parameters (Campaign Name and Ad ID/Name). Ad Set information is not included in standard UTM parameters.

### Q: How do we get Ad Set data?
**A:** We need to fetch it from the Facebook Marketing API using the Ad Sets endpoint: `/{campaign-id}/adsets`

---

## Next Steps

1. ✅ **Analyze the hierarchy** (this document)
2. ⏳ **Implement Ad Set API methods** (see FACEBOOK_AD_SETS_IMPLEMENTATION_PLAN.md)
3. ⏳ **Update matching logic** to match at Ad level, not Campaign level
4. ⏳ **Test with real data** from your Facebook account
5. ⏳ **Update UI** to show complete hierarchy

---

## References

- Facebook Marketing API - Campaigns: https://developers.facebook.com/docs/marketing-api/reference/ad-campaign
- Facebook Marketing API - Ad Sets: https://developers.facebook.com/docs/marketing-api/reference/ad-campaign
- Facebook Marketing API - Ads: https://developers.facebook.com/docs/marketing-api/reference/adgroup
- UTM Parameters Guide: https://ga-dev-tools.google/campaign-url-builder/
- Current GHL proxy code: `ghl-proxy/server.js` lines 536-552

