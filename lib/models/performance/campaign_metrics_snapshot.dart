import 'package:cloud_firestore/cloud_firestore.dart';

/// Campaign Metrics Snapshot for time-series comparisons
class CampaignMetricsSnapshot {
  final String campaignId;
  final String campaignName;
  
  // Time Period
  final int year;
  final int month;
  final int week; // 0 for monthly snapshots
  final String weekStart;
  final String weekEnd;
  
  // Metrics (same as Campaign)
  final double totalSpend;
  final int totalImpressions;
  final int totalClicks;
  final int totalReach;
  final double avgCPM;
  final double avgCPC;
  final double avgCTR;
  final int totalLeads;
  final int totalBookings;
  final int totalDeposits;
  final int totalCashCollected;
  final double totalCashAmount;
  final double totalProfit;
  final double cpl;
  final double cpb;
  final double cpa;
  final double roi;
  final double leadToBookingRate;
  final double bookingToDepositRate;
  final double depositToCashRate;
  final int adSetCount;
  final int adCount;
  
  final DateTime? createdAt;
  
  CampaignMetricsSnapshot({
    required this.campaignId,
    required this.campaignName,
    required this.year,
    required this.month,
    required this.week,
    required this.weekStart,
    required this.weekEnd,
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
    this.createdAt,
  });
  
  factory CampaignMetricsSnapshot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CampaignMetricsSnapshot(
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      year: data['year'] ?? 0,
      month: data['month'] ?? 0,
      week: data['week'] ?? 0,
      weekStart: data['weekStart'] ?? '',
      weekEnd: data['weekEnd'] ?? '',
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
  
  /// Check if this is a monthly snapshot (week == 0)
  bool get isMonthlySnapshot => week == 0;
  
  /// Check if this is a weekly snapshot
  bool get isWeeklySnapshot => week > 0;
}

