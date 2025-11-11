import 'package:cloud_firestore/cloud_firestore.dart';

/// Matching status between Facebook and GHL data
enum MatchingStatus {
  matched,    // Has both Facebook and GHL data
  unmatched,  // Facebook only, no GHL match
  partial     // Matched but missing some data
}

/// Facebook advertising statistics from Facebook Marketing API
class FacebookStats {
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final String dateStart;
  final String dateStop;
  final DateTime lastSync;

  FacebookStats({
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    required this.dateStart,
    required this.dateStop,
    required this.lastSync,
  });

  factory FacebookStats.fromFirestore(Map<String, dynamic> data) {
    return FacebookStats(
      spend: (data['spend'] ?? 0).toDouble(),
      impressions: data['impressions'] ?? 0,
      reach: data['reach'] ?? 0,
      clicks: data['clicks'] ?? 0,
      cpm: (data['cpm'] ?? 0).toDouble(),
      cpc: (data['cpc'] ?? 0).toDouble(),
      ctr: (data['ctr'] ?? 0).toDouble(),
      dateStart: data['dateStart'] ?? '',
      dateStop: data['dateStop'] ?? '',
      lastSync: (data['lastSync'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spend': spend,
      'impressions': impressions,
      'reach': reach,
      'clicks': clicks,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'dateStart': dateStart,
      'dateStop': dateStop,
      'lastSync': Timestamp.fromDate(lastSync),
    };
  }

  FacebookStats copyWith({
    double? spend,
    int? impressions,
    int? reach,
    int? clicks,
    double? cpm,
    double? cpc,
    double? ctr,
    String? dateStart,
    String? dateStop,
    DateTime? lastSync,
  }) {
    return FacebookStats(
      spend: spend ?? this.spend,
      impressions: impressions ?? this.impressions,
      reach: reach ?? this.reach,
      clicks: clicks ?? this.clicks,
      cpm: cpm ?? this.cpm,
      cpc: cpc ?? this.cpc,
      ctr: ctr ?? this.ctr,
      dateStart: dateStart ?? this.dateStart,
      dateStop: dateStop ?? this.dateStop,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// GoHighLevel statistics from opportunity tracking
class GHLStats {
  final String campaignKey;
  final int leads;
  final int bookings;
  final int deposits;
  final int cashCollected;  // Count of opportunities in cash collected stage
  final double cashAmount;   // Total monetary value (deposits + cash collected)
  final DateTime lastSync;

  GHLStats({
    required this.campaignKey,
    required this.leads,
    required this.bookings,
    required this.deposits,
    required this.cashCollected,
    required this.cashAmount,
    required this.lastSync,
  });

  factory GHLStats.fromFirestore(Map<String, dynamic> data) {
    return GHLStats(
      campaignKey: data['campaignKey'] ?? '',
      leads: data['leads'] ?? 0,
      bookings: data['bookings'] ?? 0,
      deposits: data['deposits'] ?? 0,
      cashCollected: data['cashCollected'] ?? 0,
      cashAmount: (data['cashAmount'] ?? 0).toDouble(),
      lastSync: (data['lastSync'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campaignKey': campaignKey,
      'leads': leads,
      'bookings': bookings,
      'deposits': deposits,
      'cashCollected': cashCollected,
      'cashAmount': cashAmount,
      'lastSync': Timestamp.fromDate(lastSync),
    };
  }

  GHLStats copyWith({
    String? campaignKey,
    int? leads,
    int? bookings,
    int? deposits,
    int? cashCollected,
    double? cashAmount,
    DateTime? lastSync,
  }) {
    return GHLStats(
      campaignKey: campaignKey ?? this.campaignKey,
      leads: leads ?? this.leads,
      bookings: bookings ?? this.bookings,
      deposits: deposits ?? this.deposits,
      cashCollected: cashCollected ?? this.cashCollected,
      cashAmount: cashAmount ?? this.cashAmount,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// Complete ad performance data combining Facebook and GHL metrics
class AdPerformanceData {
  final String adId;
  final String adName;
  final String campaignId;
  final String campaignName;
  final String? adSetId;
  final String? adSetName;
  final MatchingStatus matchingStatus;
  final DateTime lastUpdated;
  
  final FacebookStats facebookStats;
  final GHLStats? ghlStats;

  AdPerformanceData({
    required this.adId,
    required this.adName,
    required this.campaignId,
    required this.campaignName,
    this.adSetId,
    this.adSetName,
    required this.matchingStatus,
    required this.lastUpdated,
    required this.facebookStats,
    this.ghlStats,
  });

  factory AdPerformanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdPerformanceData(
      adId: data['adId'] ?? doc.id,
      adName: data['adName'] ?? '',
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      adSetId: data['adSetId'],
      adSetName: data['adSetName'],
      matchingStatus: _parseMatchingStatus(data['matchingStatus']),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      facebookStats: FacebookStats.fromFirestore(data['facebookStats'] ?? {}),
      ghlStats: data['ghlStats'] != null 
          ? GHLStats.fromFirestore(data['ghlStats']) 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adId': adId,
      'adName': adName,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'adSetId': adSetId,
      'adSetName': adSetName,
      'matchingStatus': matchingStatus.name,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'facebookStats': facebookStats.toFirestore(),
      'ghlStats': ghlStats?.toFirestore(),
    };
  }

  static MatchingStatus _parseMatchingStatus(dynamic value) {
    if (value == null) return MatchingStatus.unmatched;
    if (value is MatchingStatus) return value;
    
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'matched':
        return MatchingStatus.matched;
      case 'partial':
        return MatchingStatus.partial;
      default:
        return MatchingStatus.unmatched;
    }
  }

  // Computed metrics
  
  /// Cost per lead (CPL)
  double get cpl {
    final leads = ghlStats?.leads ?? 0;
    return leads > 0 ? facebookStats.spend / leads : 0;
  }

  /// Cost per booking (CPB)
  double get cpb {
    final bookings = ghlStats?.bookings ?? 0;
    return bookings > 0 ? facebookStats.spend / bookings : 0;
  }

  /// Cost per acquisition/deposit (CPA)
  double get cpa {
    final deposits = ghlStats?.deposits ?? 0;
    return deposits > 0 ? facebookStats.spend / deposits : 0;
  }

  /// Actual profit (cash collected - Facebook spend)
  double get profit {
    // Use real monetary values from GHL opportunities
    final revenue = ghlStats?.cashAmount ?? 0;
    final cost = facebookStats.spend;
    return revenue - cost;
  }

  /// Total cost (Facebook spend only)
  double get totalCost {
    return facebookStats.spend;
  }

  /// Has GHL data
  bool get hasGHLData => ghlStats != null && ghlStats!.leads > 0;

  AdPerformanceData copyWith({
    String? adId,
    String? adName,
    String? campaignId,
    String? campaignName,
    String? adSetId,
    String? adSetName,
    MatchingStatus? matchingStatus,
    DateTime? lastUpdated,
    FacebookStats? facebookStats,
    GHLStats? ghlStats,
  }) {
    return AdPerformanceData(
      adId: adId ?? this.adId,
      adName: adName ?? this.adName,
      campaignId: campaignId ?? this.campaignId,
      campaignName: campaignName ?? this.campaignName,
      adSetId: adSetId ?? this.adSetId,
      adSetName: adSetName ?? this.adSetName,
      matchingStatus: matchingStatus ?? this.matchingStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      facebookStats: facebookStats ?? this.facebookStats,
      ghlStats: ghlStats ?? this.ghlStats,
    );
  }
}

/// Extended class for display purposes (previously had product info, now just wraps AdPerformanceData)
class AdPerformanceWithProduct {
  final AdPerformanceData data;

  AdPerformanceWithProduct({
    required this.data,
  });

  // Delegate all properties to data
  String get adId => data.adId;
  String get adName => data.adName;
  String get campaignId => data.campaignId;
  String get campaignName => data.campaignName;
  String? get adSetId => data.adSetId;
  String? get adSetName => data.adSetName;
  MatchingStatus get matchingStatus => data.matchingStatus;
  DateTime get lastUpdated => data.lastUpdated;
  FacebookStats get facebookStats => data.facebookStats;
  GHLStats? get ghlStats => data.ghlStats;
  
  // Computed metrics
  double get cpl => data.cpl;
  double get cpb => data.cpb;
  double get cpa => data.cpa;
  double get profit => data.profit;
  double get totalCost => data.totalCost;
  bool get hasGHLData => data.hasGHLData;
}

