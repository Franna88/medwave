/// Facebook Marketing API data models for campaign and ad insights
class FacebookCampaignData {
  final String id;
  final String name;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final DateTime dateStart;
  final DateTime dateStop;

  FacebookCampaignData({
    required this.id,
    required this.name,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    required this.dateStart,
    required this.dateStop,
  });

  /// Create from Facebook API JSON response
  factory FacebookCampaignData.fromJson(Map<String, dynamic> json) {
    final insights = json['insights']?['data']?[0] ?? {};
    
    return FacebookCampaignData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      spend: double.tryParse(insights['spend']?.toString() ?? '0') ?? 0.0,
      impressions: int.tryParse(insights['impressions']?.toString() ?? '0') ?? 0,
      reach: int.tryParse(insights['reach']?.toString() ?? '0') ?? 0,
      clicks: int.tryParse(insights['clicks']?.toString() ?? '0') ?? 0,
      cpm: double.tryParse(insights['cpm']?.toString() ?? '0') ?? 0.0,
      cpc: double.tryParse(insights['cpc']?.toString() ?? '0') ?? 0.0,
      ctr: double.tryParse(insights['ctr']?.toString() ?? '0') ?? 0.0,
      dateStart: DateTime.tryParse(insights['date_start']?.toString() ?? '') ?? DateTime.now(),
      dateStop: DateTime.tryParse(insights['date_stop']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'dateStart': dateStart.toIso8601String(),
      'dateStop': dateStop.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FacebookCampaignData(id: $id, name: $name, spend: \$$spend, impressions: $impressions)';
  }
}

class FacebookAdData {
  final String id;
  final String name;
  final String campaignId;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final DateTime dateStart;
  final DateTime dateStop;

  FacebookAdData({
    required this.id,
    required this.name,
    required this.campaignId,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    required this.dateStart,
    required this.dateStop,
  });

  /// Create from Facebook API JSON response
  factory FacebookAdData.fromJson(Map<String, dynamic> json) {
    final insights = json['insights']?['data']?[0] ?? {};
    
    return FacebookAdData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      spend: double.tryParse(insights['spend']?.toString() ?? '0') ?? 0.0,
      impressions: int.tryParse(insights['impressions']?.toString() ?? '0') ?? 0,
      reach: int.tryParse(insights['reach']?.toString() ?? '0') ?? 0,
      clicks: int.tryParse(insights['clicks']?.toString() ?? '0') ?? 0,
      cpm: double.tryParse(insights['cpm']?.toString() ?? '0') ?? 0.0,
      cpc: double.tryParse(insights['cpc']?.toString() ?? '0') ?? 0.0,
      ctr: double.tryParse(insights['ctr']?.toString() ?? '0') ?? 0.0,
      dateStart: DateTime.tryParse(insights['date_start']?.toString() ?? '') ?? DateTime.now(),
      dateStop: DateTime.tryParse(insights['date_stop']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'campaignId': campaignId,
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'dateStart': dateStart.toIso8601String(),
      'dateStop': dateStop.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FacebookAdData(id: $id, name: $name, campaignId: $campaignId, spend: \$$spend)';
  }
}


