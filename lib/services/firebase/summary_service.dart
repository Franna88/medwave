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

        // Calculate GHL Data from opportunities (aggregate from ad-level)
        // Get all ads in this campaign from this week
        final adsMap = weekData['ads'] as Map<String, dynamic>?;
        if (adsMap != null) {
          // Parse weekId to get week start/end dates
          DateTime? weekStartDate;
          DateTime? weekEndDate;
          try {
            final parts = weekId.split('_');
            if (parts.length == 2) {
              final startParts = parts[0].split('-');
              final endParts = parts[1].split('-');
              if (startParts.length == 3 && endParts.length == 3) {
                weekStartDate = DateTime(
                  int.parse(startParts[0]),
                  int.parse(startParts[1]),
                  int.parse(startParts[2]),
                );
                weekEndDate = DateTime(
                  int.parse(endParts[0]),
                  int.parse(endParts[1]),
                  int.parse(endParts[2]),
                  23,
                  59,
                  59,
                  999,
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('      ⚠️ Error parsing week dates: $e');
            }
          }

          if (weekStartDate != null && weekEndDate != null) {
            // Get all GHL metrics from campaignData ghlData
            final ghlData = campaignData['ghlData'] as Map<String, dynamic>?;
            final weekLeads = (ghlData?['leads'] as num?)?.toInt() ?? 0;
            final weekBookings =
                (ghlData?['bookedAppointments'] as num?)?.toInt() ?? 0;
            final weekDeposits = (ghlData?['deposits'] as num?)?.toInt() ?? 0;
            final weekCashCollected =
                (ghlData?['cashCollected'] as num?)?.toInt() ?? 0;
            final weekCashAmount =
                (ghlData?['cashAmount'] as num?)?.toDouble() ?? 0.0;

            // Aggregate to totals - all metrics from ghlData
            totalLeads += weekLeads;
            totalBookings += weekBookings;
            totalDeposits += weekDeposits;
            totalCashCollected += weekCashCollected;
            totalCashAmount += weekCashAmount;

            if (kDebugMode) {
              print(
                '      GHL: leads=$weekLeads, bookings=$weekBookings, '
                'deposits=$weekDeposits, cashAmount=\$${weekCashAmount.toStringAsFixed(2)} '
                '(all from ghlData)',
              );
            }
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

        // Calculate GHL Data from opportunities (aggregate from ad-level)
        // Get all ads in this ad set from this week
        final adsMap = weekData['ads'] as Map<String, dynamic>?;
        if (adsMap != null) {
          // Parse weekId to get week start/end dates
          DateTime? weekStartDate;
          DateTime? weekEndDate;
          try {
            final parts = weekId.split('_');
            if (parts.length == 2) {
              final startParts = parts[0].split('-');
              final endParts = parts[1].split('-');
              if (startParts.length == 3 && endParts.length == 3) {
                weekStartDate = DateTime(
                  int.parse(startParts[0]),
                  int.parse(startParts[1]),
                  int.parse(startParts[2]),
                );
                weekEndDate = DateTime(
                  int.parse(endParts[0]),
                  int.parse(endParts[1]),
                  int.parse(endParts[2]),
                  23,
                  59,
                  59,
                  999,
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('   ⚠️ Error parsing week dates: $e');
            }
          }

          if (weekStartDate != null && weekEndDate != null) {
            // Get counts from adSetData ghlData
            final ghlData = adSetData['ghlData'] as Map<String, dynamic>?;
            final weekLeads = (ghlData?['leads'] as num?)?.toInt() ?? 0;
            final weekBookings =
                (ghlData?['bookedAppointments'] as num?)?.toInt() ?? 0;
            final weekDeposits = (ghlData?['deposits'] as num?)?.toInt() ?? 0;
            final weekCashCollected =
                (ghlData?['cashCollected'] as num?)?.toInt() ?? 0;

            // Aggregate cashAmount from ads that belong to this ad set
            double weekCashAmount = 0.0;
            for (var adEntry in adsMap.entries) {
              final adData = adEntry.value as Map<String, dynamic>?;
              final adAdSetId = adData?['adSetId'] as String?;
              if (adAdSetId == adSetId) {
                final adGhlData = adData?['ghlData'] as Map<String, dynamic>?;
                final adCashAmount =
                    (adGhlData?['cashAmount'] as num?)?.toDouble() ?? 0.0;
                weekCashAmount += adCashAmount;
              }
            }

            // Aggregate to totals - counts from ad set ghlData, cashAmount from ads
            totalLeads += weekLeads;
            totalBookings += weekBookings;
            totalDeposits += weekDeposits;
            totalCashCollected += weekCashCollected;
            totalCashAmount += weekCashAmount;

            if (kDebugMode) {
              print(
                '   │    💰 Ad set GHL metrics for week: leads=$weekLeads, '
                'bookings=$weekBookings, deposits=$weekDeposits (from ad set ghlData), '
                'cash=\$${weekCashAmount.toStringAsFixed(2)} (aggregated from ads)',
              );
            }
          }
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
      if (weeksMap == null || weeksMap.isEmpty) {
        if (kDebugMode) {
          print('   ⚠️ No weeks map in summary document');
        }
        return null;
      }

      if (kDebugMode) {
        print('   📋 Found ${weeksMap.length} weeks in summary document');
        print('   🔍 Looking for ad ID: $adId');
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
      int weeksChecked = 0;
      int weeksWithOverlap = 0;
      int weeksWithAdsMap = 0;
      int weeksWithAdFound = 0;

      // Iterate through each week in the map
      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;
        final weekData = weekEntry.value as Map<String, dynamic>?;
        weeksChecked++;

        if (weekData == null) {
          if (kDebugMode) {
            print('   ⚠️ Week $weekId has null weekData');
          }
          continue;
        }

        // Check if this week overlaps with the date range
        final overlaps = _weekIdOverlapsWithDateRange(
          weekId,
          startDate,
          endDate,
        );
        if (!overlaps) {
          if (kDebugMode) {
            print('   ⏭️ Week $weekId does NOT overlap with date range');
          }
          continue;
        }
        weeksWithOverlap++;

        // Access the ads map within this week
        final adsMap = weekData['ads'] as Map<String, dynamic>?;
        if (adsMap == null) {
          if (kDebugMode) {
            print('   ⚠️ Week $weekId has no ads map');
          }
          continue;
        }
        weeksWithAdsMap++;

        if (kDebugMode) {
          final adIdsInWeek = adsMap.keys.toList();
          print('   📅 Week $weekId overlaps with date range');
          print(
            '   │    Found ${adIdsInWeek.length} ads in this week\'s ads map',
          );
          print(
            '   │    Ad IDs in week: ${adIdsInWeek.take(5).join(", ")}${adIdsInWeek.length > 5 ? "..." : ""}',
          );
          print('   │    Looking for: $adId');
        }

        // Get data for this specific ad
        final adData = adsMap[adId] as Map<String, dynamic>?;
        if (adData == null) {
          if (kDebugMode) {
            print('   │    ❌ Ad $adId NOT FOUND in this week\'s ads map');
          }
          continue;
        }
        weeksWithAdFound++;
        weeksUsed++;

        if (kDebugMode) {
          print('   │    ✅ Ad $adId FOUND in this week\'s ads map');
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

          if (kDebugMode) {
            print(
              '   │    💰 Week data: spend=\$${weekSpend.toStringAsFixed(2)}, impressions=$weekImpressions, clicks=$weekClicks',
            );
            print(
              '   │    📊 Running totals: spend=\$${totalSpend.toStringAsFixed(2)}, impressions=$totalImpressions',
            );
          }
        } else {
          if (kDebugMode) {
            print('   │    ⚠️ No facebookInsights in adData for this week');
          }
        }

        // Get all GHL metrics from adData ghlData
        final ghlData = adData['ghlData'] as Map<String, dynamic>?;
        final weekLeads = (ghlData?['leads'] as num?)?.toInt() ?? 0;
        final weekBookings =
            (ghlData?['bookedAppointments'] as num?)?.toInt() ?? 0;
        final weekDeposits = (ghlData?['deposits'] as num?)?.toInt() ?? 0;
        final weekCashCollected =
            (ghlData?['cashCollected'] as num?)?.toInt() ?? 0;
        final weekCashAmount =
            (ghlData?['cashAmount'] as num?)?.toDouble() ?? 0.0;

        // Aggregate to totals - all metrics from ghlData
        totalLeads += weekLeads;
        totalBookings += weekBookings;
        totalDeposits += weekDeposits;
        totalCashCollected += weekCashCollected;
        totalCashAmount += weekCashAmount;

        if (kDebugMode) {
          print(
            '   │    💰 Ad GHL metrics for week: leads=$weekLeads, '
            'bookings=$weekBookings, deposits=$weekDeposits, '
            'cash=\$${weekCashAmount.toStringAsFixed(2)} (all from ghlData)',
          );
        }

        weeksUsed++;
      }

      if (kDebugMode) {
        print('   ───────────────────────────────────────────────────────────');
        print('   📊 AD SUMMARY SEARCH RESULTS:');
        print('   │ Weeks checked: $weeksChecked');
        print('   │ Weeks with overlap: $weeksWithOverlap');
        print('   │ Weeks with ads map: $weeksWithAdsMap');
        print('   │ Weeks with ad found: $weeksWithAdFound');
        print('   │ Weeks used (final): $weeksUsed');
        print('   ───────────────────────────────────────────────────────────');
      }

      if (weeksUsed == 0) {
        if (kDebugMode) {
          print('   ❌ RESULT: No weeks matched for ad $adId');
          print(
            '   │    Reason: Ad not found in any overlapping week\'s ads map',
          );
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
        print('   ✅ RESULT: Ad totals calculated');
        print('   │    Spend: \$${totalSpend.toStringAsFixed(2)}');
        print('   │    Impressions: $totalImpressions');
        print('   │    Clicks: $totalClicks');
        print('   │    Leads: $totalLeads');
        print('   │    Profit: \$${totalProfit.toStringAsFixed(2)}');
        print('   │    Weeks used: $weeksUsed');
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

  // ============================================================================
  // COMPARISON-SPECIFIC METHODS
  // These methods are optimized for comparison queries, returning full metrics
  // maps that can be directly used by ComparisonService
  // ============================================================================

  /// Get campaign metrics for comparison from summary collection
  /// Returns metrics map suitable for ComparisonResult.fromMetricsMap()
  Future<Map<String, dynamic>> calculateCampaignTotalsFromSummaryForComparison({
    required String campaignId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final totals = await calculateCampaignTotalsFromSummary(
      campaignId: campaignId,
      startDate: startDate,
      endDate: endDate,
    );

    if (totals == null) {
      // Return zero metrics if no data found
      return _createZeroMetrics();
    }

    // Add ROI and average metrics for campaigns
    final spend = totals['totalSpend'] as double;
    final profit = totals['totalProfit'] as double;
    final impressions = totals['totalImpressions'] as int;
    final clicks = totals['totalClicks'] as int;

    final roi = spend > 0 ? (profit / spend) * 100 : 0.0;
    final avgCPM = impressions > 0 ? (spend / impressions) * 1000 : 0.0;
    final avgCPC = clicks > 0 ? spend / clicks : 0.0;
    final avgCTR = impressions > 0 ? (clicks / impressions) * 100 : 0.0;

    return {
      ...totals,
      'roi': roi,
      'avgCPM': avgCPM,
      'avgCPC': avgCPC,
      'avgCTR': avgCTR,
    };
  }

  /// Get ad set metrics for comparison from summary collection
  /// Returns metrics map suitable for ComparisonResult.fromMetricsMap()
  Future<Map<String, dynamic>> calculateAdSetTotalsFromSummaryForComparison({
    required String campaignId,
    required String adSetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final totals = await calculateAdSetTotalsFromSummary(
      campaignId: campaignId,
      adSetId: adSetId,
      startDate: startDate,
      endDate: endDate,
    );

    if (totals == null) {
      // Return zero metrics if no data found
      return _createZeroMetrics();
    }

    // Add average metrics for ad sets
    final spend = totals['totalSpend'] as double;
    final impressions = totals['totalImpressions'] as int;
    final clicks = totals['totalClicks'] as int;

    final avgCPM = impressions > 0 ? (spend / impressions) * 1000 : 0.0;
    final avgCPC = clicks > 0 ? spend / clicks : 0.0;
    final avgCTR = impressions > 0 ? (clicks / impressions) * 100 : 0.0;

    return {...totals, 'avgCPM': avgCPM, 'avgCPC': avgCPC, 'avgCTR': avgCTR};
  }

  /// Get ad metrics for comparison from summary collection
  /// Returns metrics map suitable for ComparisonResult.fromMetricsMap()
  Future<Map<String, dynamic>> calculateAdTotalsFromSummaryForComparison({
    required String campaignId,
    required String adId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final totals = await calculateAdTotalsFromSummary(
      campaignId: campaignId,
      adId: adId,
      startDate: startDate,
      endDate: endDate,
    );

    if (totals == null) {
      // Return zero metrics if no data found
      return _createZeroMetrics();
    }

    // Ad metrics are already complete from calculateAdTotalsFromSummary
    return totals;
  }

  /// Get all campaign IDs that have summary data with activity in date range
  Future<List<String>> getCampaignIdsWithActivityInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 Fetching campaign IDs with activity from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
      }

      // Query all summary documents
      final snapshot = await _firestore.collection('summary').get();

      final campaignIds = <String>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final weeksMap = data['weeks'] as Map<String, dynamic>?;

        if (weeksMap == null || weeksMap.isEmpty) continue;

        // Check if any week overlaps with the date range
        bool hasActivity = false;
        for (final weekId in weeksMap.keys) {
          if (_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
            hasActivity = true;
            break;
          }
        }

        if (hasActivity) {
          campaignIds.add(doc.id);
        }
      }

      if (kDebugMode) {
        print('   ✅ Found ${campaignIds.length} campaigns with activity');
      }

      return campaignIds;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching campaign IDs: $e');
      }
      return [];
    }
  }

  /// Get campaign IDs with names that have activity in date range (optimized)
  /// Returns a map of campaignId -> campaignName
  Future<Map<String, String>> getCampaignsWithActivityInDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String countryFilter = 'all',
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 Fetching campaigns with names from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
      }

      // Query all summary documents
      final snapshot = await _firestore.collection('summary').get();

      final campaigns = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Country filtering based on usaAds flag
        final usaAds = data['usaAds'] as bool?;
        bool matchesCountry = true;

        if (countryFilter == 'usa') {
          matchesCountry = usaAds == true;
        } else if (countryFilter == 'sa') {
          // South Africa: either field missing or explicitly false
          matchesCountry = usaAds != true;
        }

        if (!matchesCountry) {
          continue;
        }
        final weeksMap = data['weeks'] as Map<String, dynamic>?;

        if (weeksMap == null || weeksMap.isEmpty) continue;

        // Check if any week overlaps with the date range
        bool hasActivity = false;
        for (final weekId in weeksMap.keys) {
          if (_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
            hasActivity = true;
            break;
          }
        }

        if (hasActivity) {
          final campaignName =
              data['campaignName'] as String? ?? 'Unknown Campaign';
          campaigns[doc.id] = campaignName;
        }
      }

      if (kDebugMode) {
        print('   ✅ Found ${campaigns.length} campaigns with activity');
      }

      return campaigns;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching campaigns: $e');
      }
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getCampaignsWithCalculatedTotals({
    required DateTime startDate,
    required DateTime endDate,
    String countryFilter = 'all',
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🚀 OPTIMIZED: Fetching campaigns with calculated totals (single pass)',
        );
        print(
          '   Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
        print('   Country filter: $countryFilter');
      }

      // Fetch ALL summary documents ONCE
      final snapshot = await _firestore.collection('summary').get();

      if (kDebugMode) {
        print('   📦 Fetched ${snapshot.docs.length} summary documents');
      }

      List<Map<String, dynamic>> campaigns = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // 1. Country filter check
        final usaAds = data['usaAds'] as bool?;
        if (countryFilter == 'usa' && usaAds != true) continue;
        if (countryFilter == 'sa' && usaAds == true) continue;

        final weeksMap = data['weeks'] as Map<String, dynamic>?;
        if (weeksMap == null || weeksMap.isEmpty) continue;

        // 2. Calculate totals inline (same logic as calculateCampaignTotalsFromSummary)
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

        // 3. Extract date ranges and ad set count
        List<DateTime> weekStartDates = [];
        List<DateTime> weekEndDates = [];
        Set<String> adSetIds = {};

        for (var weekEntry in weeksMap.entries) {
          final weekId = weekEntry.key;

          // Check if week overlaps with date range
          if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
            continue;
          }

          final weekData = weekEntry.value as Map<String, dynamic>?;
          if (weekData == null) continue;

          // Parse week dates for firstAdDate/lastAdDate
          try {
            final parts = weekId.split('_');
            if (parts.length == 2) {
              final startParts = parts[0].split('-');
              final endParts = parts[1].split('-');

              if (startParts.length == 3 && endParts.length == 3) {
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
                weekStartDates.add(weekStart);
                weekEndDates.add(weekEnd);
              }
            }
          } catch (e) {
            // Skip invalid week IDs
          }

          // Collect ad set IDs
          final adSetsMap = weekData['adSets'] as Map<String, dynamic>?;
          if (adSetsMap != null) {
            adSetIds.addAll(adSetsMap.keys);
          }

          // Aggregate Facebook metrics from campaign data
          final campaignData = weekData['campaign'] as Map<String, dynamic>?;
          if (campaignData != null) {
            final fbInsights =
                campaignData['facebookInsights'] as Map<String, dynamic>?;
            if (fbInsights != null) {
              totalSpend += (fbInsights['spend'] as num?)?.toDouble() ?? 0.0;
              totalImpressions +=
                  (fbInsights['impressions'] as num?)?.toInt() ?? 0;
              totalClicks += (fbInsights['clicks'] as num?)?.toInt() ?? 0;
              totalReach += (fbInsights['reach'] as num?)?.toInt() ?? 0;
            }

            // Aggregate GHL metrics from campaign ghlData
            final ghlData = campaignData['ghlData'] as Map<String, dynamic>?;
            if (ghlData != null) {
              totalLeads += (ghlData['leads'] as num?)?.toInt() ?? 0;
              totalBookings +=
                  (ghlData['bookedAppointments'] as num?)?.toInt() ?? 0;
              totalDeposits += (ghlData['deposits'] as num?)?.toInt() ?? 0;
              totalCashCollected +=
                  (ghlData['cashCollected'] as num?)?.toInt() ?? 0;
              totalCashAmount +=
                  (ghlData['cashAmount'] as num?)?.toDouble() ?? 0.0;
            }
          }

          weeksUsed++;
        }

        // Only add campaign if it has activity in the date range
        if (weeksUsed == 0) continue;

        // Calculate derived metrics
        final totalProfit = totalCashAmount - totalSpend;
        final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0.0;
        final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0.0;
        final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0.0;
        final roi = totalSpend > 0 ? (totalProfit / totalSpend) * 100 : 0.0;
        final ctr = totalImpressions > 0
            ? (totalClicks / totalImpressions) * 100
            : 0.0;
        final cpm = totalImpressions > 0
            ? (totalSpend / totalImpressions) * 1000
            : 0.0;
        final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0.0;

        // Calculate first and last ad dates
        String? firstAdDate;
        String? lastAdDate;
        if (weekStartDates.isNotEmpty) {
          weekStartDates.sort();
          weekEndDates.sort();
          final earliest = weekStartDates.first;
          final latest = weekEndDates.last;

          firstAdDate =
              '${earliest.year}-${earliest.month.toString().padLeft(2, '0')}-${earliest.day.toString().padLeft(2, '0')}';
          lastAdDate =
              '${latest.year}-${latest.month.toString().padLeft(2, '0')}-${latest.day.toString().padLeft(2, '0')}';
        }

        campaigns.add({
          'campaignId': doc.id,
          'campaignName': data['campaignName'] as String? ?? 'Unknown Campaign',
          'totals': {
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
          },
          'firstAdDate': firstAdDate,
          'lastAdDate': lastAdDate,
          'adSetCount': adSetIds.length,
        });
      }

      if (kDebugMode) {
        print(
          '   ✅ Found ${campaigns.length} campaigns with calculated totals',
        );
      }

      return campaigns;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in getCampaignsWithCalculatedTotals: $e');
      }
      return [];
    }
  }

  /// Get all ad set IDs for a campaign that have activity in date range
  Future<List<String>> getAdSetIdsWithActivityInDateRange({
    required String campaignId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 Fetching ad set IDs for campaign $campaignId with activity from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
      }

      // Get the summary document for this campaign
      final summaryDoc = await _firestore
          .collection('summary')
          .doc(campaignId)
          .get();

      if (!summaryDoc.exists) {
        if (kDebugMode) {
          print('   ⚠️ No summary document found');
        }
        return [];
      }

      final data = summaryDoc.data();
      if (data == null) return [];

      final weeksMap = data['weeks'] as Map<String, dynamic>?;
      if (weeksMap == null || weeksMap.isEmpty) return [];

      // Collect all unique ad set IDs from weeks that overlap with date range
      final adSetIds = <String>{};

      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;

        if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
          continue;
        }

        final weekData = weekEntry.value as Map<String, dynamic>?;
        if (weekData == null) continue;

        final adSetsMap = weekData['adSets'] as Map<String, dynamic>?;
        if (adSetsMap != null) {
          adSetIds.addAll(adSetsMap.keys);
        }
      }

      if (kDebugMode) {
        print('   ✅ Found ${adSetIds.length} ad sets with activity');
      }

      return adSetIds.toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad set IDs: $e');
      }
      return [];
    }
  }

  /// Get all ad IDs for an ad set that have activity in date range
  Future<List<String>> getAdIdsWithActivityInDateRange({
    required String campaignId,
    required String adSetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📊 Fetching ad IDs for ad set $adSetId with activity from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        );
      }

      // Get the summary document for this campaign
      final summaryDoc = await _firestore
          .collection('summary')
          .doc(campaignId)
          .get();

      if (!summaryDoc.exists) {
        if (kDebugMode) {
          print('   ⚠️ No summary document found');
        }
        return [];
      }

      final data = summaryDoc.data();
      if (data == null) return [];

      final weeksMap = data['weeks'] as Map<String, dynamic>?;
      if (weeksMap == null || weeksMap.isEmpty) return [];

      // Collect all unique ad IDs from weeks that overlap with date range
      final adIds = <String>{};
      int weeksChecked = 0;
      int weeksWithOverlap = 0;
      int weeksWithAdsMap = 0;
      int adsFoundTotal = 0;

      for (var weekEntry in weeksMap.entries) {
        final weekId = weekEntry.key;
        weeksChecked++;

        if (!_weekIdOverlapsWithDateRange(weekId, startDate, endDate)) {
          if (kDebugMode) {
            print('   ⏭️ Week $weekId does NOT overlap with date range');
          }
          continue;
        }
        weeksWithOverlap++;

        final weekData = weekEntry.value as Map<String, dynamic>?;
        if (weekData == null) {
          if (kDebugMode) {
            print('   ⚠️ Week $weekId has null weekData');
          }
          continue;
        }

        final adsMap = weekData['ads'] as Map<String, dynamic>?;
        if (adsMap == null) {
          if (kDebugMode) {
            print('   ⚠️ Week $weekId has no ads map');
          }
          continue;
        }
        weeksWithAdsMap++;

        if (kDebugMode) {
          final allAdIds = adsMap.keys.toList();
          print('   📅 Week $weekId overlaps with date range');
          print(
            '   │    Found ${allAdIds.length} total ads in this week\'s ads map',
          );
          print('   │    Looking for ads in ad set: $adSetId');
        }

        // Filter ads by ad set ID
        int adsFoundInWeek = 0;
        for (var adEntry in adsMap.entries) {
          final adId = adEntry.key;
          final adData = adEntry.value as Map<String, dynamic>?;

          if (adData == null) {
            if (kDebugMode) {
              print('   │    ⚠️ Ad $adId has null adData');
            }
            continue;
          }

          final adDataAdSetId = adData['adSetId'];
          if (adDataAdSetId == adSetId) {
            adIds.add(adId);
            adsFoundInWeek++;
            adsFoundTotal++;

            if (kDebugMode) {
              print('   │    ✅ Ad $adId belongs to ad set $adSetId');
            }
          } else {
            if (kDebugMode) {
              print(
                '   │    ⏭️ Ad $adId belongs to ad set $adDataAdSetId (not $adSetId)',
              );
            }
          }
        }

        if (kDebugMode) {
          print(
            '   │    Found $adsFoundInWeek ads for ad set $adSetId in this week',
          );
        }
      }

      if (kDebugMode) {
        print('   ───────────────────────────────────────────────────────────');
        print('   📊 AD ID SEARCH RESULTS:');
        print('   │ Weeks checked: $weeksChecked');
        print('   │ Weeks with overlap: $weeksWithOverlap');
        print('   │ Weeks with ads map: $weeksWithAdsMap');
        print('   │ Total ads found for ad set: $adsFoundTotal');
        print('   │ Unique ad IDs: ${adIds.length}');
        print('   ───────────────────────────────────────────────────────────');
        print(
          '   ✅ Found ${adIds.length} unique ads with activity in ad set $adSetId',
        );
      }

      return adIds.toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad IDs: $e');
      }
      return [];
    }
  }

  /// Helper: Create zero metrics map for comparison
  Map<String, dynamic> _createZeroMetrics() {
    return {
      'totalSpend': 0.0,
      'totalImpressions': 0,
      'totalClicks': 0,
      'totalReach': 0,
      'totalLeads': 0,
      'totalBookings': 0,
      'totalDeposits': 0,
      'totalCashAmount': 0.0,
      'totalProfit': 0.0,
      'cpl': 0.0,
      'cpb': 0.0,
      'cpa': 0.0,
      'roi': 0.0,
      'avgCPM': 0.0,
      'avgCPC': 0.0,
      'avgCTR': 0.0,
    };
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
