import 'package:cloud_firestore/cloud_firestore.dart';

/// Campaign model for the split collections schema
class Campaign {
  final String campaignId;
  final String campaignName;
  final String status; // ACTIVE, RECENT, PAUSED, UNKNOWN

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
  final double cpl; // Cost per lead
  final double cpb; // Cost per booking
  final double cpa; // Cost per acquisition (deposit)
  final double roi; // Return on investment

  // Conversion Rates
  final double leadToBookingRate;
  final double bookingToDepositRate;
  final double depositToCashRate;

  // Counts
  final int adSetCount;
  final int adCount;

  // Timestamps
  final DateTime? lastUpdated;
  final DateTime? lastFacebookSync;
  final DateTime? lastGHLSync;
  final DateTime? createdAt;

  final String? firstAdDate;
  final String? lastAdDate;

  Campaign({
    required this.campaignId,
    required this.campaignName,
    required this.status,
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
    required this.roi,
    required this.leadToBookingRate,
    required this.bookingToDepositRate,
    required this.depositToCashRate,
    required this.adSetCount,
    required this.adCount,
    this.lastUpdated,
    this.lastFacebookSync,
    this.lastGHLSync,
    this.createdAt,
    this.firstAdDate,
    this.lastAdDate,
  });

  /// Create Campaign from Firestore document
  factory Campaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Campaign(
      campaignId: doc.id,
      campaignName: data['campaignName'] ?? '',
      status: data['status'] ?? 'UNKNOWN',
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
      roi: (data['roi'] ?? 0).toDouble(),
      leadToBookingRate: (data['leadToBookingRate'] ?? 0).toDouble(),
      bookingToDepositRate: (data['bookingToDepositRate'] ?? 0).toDouble(),
      depositToCashRate: (data['depositToCashRate'] ?? 0).toDouble(),
      adSetCount: data['adSetCount'] ?? 0,
      adCount: data['adCount'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      lastFacebookSync: (data['lastFacebookSync'] as Timestamp?)?.toDate(),
      lastGHLSync: (data['lastGHLSync'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      firstAdDate: _parseDateField(data['firstAdDate']),
      lastAdDate: _parseDateField(data['lastAdDate']),
    );
  }

  static String? _parseDateField(dynamic value) {
    if (value == null) return null;

    if (value is String) return value;

    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  DateTime? get firstAdDateAsDateTime {
    if (firstAdDate == null) return null;
    try {
      return DateTime.parse(firstAdDate!);
    } catch (e) {
      return null;
    }
  }

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
      'campaignId': campaignId,
      'campaignName': campaignName,
      'status': status,
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
      'roi': roi,
      'leadToBookingRate': leadToBookingRate,
      'bookingToDepositRate': bookingToDepositRate,
      'depositToCashRate': depositToCashRate,
      'adSetCount': adSetCount,
      'adCount': adCount,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : null,
      'lastFacebookSync': lastFacebookSync != null
          ? Timestamp.fromDate(lastFacebookSync!)
          : null,
      'lastGHLSync': lastGHLSync != null
          ? Timestamp.fromDate(lastGHLSync!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'firstAdDate': firstAdDate,
      'lastAdDate': lastAdDate,
    };
  }

  /// Create a copy with modified fields
  Campaign copyWith({
    String? campaignId,
    String? campaignName,
    String? status,
    double? totalSpend,
    int? totalImpressions,
    int? totalClicks,
    int? totalReach,
    double? avgCPM,
    double? avgCPC,
    double? avgCTR,
    int? totalLeads,
    int? totalBookings,
    int? totalDeposits,
    int? totalCashCollected,
    double? totalCashAmount,
    double? totalProfit,
    double? cpl,
    double? cpb,
    double? cpa,
    double? roi,
    double? leadToBookingRate,
    double? bookingToDepositRate,
    double? depositToCashRate,
    int? adSetCount,
    int? adCount,
    DateTime? lastUpdated,
    DateTime? lastFacebookSync,
    DateTime? lastGHLSync,
    DateTime? createdAt,
    String? firstAdDate,
    String? lastAdDate,
  }) {
    return Campaign(
      campaignId: campaignId ?? this.campaignId,
      campaignName: campaignName ?? this.campaignName,
      status: status ?? this.status,
      totalSpend: totalSpend ?? this.totalSpend,
      totalImpressions: totalImpressions ?? this.totalImpressions,
      totalClicks: totalClicks ?? this.totalClicks,
      totalReach: totalReach ?? this.totalReach,
      avgCPM: avgCPM ?? this.avgCPM,
      avgCPC: avgCPC ?? this.avgCPC,
      avgCTR: avgCTR ?? this.avgCTR,
      totalLeads: totalLeads ?? this.totalLeads,
      totalBookings: totalBookings ?? this.totalBookings,
      totalDeposits: totalDeposits ?? this.totalDeposits,
      totalCashCollected: totalCashCollected ?? this.totalCashCollected,
      totalCashAmount: totalCashAmount ?? this.totalCashAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      cpl: cpl ?? this.cpl,
      cpb: cpb ?? this.cpb,
      cpa: cpa ?? this.cpa,
      roi: roi ?? this.roi,
      leadToBookingRate: leadToBookingRate ?? this.leadToBookingRate,
      bookingToDepositRate: bookingToDepositRate ?? this.bookingToDepositRate,
      depositToCashRate: depositToCashRate ?? this.depositToCashRate,
      adSetCount: adSetCount ?? this.adSetCount,
      adCount: adCount ?? this.adCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastFacebookSync: lastFacebookSync ?? this.lastFacebookSync,
      lastGHLSync: lastGHLSync ?? this.lastGHLSync,
      createdAt: createdAt ?? this.createdAt,
      firstAdDate: firstAdDate ?? this.firstAdDate,
      lastAdDate: lastAdDate ?? this.lastAdDate,
    );
  }
}
