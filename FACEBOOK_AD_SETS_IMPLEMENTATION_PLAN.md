# Facebook Ad Sets Implementation Plan

## Problem Statement

The current Facebook Ads API integration is **missing the Ad Set level** in the hierarchy:

### Current Implementation (INCOMPLETE):
```
Campaign (e.g., "Matthys - 17102025 - ABOLEADFORMZA (DDM)")
    └── Ads (e.g., "Obesity - DDM", "AI Jab - DDM")  ❌ WRONG!
```

### Correct Facebook Hierarchy:
```
Campaign (e.g., "Matthys - 17102025 - ABOLEADFORMZA (DDM) - Targeted Audiences")
    └── Ad Set (e.g., "Interests - Business (DDM)")
        └── Ads (e.g., "Obesity - DDM", "AI Jab - DDM", "COLIN LAGRANGE (DDM)")
```

## Impact on Matching

This explains why matching is difficult! GHL might be tracking at the **Ad Set level**, not just the Campaign level.

### GHL Campaign Structure (from screenshots):
Looking at the GHL data structure, we need to understand what level GHL is tracking:
- Does GHL track at Campaign level?
- Does GHL track at Ad Set level?
- Does GHL track at individual Ad level?

## Implementation Steps

### Step 1: Add Ad Set Model

**File:** `lib/models/facebook/facebook_ad_data.dart`

Add new model class:

```dart
class FacebookAdSetData {
  final String id;
  final String name;
  final String campaignId;
  final String campaignName;
  
  // Insights metrics
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final String? dateStart;
  final String? dateStop;
  
  FacebookAdSetData({
    required this.id,
    required this.name,
    required this.campaignId,
    required this.campaignName,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    this.dateStart,
    this.dateStop,
  });
  
  factory FacebookAdSetData.fromJson(Map<String, dynamic> json) {
    // Parse insights data
    final insights = json['insights']?['data']?[0] as Map<String, dynamic>?;
    
    return FacebookAdSetData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      campaignId: json['campaign_id'] as String? ?? '',
      campaignName: json['campaign']?['name'] as String? ?? '',
      spend: double.tryParse(insights?['spend']?.toString() ?? '0') ?? 0.0,
      impressions: int.tryParse(insights?['impressions']?.toString() ?? '0') ?? 0,
      reach: int.tryParse(insights?['reach']?.toString() ?? '0') ?? 0,
      clicks: int.tryParse(insights?['clicks']?.toString() ?? '0') ?? 0,
      cpm: double.tryParse(insights?['cpm']?.toString() ?? '0') ?? 0.0,
      cpc: double.tryParse(insights?['cpc']?.toString() ?? '0') ?? 0.0,
      ctr: double.tryParse(insights?['ctr']?.toString() ?? '0') ?? 0.0,
      dateStart: insights?['date_start'] as String?,
      dateStop: insights?['date_stop'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'dateStart': dateStart,
      'dateStop': dateStop,
    };
  }
}
```

### Step 2: Add Ad Set API Methods

**File:** `lib/services/facebook/facebook_ads_service.dart`

Add new methods to fetch Ad Sets:

