import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for the main advertData document
class AdvertData {
  final String adId;
  final String adName;
  final String campaignId;
  final String campaignName;
  final String? adSetId;
  final String? adSetName;
  final DateTime? lastUpdated;
  final DateTime? lastFacebookSync;
  final DateTime? lastGHLSync;

  AdvertData({
    required this.adId,
    required this.adName,
    required this.campaignId,
    required this.campaignName,
    this.adSetId,
    this.adSetName,
    this.lastUpdated,
    this.lastFacebookSync,
    this.lastGHLSync,
  });

  factory AdvertData.fromFirestore(Map<String, dynamic> data, String docId) {
    return AdvertData(
      adId: docId,
      adName: data['adName'] ?? '',
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      adSetId: data['adSetId'],
      adSetName: data['adSetName'],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      lastFacebookSync: (data['lastFacebookSync'] as Timestamp?)?.toDate(),
      lastGHLSync: (data['lastGHLSync'] as Timestamp?)?.toDate(),
    );
  }
}

/// Model for Facebook weekly insights
class FacebookInsightWeekly {
  final String weekId;
  final DateTime dateStart;
  final DateTime dateStop;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;

  FacebookInsightWeekly({
    required this.weekId,
    required this.dateStart,
    required this.dateStop,
    required this.spend,
    required this.impressions,
    required this.reach,
    required this.clicks,
    required this.cpm,
    required this.cpc,
    required this.ctr,
  });

  factory FacebookInsightWeekly.fromFirestore(Map<String, dynamic> data, String weekId) {
    // Handle both Timestamp and String formats for dates
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }
    
    return FacebookInsightWeekly(
      weekId: weekId,
      dateStart: parseDate(data['dateStart']),
      dateStop: parseDate(data['dateStop']),
      spend: (data['spend'] ?? 0).toDouble(),
      impressions: data['impressions'] ?? 0,
      reach: data['reach'] ?? 0,
      clicks: data['clicks'] ?? 0,
      cpm: (data['cpm'] ?? 0).toDouble(),
      cpc: (data['cpc'] ?? 0).toDouble(),
      ctr: (data['ctr'] ?? 0).toDouble(),
    );
  }
}

/// Model for GHL weekly data
class GHLWeeklyData {
  final String weekId;
  final DateTime? dateStart;
  final DateTime? dateStop;
  final int leads;
  final int bookedAppointments;
  final int deposits;
  final int cashCollected;
  final double cashAmount; // Actual opportunity monetary values

  GHLWeeklyData({
    required this.weekId,
    this.dateStart,
    this.dateStop,
    required this.leads,
    required this.bookedAppointments,
    required this.deposits,
    required this.cashCollected,
    required this.cashAmount,
  });

  factory GHLWeeklyData.fromFirestore(Map<String, dynamic> data, String weekId) {
    // Handle both Timestamp and String formats for dates
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return null;
        }
      }
      return null;
    }
    
    return GHLWeeklyData(
      weekId: weekId,
      dateStart: parseDate(data['dateStart']),
      dateStop: parseDate(data['dateStop']),
      leads: data['leads'] ?? 0,
      bookedAppointments: data['bookedAppointments'] ?? 0,
      deposits: data['deposits'] ?? 0,
      cashCollected: data['cashCollected'] ?? 0,
      cashAmount: (data['cashAmount'] ?? 0).toDouble(),
    );
  }
}

/// Aggregated Facebook insights (totals from all weeks)
class FacebookInsightTotals {
  final double totalSpend;
  final int totalImpressions;
  final int totalReach;
  final int totalClicks;
  final double avgCPM;
  final double avgCPC;
  final double avgCTR;
  final String dateStart; // Earliest date
  final String dateStop;  // Latest date

  FacebookInsightTotals({
    required this.totalSpend,
    required this.totalImpressions,
    required this.totalReach,
    required this.totalClicks,
    required this.avgCPM,
    required this.avgCPC,
    required this.avgCTR,
    required this.dateStart,
    required this.dateStop,
  });

