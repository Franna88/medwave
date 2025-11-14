import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for querying pre-aggregated summary data
/// Summary structure: summary/{campaignId} with a weeks MAP field
/// Each week key format: "2025-11-03_2025-11-09"
/// Each week contains: campaign.facebookInsights, campaign.ghlData
class SummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate campaign totals from pre-aggregated summary data
  /// Fetches the summary document and aggregates data from the weeks map
  Future<Map<String, dynamic>?> calculateCampaignTotalsFromSummary({
    required String campaignId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching summary document for campaign $campaignId');
        print(
          '   Date range: ${startDate?.toIso8601String() ?? "any"} to ${endDate?.toIso8601String() ?? "any"}',
        );
      }

      // Fetch the summary document
      final summaryDoc = await _firestore
          .collection('summary')
          .doc(campaignId)
          .get();

      if (!summaryDoc.exists) {
        if (kDebugMode) {
          print('   ⚠️ No summary document found for campaign $campaignId');
        }
        return null;
      }

      final data = summaryDoc.data();
      if (data == null) {
        if (kDebugMode) {
          print('   ⚠️ Summary document has no data');
        }
        return null;
      }

      // Get the weeks map
      final weeksMap = data['weeks'] as Map<String, dynamic>?;
      if (weeksMap == null || weeksMap.isEmpty) {
        if (kDebugMode) {
          print('   ⚠️ No weeks data in summary document');
        }
        return null;
      }

      if (kDebugMode) {
        print('   ✅ Found ${weeksMap.length} weeks in summary');
        print('   📋 Week IDs: ${weeksMap.keys.take(3).join(", ")}...');
      }

      double totalSpend = 0;
      int totalImpressions = 0;
      int totalClicks = 0;
      int totalReach = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      int weeksUsed = 0;

      // Iterate through each week in the map
      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;
        final weekData = weekEntry.value as Map<String, dynamic>?;

        if (weekData == null) {
          if (kDebugMode) {
            print('   ⚠️ Week $weekId has no data');
          }
          continue;
        }

        // Check if this week overlaps with the date range
        if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
          if (kDebugMode) {
            print('   ⏭️ Skipping week $weekId (outside date range)');
          }
          continue;
        }

        if (kDebugMode) {
          print('   📅 Processing week: $weekId');
        }

        // Access the campaign data within this week
        final campaignData = weekData['campaign'] as Map<String, dynamic>?;
        if (campaignData == null) {
          if (kDebugMode) {
            print('   ⚠️ No campaign data in week $weekId');
          }
          continue;
        }

        // Extract Facebook Insights
        final fbInsights =
            campaignData['facebookInsights'] as Map<String, dynamic>?;
        if (fbInsights != null) {
          final weekSpend = (fbInsights['spend'] as num?)?.toDouble() ?? 0;
          final weekImpressions =
              (fbInsights['impressions'] as num?)?.toInt() ?? 0;
          final weekClicks = (fbInsights['clicks'] as num?)?.toInt() ?? 0;
          final weekReach = (fbInsights['reach'] as num?)?.toInt() ?? 0;

          totalSpend += weekSpend;
          totalImpressions += weekImpressions;
          totalClicks += weekClicks;
          totalReach += weekReach;

          if (kDebugMode) {
            print(
              '      FB: spend=\$${weekSpend.toStringAsFixed(2)}, '
              'impressions=$weekImpressions, clicks=$weekClicks',
            );
          }
        }

        // Extract GHL Data
        final ghlData = campaignData['ghlData'] as Map<String, dynamic>?;
        if (ghlData != null) {
          final weekLeads = (ghlData['leads'] as num?)?.toInt() ?? 0;
          final weekBookings =
              (ghlData['bookedAppointments'] as num?)?.toInt() ?? 0;
          final weekDeposits = (ghlData['deposits'] as num?)?.toInt() ?? 0;
          final weekCashCollected =
              (ghlData['cashCollected'] as num?)?.toInt() ?? 0;
          final weekCashAmount =
              (ghlData['cashAmount'] as num?)?.toDouble() ?? 0;

          totalLeads += weekLeads;
          totalBookings += weekBookings;
          totalDeposits += weekDeposits;
          totalCashCollected += weekCashCollected;
          totalCashAmount += weekCashAmount;

          if (kDebugMode) {
            print(
              '      GHL: leads=$weekLeads, bookings=$weekBookings, '
              'deposits=$weekDeposits, cashAmount=\$${weekCashAmount.toStringAsFixed(2)}',
            );
          }
        }

        weeksUsed++;
      }

      if (weeksUsed == 0) {
        if (kDebugMode) {
          print('   ⚠️ No weeks matched the date range');
        }
        return null;
      }

      // Calculate derived metrics
      final totalProfit = totalCashAmount - totalSpend;
      final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0;
      final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0;
      final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0;
      final roi = totalSpend > 0 ? (totalProfit / totalSpend) * 100 : 0;
      final ctr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0;
      final cpm = totalImpressions > 0
          ? (totalSpend / totalImpressions) * 1000
          : 0;
      final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0;

      if (kDebugMode) {
        print('   📊 Summary totals calculated:');
        print('      Spend: \$${totalSpend.toStringAsFixed(2)}');
        print('      Impressions: $totalImpressions');
        print('      Clicks: $totalClicks');
        print('      Leads: $totalLeads');
        print('      Bookings: $totalBookings');
        print('      Deposits: $totalDeposits');
        print('      Cash Amount: \$${totalCashAmount.toStringAsFixed(2)}');
        print('      Profit: \$${totalProfit.toStringAsFixed(2)}');
        print('      ROI: ${roi.toStringAsFixed(2)}%');
        print('      Weeks used: $weeksUsed');
      }

      return {
        'totalSpend': totalSpend,
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'totalReach': totalReach,
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
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': weeksUsed,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating campaign totals from summary: $e');
      }
      return null;
    }
  }

  /// Check if a week ID overlaps with the given date range
  /// Week ID format: "2025-10-27_2025-11-02"
  bool _weekIdOverlapsWithDateRange(
    String weekId,
    DateTime? filterStartDate,
    DateTime? filterEndDate,
  ) {
    try {
      final parts = weekId.split('_');
      if (parts.length != 2) return false;

      final startParts = parts[0].split('-');
      final endParts = parts[1].split('-');

      if (startParts.length != 3 || endParts.length != 3) return false;

      final weekStart = DateTime(
        int.parse(startParts[0]),
        int.parse(startParts[1]),
        int.parse(startParts[2]),
      );
      final weekEnd = DateTime(
        int.parse(endParts[0]),
        int.parse(endParts[1]),
        int.parse(endParts[2]),
      );

      // Check for overlap
      // Week starts before filter ends AND Week ends after filter starts
      final bool overlaps =
          (filterEndDate == null || !weekStart.isAfter(filterEndDate)) &&
          (filterStartDate == null || !weekEnd.isBefore(filterStartDate));

      return overlaps;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parsing week ID "$weekId": $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> calculateAdSetTotalsFromSummary({
    required String campaignId,
    required String adSetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 Fetching summary for ad set $adSetId in campaign $campaignId',
        );
      }

      // Fetch the summary document
      final summaryDoc = await _firestore
          .collection('summary')
          .doc(campaignId)
          .get();

      if (!summaryDoc.exists) {
        if (kDebugMode) {
          print('   ⚠️ No summary document found');
        }
        return null;
      }

      final data = summaryDoc.data();
      if (data == null) return null;

      // Get the weeks map
      final weeksMap = data['weeks'] as Map<String, dynamic>?;
      if (weeksMap == null || weeksMap.isEmpty) return null;

      double totalSpend = 0;
      int totalImpressions = 0;
      int totalClicks = 0;
      int totalReach = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      int weeksUsed = 0;

      // Iterate through each week in the map
      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;
        final weekData = weekEntry.value as Map<String, dynamic>?;

        if (weekData == null) continue;

        // Check if this week overlaps with the date range
        if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
          continue;
        }

        // Access the adSets map within this week
        final adSetsMap = weekData['adSets'] as Map<String, dynamic>?;
        if (adSetsMap == null) continue;

        // Get data for this specific ad set
        final adSetData = adSetsMap[adSetId] as Map<String, dynamic>?;
        if (adSetData == null) continue;

        if (kDebugMode) {
          print('   📅 Processing week: $weekId for ad set $adSetId');
        }

        // Extract Facebook Insights
        final fbInsights =
            adSetData['facebookInsights'] as Map<String, dynamic>?;
        if (fbInsights != null) {
          final weekSpend = (fbInsights['spend'] as num?)?.toDouble() ?? 0;
          final weekImpressions =
              (fbInsights['impressions'] as num?)?.toInt() ?? 0;
          final weekClicks = (fbInsights['clicks'] as num?)?.toInt() ?? 0;
          final weekReach = (fbInsights['reach'] as num?)?.toInt() ?? 0;

          totalSpend += weekSpend;
          totalImpressions += weekImpressions;
          totalClicks += weekClicks;
          totalReach += weekReach;
        }

        // Extract GHL Data
        final ghlData = adSetData['ghlData'] as Map<String, dynamic>?;
        if (ghlData != null) {
          final weekLeads = (ghlData['leads'] as num?)?.toInt() ?? 0;
          final weekBookings =
              (ghlData['bookedAppointments'] as num?)?.toInt() ?? 0;
          final weekDeposits = (ghlData['deposits'] as num?)?.toInt() ?? 0;
          final weekCashCollected =
              (ghlData['cashCollected'] as num?)?.toInt() ?? 0;
          final weekCashAmount =
              (ghlData['cashAmount'] as num?)?.toDouble() ?? 0;

          totalLeads += weekLeads;
          totalBookings += weekBookings;
          totalDeposits += weekDeposits;
          totalCashCollected += weekCashCollected;
          totalCashAmount += weekCashAmount;
        }

        weeksUsed++;
      }

      if (weeksUsed == 0) {
        if (kDebugMode) {
          print('   ⚠️ No weeks matched for ad set $adSetId');
        }
        return null;
      }

      // Calculate derived metrics
      final totalProfit = totalCashAmount - totalSpend;
      final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0;
      final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0;
      final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0;
      final roi = totalSpend > 0 ? (totalProfit / totalSpend) * 100 : 0;
      final ctr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0;
      final cpm = totalImpressions > 0
          ? (totalSpend / totalImpressions) * 1000
          : 0;
      final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0;

      if (kDebugMode) {
        print(
          '   ✅ Ad set totals: spend=\$${totalSpend.toStringAsFixed(2)}, '
          'leads=$totalLeads, profit=\$${totalProfit.toStringAsFixed(2)}',
        );
      }

      return {
        'totalSpend': totalSpend,
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'totalReach': totalReach,
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
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': weeksUsed,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating ad set totals from summary: $e');
      }
      return null;
    }
  }

  /// Calculate ad totals from pre-aggregated summary data
  /// Aggregates metrics for a specific ad from matching weeks
  Future<Map<String, dynamic>?> calculateAdTotalsFromSummary({
    required String campaignId,
    required String adId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching summary for ad $adId in campaign $campaignId');
      }

      // Fetch the summary document
      final summaryDoc = await _firestore
          .collection('summary')
          .doc(campaignId)
          .get();

      if (!summaryDoc.exists) {
        if (kDebugMode) {
          print('   ⚠️ No summary document found');
        }
        return null;
      }

      final data = summaryDoc.data();
      if (data == null) return null;

      // Get the weeks map
      final weeksMap = data['weeks'] as Map<String, dynamic>?;
      if (weeksMap == null || weeksMap.isEmpty) return null;

      double totalSpend = 0;
      int totalImpressions = 0;
      int totalClicks = 0;
      int totalReach = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      int weeksUsed = 0;

      // Iterate through each week in the map
      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;
        final weekData = weekEntry.value as Map<String, dynamic>?;

        if (weekData == null) continue;

        // Check if this week overlaps with the date range
        if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
          continue;
        }

        // Access the ads map within this week
        final adsMap = weekData['ads'] as Map<String, dynamic>?;
        if (adsMap == null) continue;

        // Get data for this specific ad
        final adData = adsMap[adId] as Map<String, dynamic>?;
        if (adData == null) continue;

        if (kDebugMode) {
          print('   📅 Processing week: $weekId for ad $adId');
        }

        // Extract Facebook Insights
        final fbInsights = adData['facebookInsights'] as Map<String, dynamic>?;
        if (fbInsights != null) {
          final weekSpend = (fbInsights['spend'] as num?)?.toDouble() ?? 0;
          final weekImpressions =
              (fbInsights['impressions'] as num?)?.toInt() ?? 0;
          final weekClicks = (fbInsights['clicks'] as num?)?.toInt() ?? 0;
          final weekReach = (fbInsights['reach'] as num?)?.toInt() ?? 0;

          totalSpend += weekSpend;
          totalImpressions += weekImpressions;
          totalClicks += weekClicks;
          totalReach += weekReach;
        }

        // Extract GHL Data
        final ghlData = adData['ghlData'] as Map<String, dynamic>?;
        if (ghlData != null) {
          final weekLeads = (ghlData['leads'] as num?)?.toInt() ?? 0;
          final weekBookings =
              (ghlData['bookedAppointments'] as num?)?.toInt() ?? 0;
          final weekDeposits = (ghlData['deposits'] as num?)?.toInt() ?? 0;
          final weekCashCollected =
              (ghlData['cashCollected'] as num?)?.toInt() ?? 0;
          final weekCashAmount =
              (ghlData['cashAmount'] as num?)?.toDouble() ?? 0;

          totalLeads += weekLeads;
          totalBookings += weekBookings;
          totalDeposits += weekDeposits;
          totalCashCollected += weekCashCollected;
          totalCashAmount += weekCashAmount;
        }

        weeksUsed++;
      }

      if (weeksUsed == 0) {
        if (kDebugMode) {
          print('   ⚠️ No weeks matched for ad $adId');
        }
        return null;
      }

      // Calculate derived metrics
      final totalProfit = totalCashAmount - totalSpend;
      final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0;
      final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0;
      final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0;
      final roi = totalSpend > 0 ? (totalProfit / totalSpend) * 100 : 0;
      final ctr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0;
      final cpm = totalImpressions > 0
          ? (totalSpend / totalImpressions) * 1000
          : 0;
      final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0;

      if (kDebugMode) {
        print(
          '   ✅ Ad totals: spend=\$${totalSpend.toStringAsFixed(2)}, '
          'leads=$totalLeads, profit=\$${totalProfit.toStringAsFixed(2)}',
        );
      }

      return {
        'totalSpend': totalSpend,
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'totalReach': totalReach,
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
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': weeksUsed,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating ad totals from summary: $e');
      }
      return null;
    }
  }

  /// Check if summary data exists for a campaign
  Future<bool> hasSummaryData(String campaignId) async {
    try {
      final doc = await _firestore.collection('summary').doc(campaignId).get();

      if (!doc.exists) return false;

      final data = doc.data();
      final weeksMap = data?['weeks'] as Map<String, dynamic>?;

      return weeksMap != null && weeksMap.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking for summary data: $e');
      }
      return false;
    }
  }
}