```dart
/// Fetch all ad sets for a specific campaign
static Future<List<FacebookAdSetData>> fetchAdSetsForCampaign(
  String campaignId, {
  bool forceRefresh = false,
  String datePreset = 'last_30d',
}) async {
  final cacheKey = 'adsets_${campaignId}_$datePreset';
  
  // Check cache first
  if (!forceRefresh && _cache.containsKey(cacheKey)) {
    final cached = _cache[cacheKey]!;
    if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      if (kDebugMode) {
        print('📦 Using cached Facebook ad sets for campaign $campaignId');
      }
      return cached.data as List<FacebookAdSetData>;
    }
  }
  
  try {
    if (kDebugMode) {
      print('🌐 Fetching Facebook ad sets for campaign $campaignId...');
    }
    
    // Build API URL
    final url = Uri.parse(
      '$_baseUrl/$campaignId/adsets?'
      'fields=id,name,campaign_id,campaign{name},insights{'
      'impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop'
      '}&'
      'date_preset=$datePreset&'
      'access_token=$_accessToken'
    );
    
    // Make API request
    final response = await http.get(url);
    
    if (response.statusCode != 200) {
      throw FacebookAdsApiException(
        'Failed to fetch ad sets for campaign $campaignId: ${response.statusCode} ${response.body}',
      );
    }
    
    final jsonData = json.decode(response.body);
    final adSetsJson = jsonData['data'] as List<dynamic>? ?? [];
    
    // Parse ad sets
    final adSets = adSetsJson
        .map((a) => FacebookAdSetData.fromJson(a as Map<String, dynamic>))
        .toList();
    
    // Cache the results
    _cache[cacheKey] = _CachedData(
      data: adSets,
      timestamp: DateTime.now(),
    );
    
    if (kDebugMode) {
      print('✅ Fetched ${adSets.length} Facebook ad sets for campaign $campaignId');
      for (final adSet in adSets) {
        print('   • ${adSet.name}: \$${adSet.spend.toStringAsFixed(2)} spend, ${adSet.impressions} impressions');
      }
    }
    
    return adSets;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error fetching Facebook ad sets for campaign $campaignId: $e');
    }
    
    // Return cached data if available, even if expired
    if (_cache.containsKey(cacheKey)) {
      if (kDebugMode) {
        print('⚠️ Returning stale cached data due to error');
      }
      return _cache[cacheKey]!.data as List<FacebookAdSetData>;
    }
    
    rethrow;
  }
}

/// Fetch ads for a specific ad set
static Future<List<FacebookAdData>> fetchAdsForAdSet(
  String adSetId, {
  bool forceRefresh = false,
  String datePreset = 'last_30d',
}) async {
  final cacheKey = 'ads_adset_${adSetId}_$datePreset';
  
  // Check cache first
  if (!forceRefresh && _cache.containsKey(cacheKey)) {
    final cached = _cache[cacheKey]!;
    if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      if (kDebugMode) {
        print('📦 Using cached Facebook ads for ad set $adSetId');
      }
      return cached.data as List<FacebookAdData>;
    }
  }
  
  try {
    if (kDebugMode) {
      print('🌐 Fetching Facebook ads for ad set $adSetId...');
    }
    
    // Build API URL
    final url = Uri.parse(
      '$_baseUrl/$adSetId/ads?'
      'fields=id,name,adset_id,campaign_id,insights{'
      'impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop'
      '}&'
      'date_preset=$datePreset&'
      'access_token=$_accessToken'
    );
    
    // Make API request
    final response = await http.get(url);
    
    if (response.statusCode != 200) {
      throw FacebookAdsApiException(
        'Failed to fetch ads for ad set $adSetId: ${response.statusCode} ${response.body}',
      );
    }
    
    final jsonData = json.decode(response.body);
    final adsJson = jsonData['data'] as List<dynamic>? ?? [];
    
    // Parse ads
    final ads = adsJson
        .map((a) => FacebookAdData.fromJson(a as Map<String, dynamic>))
        .toList();
    
    // Cache the results
    _cache[cacheKey] = _CachedData(
      data: ads,
      timestamp: DateTime.now(),
    );
    
    if (kDebugMode) {
      print('✅ Fetched ${ads.length} Facebook ads for ad set $adSetId');
    }
    
    return ads;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error fetching Facebook ads for ad set $adSetId: $e');
    }
    
    // Return cached data if available, even if expired
    if (_cache.containsKey(cacheKey)) {
      if (kDebugMode) {
        print('⚠️ Returning stale cached data due to error');
      }
      return _cache[cacheKey]!.data as List<FacebookAdData>;
    }
    
    rethrow;
  }
}

/// Fetch complete hierarchy: Campaigns → Ad Sets → Ads
static Future<Map<String, dynamic>> fetchCompleteHierarchy({
  bool forceRefresh = false,
  String datePreset = 'last_30d',
}) async {
  try {
    if (kDebugMode) {
      print('🌐 Fetching complete Facebook hierarchy (Campaigns → Ad Sets → Ads)...');
    }
    
    // Step 1: Fetch all campaigns
    final campaigns = await fetchCampaigns(
      forceRefresh: forceRefresh,
      datePreset: datePreset,
    );
    
    final hierarchy = <String, dynamic>{};
    
    // Step 2: For each campaign, fetch ad sets
    for (final campaign in campaigns) {
      try {
        final adSets = await fetchAdSetsForCampaign(
          campaign.id,
          forceRefresh: forceRefresh,
          datePreset: datePreset,
        );
        
        final adSetData = <String, dynamic>{};
        
        // Step 3: For each ad set, fetch ads
        for (final adSet in adSets) {
          try {
            final ads = await fetchAdsForAdSet(
              adSet.id,
              forceRefresh: forceRefresh,
              datePreset: datePreset,
            );
            
            adSetData[adSet.id] = {
              'adSet': adSet,
              'ads': ads,
            };
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to fetch ads for ad set ${adSet.id}: $e');
            }
            adSetData[adSet.id] = {
              'adSet': adSet,
              'ads': <FacebookAdData>[],
            };
          }
        }
        
        hierarchy[campaign.id] = {
          'campaign': campaign,
          'adSets': adSetData,
        };
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to fetch ad sets for campaign ${campaign.id}: $e');
        }
        hierarchy[campaign.id] = {
          'campaign': campaign,
          'adSets': <String, dynamic>{},
        };
      }
    }
    
    if (kDebugMode) {
      print('✅ Fetched complete Facebook hierarchy:');
      print('   • ${campaigns.length} campaigns');
      int totalAdSets = 0;
      int totalAds = 0;
      hierarchy.forEach((campaignId, data) {
        final adSets = data['adSets'] as Map<String, dynamic>;
        totalAdSets += adSets.length;
        adSets.forEach((adSetId, adSetData) {
          final ads = adSetData['ads'] as List<FacebookAdData>;
          totalAds += ads.length;
        });
      });
      print('   • $totalAdSets ad sets');
      print('   • $totalAds ads');
    }
    
    return hierarchy;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error fetching complete Facebook hierarchy: $e');
    }
    rethrow;
  }
}
```

