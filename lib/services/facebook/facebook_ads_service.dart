import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/facebook/facebook_ad_data.dart';

/// Service for fetching Facebook Marketing API data
class FacebookAdsService {
  // Facebook Marketing API configuration
  static const String _baseUrl = 'https://graph.facebook.com/v24.0';
  static const String _adAccountId = 'act_220298027464902'; // MedWave Master Ads Account
  
  // Access token from Marketing API Tools
  // TODO: Move to Firebase Remote Config or secure backend for production
  static const String _accessToken = 'EAAc9pw8rgA0BPzXZBZAxiHi2g36aIZCtPitgYZAQVtZCknzxEQTeTb3Vo6iDKipdNZAu1kd1YSnOovulEHGSNdEZBNXOjo3UBRivxXwYcCVR4BZAa5EmRLTKSpeb2E1wri8CN0PYZChS8N9GDFs0ug7XcwdnMNIwMDlNgg65aCE1koSDJQTWlQZAT2x63N8Hu8pPQpBJYZD';
  
  // Cache configuration
  static final Map<String, _CachedData> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  /// Fetch all campaigns with insights from the ad account
  static Future<List<FacebookCampaignData>> fetchCampaigns({
    bool forceRefresh = false,
    String datePreset = 'last_30d',
  }) async {
    final cacheKey = 'campaigns_$datePreset';
    
    // Check cache first
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
        if (kDebugMode) {
          print('📦 Using cached Facebook campaigns (age: ${DateTime.now().difference(cached.timestamp).inMinutes}m)');
        }
        return cached.data as List<FacebookCampaignData>;
      }
    }
    
    try {
      if (kDebugMode) {
        print('🌐 Fetching Facebook campaigns from API...');
      }
      
      // Build API URL
      final url = Uri.parse(
        '$_baseUrl/$_adAccountId/campaigns?'
        'fields=id,name,insights{'
        'impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop'
        '}&'
        'date_preset=$datePreset&'
        'access_token=$_accessToken'
      );
      
      // Make API request
      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        throw FacebookAdsApiException(
          'Failed to fetch campaigns: ${response.statusCode} ${response.body}',
        );
      }
      
      final jsonData = json.decode(response.body);
      final campaignsJson = jsonData['data'] as List<dynamic>? ?? [];
      
      // Parse campaigns
      final campaigns = campaignsJson
          .map((c) => FacebookCampaignData.fromJson(c as Map<String, dynamic>))
          .toList();
      
      // Cache the results
      _cache[cacheKey] = _CachedData(
        data: campaigns,
        timestamp: DateTime.now(),
      );
      
      if (kDebugMode) {
        print('✅ Fetched ${campaigns.length} Facebook campaigns');
        for (final campaign in campaigns) {
          print('   • ${campaign.name}: \$${campaign.spend.toStringAsFixed(2)} spend, ${campaign.impressions} impressions');
        }
      }
      
      return campaigns;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching Facebook campaigns: $e');
      }
      
      // Return cached data if available, even if expired
      if (_cache.containsKey(cacheKey)) {
        if (kDebugMode) {
          print('⚠️ Returning stale cached data due to error');
        }
        return _cache[cacheKey]!.data as List<FacebookCampaignData>;
      }
      
      rethrow;
    }
  }
  
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
        'fields=id,name,adset_id,adset{name},campaign_id,insights{'
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
  
  /// Fetch ads for a specific campaign (DEPRECATED - use fetchCompleteHierarchy instead)
  @Deprecated('Use fetchCompleteHierarchy() to get the full Campaign → Ad Sets → Ads structure')
  static Future<List<FacebookAdData>> fetchAdsForCampaign(
    String campaignId, {
    bool forceRefresh = false,
    String datePreset = 'last_30d',
  }) async {
    final cacheKey = 'ads_${campaignId}_$datePreset';
    
    // Check cache first
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
        if (kDebugMode) {
          print('📦 Using cached Facebook ads for campaign $campaignId');
        }
        return cached.data as List<FacebookAdData>;
      }
    }
    
    try {
      if (kDebugMode) {
        print('🌐 Fetching Facebook ads for campaign $campaignId...');
      }
      
      // Build API URL
      final url = Uri.parse(
        '$_baseUrl/$campaignId/ads?'
        'fields=id,name,campaign_id,insights{'
        'impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop'
        '}&'
        'date_preset=$datePreset&'
        'access_token=$_accessToken'
      );
      
      // Make API request
      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        throw FacebookAdsApiException(
          'Failed to fetch ads for campaign $campaignId: ${response.statusCode} ${response.body}',
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
        print('✅ Fetched ${ads.length} Facebook ads for campaign $campaignId');
      }
      
      return ads;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching Facebook ads for campaign $campaignId: $e');
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
  /// Returns a structured map with the full Facebook Ads hierarchy
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
      int totalAdSets = 0;
      int totalAds = 0;
      
      // Step 2: For each campaign, fetch ad sets
      for (final campaign in campaigns) {
        try {
          final adSets = await fetchAdSetsForCampaign(
            campaign.id,
            forceRefresh: forceRefresh,
            datePreset: datePreset,
          );
          
          totalAdSets += adSets.length;
          final adSetData = <String, dynamic>{};
          
          // Step 3: For each ad set, fetch ads
          for (final adSet in adSets) {
            try {
              final ads = await fetchAdsForAdSet(
                adSet.id,
                forceRefresh: forceRefresh,
                datePreset: datePreset,
              );
              
              totalAds += ads.length;
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
  
  /// Fetch all ads for all campaigns (batch operation)
  /// DEPRECATED: Use fetchCompleteHierarchy() for better structure
  @Deprecated('Use fetchCompleteHierarchy() to get the full Campaign → Ad Sets → Ads structure')
  static Future<Map<String, List<FacebookAdData>>> fetchAllAds({
    bool forceRefresh = false,
    String datePreset = 'last_30d',
  }) async {
    try {
      // First, fetch all campaigns
      final campaigns = await fetchCampaigns(
        forceRefresh: forceRefresh,
        datePreset: datePreset,
      );
      
      // Then, fetch ads for each campaign
      final Map<String, List<FacebookAdData>> adsByCampaign = {};
      
      for (final campaign in campaigns) {
        try {
          final ads = await fetchAdsForCampaign(
            campaign.id,
            forceRefresh: forceRefresh,
            datePreset: datePreset,
          );
          adsByCampaign[campaign.id] = ads;
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to fetch ads for campaign ${campaign.id}: $e');
          }
          adsByCampaign[campaign.id] = [];
        }
      }
      
      return adsByCampaign;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching all Facebook ads: $e');
      }
      rethrow;
    }
  }
  
  /// Clear all cached data
  static void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print('🗑️ Facebook Ads API cache cleared');
    }
  }
  
  /// Get cache status information
  static Map<String, dynamic> getCacheStatus() {
    final now = DateTime.now();
    return {
      'cacheSize': _cache.length,
      'entries': _cache.entries.map((e) {
        final age = now.difference(e.value.timestamp);
        return {
          'key': e.key,
          'age': age.inMinutes,
          'isExpired': age > _cacheExpiry,
        };
      }).toList(),
    };
  }
  
  /// Check if the access token is likely valid (basic validation)
  static bool isAccessTokenConfigured() {
    return _accessToken.isNotEmpty && _accessToken != 'YOUR_ACCESS_TOKEN_HERE';
  }
}

/// Internal class for caching data
class _CachedData {
  final dynamic data;
  final DateTime timestamp;
  
  _CachedData({
    required this.data,
    required this.timestamp,
  });
}

/// Custom exception for Facebook Ads API errors
class FacebookAdsApiException implements Exception {
  final String message;
  
  FacebookAdsApiException(this.message);
  
  @override
  String toString() => 'FacebookAdsApiException: $message';
}


