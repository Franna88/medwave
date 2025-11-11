import 'package:cloud_firestore/cloud_firestore.dart';

/// Facebook Stats nested object
class FacebookStats {
  final double spend;
  final int impressions;
  final int clicks;
  final int reach;
  final double cpm;
  final double cpc;
  final double ctr;
  final String dateStart;
  final String dateStop;
  
  FacebookStats({
    required this.spend,
    required this.impressions,
    required this.clicks,
    required this.reach,
    required this.cpm,
    required this.cpc,
    required this.ctr,
    required this.dateStart,
    required this.dateStop,
  });
  
  factory FacebookStats.fromMap(Map<String, dynamic> data) {
    return FacebookStats(
      spend: (data['spend'] ?? 0).toDouble(),
      impressions: data['impressions'] ?? 0,
      clicks: data['clicks'] ?? 0,
      reach: data['reach'] ?? 0,
      cpm: (data['cpm'] ?? 0).toDouble(),
      cpc: (data['cpc'] ?? 0).toDouble(),
      ctr: (data['ctr'] ?? 0).toDouble(),
      dateStart: data['dateStart'] ?? '',
      dateStop: data['dateStop'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'spend': spend,
      'impressions': impressions,
      'clicks': clicks,
      'reach': reach,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
      'dateStart': dateStart,
      'dateStop': dateStop,
    };
  }
}

/// GHL Stats nested object
class GHLStats {
  final int leads;
  final int bookings;
  final int deposits;
  final int cashCollected;
  final double cashAmount;
  
  GHLStats({
    required this.leads,
    required this.bookings,
    required this.deposits,
    required this.cashCollected,
    required this.cashAmount,
  });
  
  factory GHLStats.fromMap(Map<String, dynamic> data) {
    return GHLStats(
      leads: data['leads'] ?? 0,
      bookings: data['bookings'] ?? 0,
      deposits: data['deposits'] ?? 0,
      cashCollected: data['cashCollected'] ?? 0,
      cashAmount: (data['cashAmount'] ?? 0).toDouble(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'leads': leads,
      'bookings': bookings,
      'deposits': deposits,
      'cashCollected': cashCollected,
      'cashAmount': cashAmount,
    };
  }
}

/// Ad model for the split collections schema
class Ad {
  final String adId;
  final String adName;
  
  // Parent references
  final String adSetId;
  final String adSetName;
  final String campaignId;
  final String campaignName;
  
  // Stats
  final FacebookStats facebookStats;
  final GHLStats ghlStats;
  
  // Computed Metrics
  final double profit;
  final double cpl;
  final double cpb;
  final double cpa;
  
  // Status
  final String status;
  
  // Timestamps
  final DateTime? lastUpdated;
  final DateTime? lastFacebookSync;
  final DateTime? lastGHLSync;
  final DateTime? createdAt;
  final String? firstInsightDate;
  final String? lastInsightDate;
  
  Ad({
    required this.adId,
    required this.adName,
    required this.adSetId,
    required this.adSetName,
    required this.campaignId,
    required this.campaignName,
    required this.facebookStats,
    required this.ghlStats,
    required this.profit,
    required this.cpl,
    required this.cpb,
    required this.cpa,
    required this.status,
    this.lastUpdated,
    this.lastFacebookSync,
    this.lastGHLSync,
    this.createdAt,
    this.firstInsightDate,
    this.lastInsightDate,
  });
  
  factory Ad.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Ad(
      adId: doc.id,
      adName: data['adName'] ?? '',
      adSetId: data['adSetId'] ?? '',
      adSetName: data['adSetName'] ?? '',
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      facebookStats: FacebookStats.fromMap(data['facebookStats'] ?? {}),
      ghlStats: GHLStats.fromMap(data['ghlStats'] ?? {}),
      profit: (data['profit'] ?? 0).toDouble(),
      cpl: (data['cpl'] ?? 0).toDouble(),
      cpb: (data['cpb'] ?? 0).toDouble(),
      cpa: (data['cpa'] ?? 0).toDouble(),
      status: data['status'] ?? 'ACTIVE',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      lastFacebookSync: (data['lastFacebookSync'] as Timestamp?)?.toDate(),
      lastGHLSync: (data['lastGHLSync'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      firstInsightDate: data['firstInsightDate'],
      lastInsightDate: data['lastInsightDate'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'adId': adId,
      'adName': adName,
      'adSetId': adSetId,
      'adSetName': adSetName,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'facebookStats': facebookStats.toMap(),
      'ghlStats': ghlStats.toMap(),
      'profit': profit,
      'cpl': cpl,
      'cpb': cpb,
      'cpa': cpa,
      'status': status,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'lastFacebookSync': lastFacebookSync != null ? Timestamp.fromDate(lastFacebookSync!) : null,
      'lastGHLSync': lastGHLSync != null ? Timestamp.fromDate(lastGHLSync!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'firstInsightDate': firstInsightDate,
      'lastInsightDate': lastInsightDate,
    };
  }
}

