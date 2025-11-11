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

/// Facebook Ad Set data model
class FacebookAdSetData {
  final String id;
  final String name;
  final String campaignId;
  final String campaignName;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final DateTime dateStart;
  final DateTime dateStop;

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
    required this.dateStart,
    required this.dateStop,
  });

  /// Create from Facebook API JSON response
  factory FacebookAdSetData.fromJson(Map<String, dynamic> json) {
    final insights = json['insights']?['data']?[0] ?? {};
    
    return FacebookAdSetData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      campaignName: json['campaign']?['name']?.toString() ?? '',
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
      'campaignName': campaignName,
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
    return 'FacebookAdSetData(id: $id, name: $name, campaignId: $campaignId, spend: \$$spend)';
  }
}

class FacebookAdData {
  final String id;
  final String name;
  final String campaignId;
  final String? adSetId;      // Ad Set ID for hierarchy
  final String? adSetName;    // Ad Set name for display
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
    this.adSetId,
    this.adSetName,
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
      adSetId: json['adset_id']?.toString(),
      adSetName: json['adset']?['name']?.toString(),
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
      'adSetId': adSetId,
      'adSetName': adSetName,
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
    return 'FacebookAdData(id: $id, name: $name, adSetName: $adSetName, campaignId: $campaignId, spend: \$$spend)';
  }
}

/// Facebook Weekly Insight data model for time-series analysis
class FacebookWeeklyInsight {
  final String adId;
  final int weekNumber;
  final DateTime dateStart;
  final DateTime dateStop;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final DateTime fetchedAt;

  FacebookWeeklyInsight({
    required this.adId,
    required this.weekNumber,
    required this.dateStart,
    required this.dateStop,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    required this.fetchedAt,
  });

  /// Create from Firestore document
  factory FacebookWeeklyInsight.fromFirestore(Map<String, dynamic> data) {
    return FacebookWeeklyInsight(
      adId: data['adId']?.toString() ?? '',
      weekNumber: data['weekNumber'] ?? 0,
      dateStart: (data['dateStart'] as dynamic)?.toDate() ?? DateTime.now(),
      dateStop: (data['dateStop'] as dynamic)?.toDate() ?? DateTime.now(),
      spend: (data['spend'] ?? 0).toDouble(),
      impressions: data['impressions'] ?? 0,
      reach: data['reach'] ?? 0,
      clicks: data['clicks'] ?? 0,
      cpm: (data['cpm'] ?? 0).toDouble(),
      cpc: (data['cpc'] ?? 0).toDouble(),
      ctr: (data['ctr'] ?? 0).toDouble(),
      fetchedAt: (data['fetchedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create from Facebook API JSON response (single week)
  factory FacebookWeeklyInsight.fromJson(Map<String, dynamic> json, String adId, int weekNumber) {
    return FacebookWeeklyInsight(
      adId: adId,
      weekNumber: weekNumber,
      dateStart: DateTime.tryParse(json['date_start']?.toString() ?? '') ?? DateTime.now(),
      dateStop: DateTime.tryParse(json['date_stop']?.toString() ?? '') ?? DateTime.now(),
      spend: double.tryParse(json['spend']?.toString() ?? '0') ?? 0.0,
      impressions: int.tryParse(json['impressions']?.toString() ?? '0') ?? 0,
      reach: int.tryParse(json['reach']?.toString() ?? '0') ?? 0,
      clicks: int.tryParse(json['clicks']?.toString() ?? '0') ?? 0,
      cpm: double.tryParse(json['cpm']?.toString() ?? '0') ?? 0.0,
      cpc: double.tryParse(json['cpc']?.toString() ?? '0') ?? 0.0,
      ctr: double.tryParse(json['ctr']?.toString() ?? '0') ?? 0.0,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adId': adId,
      'weekNumber': weekNumber,
      'dateStart': dateStart.toIso8601String(),
      'dateStop': dateStop.toIso8601String(),
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  /// Get formatted date range string (e.g., "Nov 1-7")
  String get dateRangeString {
    final startMonth = _getMonthAbbr(dateStart.month);
    final stopMonth = _getMonthAbbr(dateStop.month);
    
    if (dateStart.month == dateStop.month) {
      return '$startMonth ${dateStart.day}-${dateStop.day}';
    } else {
      return '$startMonth ${dateStart.day} - $stopMonth ${dateStop.day}';
    }
  }

  /// Get week label (e.g., "Week 1", "Week 2")
  String get weekLabel => 'Week $weekNumber';

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  String toString() {
    return 'FacebookWeeklyInsight(adId: $adId, week: $weekNumber, spend: \$$spend, dateRange: $dateRangeString)';
  }

  /// Calculate week-over-week change percentage
  double calculateChangePercent(FacebookWeeklyInsight previousWeek, String metric) {
    double current = 0;
    double previous = 0;

    switch (metric.toLowerCase()) {
      case 'spend':
        current = spend;
        previous = previousWeek.spend;
        break;
      case 'impressions':
        current = impressions.toDouble();
        previous = previousWeek.impressions.toDouble();
        break;
      case 'reach':
        current = reach.toDouble();
        previous = previousWeek.reach.toDouble();
        break;
      case 'clicks':
        current = clicks.toDouble();
        previous = previousWeek.clicks.toDouble();
        break;
      case 'cpm':
        current = cpm;
        previous = previousWeek.cpm;
        break;
      case 'cpc':
        current = cpc;
        previous = previousWeek.cpc;
        break;
      case 'ctr':
        current = ctr;
        previous = previousWeek.ctr;
        break;
    }

    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }
}