### Step 3: Update FacebookAdData Model

**File:** `lib/models/facebook/facebook_ad_data.dart`

Add `adSetId` and `adSetName` fields to `FacebookAdData`:

```dart
class FacebookAdData {
  final String id;
  final String name;
  final String campaignId;
  final String? adSetId;      // NEW FIELD
  final String? adSetName;    // NEW FIELD
  
  // ... rest of fields
}
```

### Step 4: Investigate GHL Data Structure

**CRITICAL QUESTION:** What level does GHL track campaigns at?

We need to examine the GHL data to understand:
1. Does GHL `campaignKey` correspond to Facebook Campaign, Ad Set, or Ad?
2. What does the GHL `adId` represent?
3. What does the GHL `adName` represent?

**Action Required:** 
- Check the GHL proxy logs to see the actual structure
- Compare GHL campaign names with Facebook Ad Set names
- Determine the correct matching level

### Step 5: Update Matching Logic

Once we understand the GHL structure, update the matching logic in:
**File:** `lib/providers/performance_cost_provider.dart`

Possible scenarios:
1. **GHL tracks at Ad Set level** → Match GHL campaigns to Facebook Ad Sets
2. **GHL tracks at Ad level** → Match GHL ads to Facebook Ads
3. **GHL tracks at Campaign level** → Keep current matching, but add Ad Set visibility

## Testing Plan

1. **Test API Endpoints:**
   - Fetch ad sets for a campaign
   - Fetch ads for an ad set
   - Fetch complete hierarchy

2. **Verify Data Structure:**
   - Campaign → Ad Sets → Ads hierarchy is correct
   - All metrics are populated correctly
   - IDs and names match Facebook UI

3. **Test Matching:**
   - Compare GHL campaign names with Facebook Ad Set names
   - Verify matches are found at the correct level
   - Check logs for successful matches

## Next Steps

1. ✅ **Document the problem** (this file)
2. ⏳ **Investigate GHL data structure** - Understand what GHL is actually tracking
3. ⏳ **Implement Ad Set model** - Add `FacebookAdSetData` class
4. ⏳ **Implement Ad Set API methods** - Add `fetchAdSetsForCampaign()` and related methods
5. ⏳ **Update matching logic** - Match at the correct level (Campaign/Ad Set/Ad)
6. ⏳ **Update UI** - Display the complete hierarchy
7. ⏳ **Test end-to-end** - Verify matching works correctly

## Questions to Answer

1. **What does GHL's `campaignKey` represent?**
   - Is it the Facebook Campaign name?
   - Is it the Facebook Ad Set name?
   - Is it something else?

2. **What does GHL's `adId` represent?**
   - Is it the Facebook Ad ID?
   - Is it the Facebook Ad Set ID?
   - Is it a GHL-generated ID?

3. **What does GHL's `adName` represent?**
   - Is it the Facebook Ad name?
   - Is it the Facebook Ad Set name?
   - Is it a custom name from GHL?

4. **Where does the UTM data come from?**
   - Are UTM parameters set at Campaign, Ad Set, or Ad level?
   - How does GHL extract and store this data?

## References

- Facebook Marketing API - Ad Sets: https://developers.facebook.com/docs/marketing-api/reference/ad-campaign
- Facebook Marketing API - Ads: https://developers.facebook.com/docs/marketing-api/reference/adgroup
- Current implementation: `lib/services/facebook/facebook_ads_service.dart`