  /// Create totals from a list of weekly insights
  factory FacebookInsightTotals.fromWeeklyInsights(List<FacebookInsightWeekly> insights) {
    if (insights.isEmpty) {
      return FacebookInsightTotals(
        totalSpend: 0,
        totalImpressions: 0,
        totalReach: 0,
        totalClicks: 0,
        avgCPM: 0,
        avgCPC: 0,
        avgCTR: 0,
        dateStart: '',
        dateStop: '',
      );
    }

    double totalSpend = 0;
    int totalImpressions = 0;
    int totalReach = 0;
    int totalClicks = 0;
    DateTime? earliestDate;
    DateTime? latestDate;

    for (final insight in insights) {
      totalSpend += insight.spend;
      totalImpressions += insight.impressions;
      totalReach += insight.reach;
      totalClicks += insight.clicks;

      if (earliestDate == null || insight.dateStart.isBefore(earliestDate)) {
        earliestDate = insight.dateStart;
      }
      if (latestDate == null || insight.dateStop.isAfter(latestDate)) {
        latestDate = insight.dateStop;
      }
    }

    // Calculate averages
    final avgCPM = totalImpressions > 0 ? (totalSpend / totalImpressions) * 1000 : 0.0;
    final avgCPC = totalClicks > 0 ? totalSpend / totalClicks : 0.0;
    final avgCTR = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0.0;

    return FacebookInsightTotals(
      totalSpend: totalSpend,
      totalImpressions: totalImpressions,
      totalReach: totalReach,
      totalClicks: totalClicks,
      avgCPM: avgCPM.toDouble(),
      avgCPC: avgCPC.toDouble(),
      avgCTR: avgCTR.toDouble(),
      dateStart: earliestDate?.toIso8601String() ?? '',
      dateStop: latestDate?.toIso8601String() ?? '',
    );
  }
}

/// Aggregated GHL data (totals from all weeks)
class GHLDataTotals {
  final int totalLeads;
  final int totalBookedAppointments;
  final int totalDeposits;
  final int totalCashCollected;
  final double totalCashAmount; // Sum of actual opportunity monetary values

  GHLDataTotals({
    required this.totalLeads,
    required this.totalBookedAppointments,
    required this.totalDeposits,
    required this.totalCashCollected,
    required this.totalCashAmount,
  });

  /// Create totals from a list of weekly GHL data
  factory GHLDataTotals.fromWeeklyData(List<GHLWeeklyData> weeklyData) {
    if (weeklyData.isEmpty) {
      return GHLDataTotals(
        totalLeads: 0,
        totalBookedAppointments: 0,
        totalDeposits: 0,
        totalCashCollected: 0,
        totalCashAmount: 0,
      );
    }

    int totalLeads = 0;
    int totalBookedAppointments = 0;
    int totalDeposits = 0;
    int totalCashCollected = 0;
    double totalCashAmount = 0;

    for (final week in weeklyData) {
      totalLeads += week.leads;
      totalBookedAppointments += week.bookedAppointments;
      totalDeposits += week.deposits;
      totalCashCollected += week.cashCollected;
      totalCashAmount += week.cashAmount;
    }

    return GHLDataTotals(
      totalLeads: totalLeads,
      totalBookedAppointments: totalBookedAppointments,
      totalDeposits: totalDeposits,
      totalCashCollected: totalCashCollected,
      totalCashAmount: totalCashAmount,
    );
  }
}

/// Complete advert data with aggregated totals
class AdvertDataWithTotals {
  final AdvertData advert;
  final FacebookInsightTotals facebookTotals;
  final GHLDataTotals ghlTotals;

  AdvertDataWithTotals({
    required this.advert,
    required this.facebookTotals,
    required this.ghlTotals,
  });

  // Computed metrics

  /// Cost per lead (CPL)
  double get cpl {
    return ghlTotals.totalLeads > 0 
        ? facebookTotals.totalSpend / ghlTotals.totalLeads 
        : 0;
  }

  /// Cost per booking (CPB)
  double get cpb {
    return ghlTotals.totalBookedAppointments > 0 
        ? facebookTotals.totalSpend / ghlTotals.totalBookedAppointments 
        : 0;
  }

  /// Cost per acquisition/deposit (CPA)
  double get cpa {
    return ghlTotals.totalDeposits > 0 
        ? facebookTotals.totalSpend / ghlTotals.totalDeposits 
        : 0;
  }

  /// Profit (cash amount from opportunities - Facebook spend)
  /// Uses actual opportunity monetary values from GHL
  double get profit {
    return ghlTotals.totalCashAmount - facebookTotals.totalSpend;
  }

  /// Has GHL data
  bool get hasGHLData => ghlTotals.totalLeads > 0;

  /// Has Facebook data
  bool get hasFacebookData => facebookTotals.totalSpend > 0;
}

