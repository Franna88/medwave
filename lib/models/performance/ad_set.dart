import 'package:cloud_firestore/cloud_firestore.dart';

/// Ad Set model for the split collections schema
class AdSet {
  final String adSetId;
  final String adSetName;

  // Parent Campaign
  final String campaignId;
  final String campaignName;

  // Facebook Metrics
  final double totalSpend;
  final int totalImpressions;
  final int totalClicks;
  final int totalReach;
  final double avgCPM;
  final double avgCPC;
  final double avgCTR;

  // GHL Metrics
  final int totalLeads;
  final int totalBookings;
  final int totalDeposits;
  final int totalCashCollected;
  final double totalCashAmount;

  // Computed Metrics
  final double totalProfit;
  final double cpl;
  final double cpb;
  final double cpa;

  // Counts
  final int adCount;

  // Timestamps
  final DateTime? lastUpdated;
  final DateTime? createdAt;

  // Date fields as YYYY-MM-DD strings (backward compatible with Timestamp)
  final String? firstAdDate;
  final String? lastAdDate;

  AdSet({
    required this.adSetId,
    required this.adSetName,
    required this.campaignId,
    required this.campaignName,
    required this.totalSpend,
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalReach,
    required this.avgCPM,
    required this.avgCPC,
    required this.avgCTR,
    required this.totalLeads,
    required this.totalBookings,
    required this.totalDeposits,
    required this.totalCashCollected,
    required this.totalCashAmount,
    required this.totalProfit,
    required this.cpl,
    required this.cpb,
    required this.cpa,
    required this.adCount,
    this.lastUpdated,
    this.createdAt,
    this.firstAdDate,
    this.lastAdDate,
  });

  factory AdSet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AdSet(
      adSetId: doc.id,
      adSetName: data['adSetName'] ?? '',
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      totalSpend: (data['totalSpend'] ?? 0).toDouble(),
      totalImpressions: data['totalImpressions'] ?? 0,
      totalClicks: data['totalClicks'] ?? 0,
      totalReach: data['totalReach'] ?? 0,
      avgCPM: (data['avgCPM'] ?? 0).toDouble(),
      avgCPC: (data['avgCPC'] ?? 0).toDouble(),
      avgCTR: (data['avgCTR'] ?? 0).toDouble(),
      totalLeads: data['totalLeads'] ?? 0,
      totalBookings: data['totalBookings'] ?? 0,
      totalDeposits: data['totalDeposits'] ?? 0,
      totalCashCollected: data['totalCashCollected'] ?? 0,
      totalCashAmount: (data['totalCashAmount'] ?? 0).toDouble(),
      totalProfit: (data['totalProfit'] ?? 0).toDouble(),
      cpl: (data['cpl'] ?? 0).toDouble(),
      cpb: (data['cpb'] ?? 0).toDouble(),
      cpa: (data['cpa'] ?? 0).toDouble(),
      adCount: data['adCount'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      firstAdDate: _parseDateField(data['firstAdDate']),
      lastAdDate: _parseDateField(data['lastAdDate']),
    );
  }

  /// Parse date field from Firestore (handles both Timestamp and String)
  static String? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;

    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  /// Get firstAdDate as DateTime for UI compatibility
  DateTime? get firstAdDateAsDateTime {
    if (firstAdDate == null) return null;
    try {
      return DateTime.parse(firstAdDate!);
    } catch (e) {
      return null;
    }
  }

  /// Get lastAdDate as DateTime for UI compatibility
  DateTime? get lastAdDateAsDateTime {
    if (lastAdDate == null) return null;
    try {
      return DateTime.parse(lastAdDate!);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'adSetId': adSetId,
      'adSetName': adSetName,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'totalSpend': totalSpend,
      'totalImpressions': totalImpressions,
      'totalClicks': totalClicks,
      'totalReach': totalReach,
      'avgCPM': avgCPM,
      'avgCPC': avgCPC,
      'avgCTR': avgCTR,
      'totalLeads': totalLeads,
      'totalBookings': totalBookings,
      'totalDeposits': totalDeposits,
      'totalCashCollected': totalCashCollected,
      'totalCashAmount': totalCashAmount,
      'totalProfit': totalProfit,
      'cpl': cpl,
      'cpb': cpb,
      'cpa': cpa,
      'adCount': adCount,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'firstAdDate': firstAdDate,
      'lastAdDate': lastAdDate,
    };
  }
}
