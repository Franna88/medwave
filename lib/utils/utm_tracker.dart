import '../models/form/form_submission.dart';

/// Utility for extracting and mapping UTM parameters from URL query parameters
class UtmTracker {
  /// Extract UTM parameters from URL query parameters and create FormAttribution
  static FormAttribution extractUtmParams(Map<String, String> queryParams) {
    return FormAttribution(
      utmSource: queryParams['utm_source'],
      utmMedium: queryParams['utm_medium'],
      utmCampaign: queryParams['utm_campaign'],
      utmCampaignId: queryParams['utm_campaign_id'],
      utmAdset: queryParams['utm_adset'],
      utmAdsetId: queryParams['utm_adset_id'],
      utmAd: queryParams['utm_ad'],
      utmAdId: queryParams['utm_ad_id'],
      fbclid: queryParams['fbclid'],
      // Map legacy fields if present
      campaignId: queryParams['utm_campaign_id'] ?? queryParams['campaign_id'],
      adSetId: queryParams['utm_adset_id'] ?? queryParams['adset_id'],
      adId: queryParams['utm_ad_id'] ?? queryParams['ad_id'],
    );
  }
}

