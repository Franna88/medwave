import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/performance/ad_set.dart';
import 'summary_service.dart';

/// Service for managing ad set data from the split collections schema
class AdSetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SummaryService _summaryService = SummaryService();

  /// Get all ad sets for a campaign
  Future<List<AdSet>> getAdSetsForCampaign(
    String campaignId, {
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('adSets')
          .where('campaignId', isEqualTo: campaignId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => AdSet.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting ad sets for campaign: $e');
      rethrow;
    }
  }

  /// Get a single ad set by ID
  Future<AdSet?> getAdSet(String adSetId) async {
    try {
      final doc = await _firestore.collection('adSets').doc(adSetId).get();

      if (!doc.exists) {
        return null;
      }

      return AdSet.fromFirestore(doc);
    } catch (e) {
      print('Error getting ad set $adSetId: $e');
      rethrow;
    }
  }

  /// Stream ad sets for a campaign
  Stream<List<AdSet>> streamAdSetsForCampaign(
    String campaignId, {
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) {
    try {
      Query query = _firestore
          .collection('adSets')
          .where('campaignId', isEqualTo: campaignId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => AdSet.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error streaming ad sets: $e');
      rethrow;
    }
  }

  /// Stream a single ad set
  Stream<AdSet?> streamAdSet(String adSetId) {
    try {
      return _firestore.collection('adSets').doc(adSetId).snapshots().map((
        doc,
      ) {
        if (!doc.exists) {
          return null;
        }
        return AdSet.fromFirestore(doc);
      });
    } catch (e) {
      print('Error streaming ad set $adSetId: $e');
      rethrow;
    }
  }

  /// Get ad sets with date-filtered totals from summary collection
  /// Similar to CampaignService.getCampaignsWithDateFilteredTotals()
  Future<List<AdSet>> getAdSetsWithDateFilteredTotals({
    required String campaignId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 Loading ad sets with date-filtered totals for campaign $campaignId',
        );
        if (startDate != null || endDate != null) {
          print(
            '   📅 Date range: ${startDate?.toIso8601String() ?? "any"} to ${endDate?.toIso8601String() ?? "any"}',
          );
        }
      }

      // Handle "All" case (no date filtering) - use ONLY summary collection
      if (startDate == null || endDate == null) {
        if (kDebugMode) {
          print(
            '   📋 No date range specified, loading all ad sets from SUMMARY collection',
          );
        }

        // Fetch campaign summary document
        final summaryDoc = await _firestore
            .collection('summary')
            .doc(campaignId)
            .get();

        if (!summaryDoc.exists) {
          if (kDebugMode) {
            print('   ⚠️ No summary document found for campaign $campaignId');
          }
          return [];
        }

        final data = summaryDoc.data();
        if (data == null) return [];

        final campaignName =
            data['campaignName'] as String? ?? 'Unknown Campaign';
        final weeksMap = data['weeks'] as Map<String, dynamic>?;
        if (weeksMap == null || weeksMap.isEmpty) return [];

        // Map to store ad set data: adSetId -> {totals, metadata, dates, adIds}
        final Map<String, Map<String, dynamic>> adSetsMap = {};

        // Iterate through ALL weeks (no date filtering)
        for (var weekEntry in weeksMap.entries) {
          final weekData = weekEntry.value as Map<String, dynamic>?;
          if (weekData == null) continue;

          // Parse week dates for firstAdDate/lastAdDate
          DateTime? weekStartDate;
          DateTime? weekEndDate;
          try {
            final weekId = weekEntry.key;
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
                );
              }
            }
          } catch (e) {
            // Skip invalid week IDs
          }

          // Get ad sets map for this week
          final weekAdSetsMap = weekData['adSets'] as Map<String, dynamic>?;
          if (weekAdSetsMap == null) continue;

          // Get ads map for aggregating cashAmount
          final adsMap = weekData['ads'] as Map<String, dynamic>?;

          // Process each ad set in this week
          for (var adSetEntry in weekAdSetsMap.entries) {
            final adSetId = adSetEntry.key;
            final adSetData = adSetEntry.value as Map<String, dynamic>?;
            if (adSetData == null) continue;

            // Initialize ad set if not seen before
            if (!adSetsMap.containsKey(adSetId)) {
              final adSetName =
                  adSetData['adSetName'] as String? ?? 'Unknown Ad Set';
              adSetsMap[adSetId] = {
                'adSetId': adSetId,
                'adSetName': adSetName,
                'campaignId': campaignId,
                'campaignName': campaignName,
                'totalSpend': 0.0,
                'totalImpressions': 0,
                'totalClicks': 0,
                'totalReach': 0,
                'totalLeads': 0,
                'totalBookings': 0,
                'totalDeposits': 0,
                'totalCashCollected': 0,
                'totalCashAmount': 0.0,
                'weekStartDates': <DateTime>[],
                'weekEndDates': <DateTime>[],
                'adIds': <String>{},
              };
            }

            final adSetTotals = adSetsMap[adSetId]!;

            // Collect ad IDs for this ad set from ALL ads
            if (adsMap != null) {
              for (var adEntry in adsMap.entries) {
                final adData = adEntry.value as Map<String, dynamic>?;
                final adAdSetId = adData?['adSetId'] as String?;
                if (adAdSetId == adSetId) {
                  final adId = adEntry.key;
                  (adSetTotals['adIds'] as Set<String>).add(adId);
                }
              }
            }

            // Aggregate Facebook metrics
            final fbInsights =
                adSetData['facebookInsights'] as Map<String, dynamic>?;
            if (fbInsights != null) {
              adSetTotals['totalSpend'] =
                  (adSetTotals['totalSpend'] as double) +
                  ((fbInsights['spend'] as num?)?.toDouble() ?? 0.0);
              adSetTotals['totalImpressions'] =
                  (adSetTotals['totalImpressions'] as int) +
                  ((fbInsights['impressions'] as num?)?.toInt() ?? 0);
              adSetTotals['totalClicks'] =
                  (adSetTotals['totalClicks'] as int) +
                  ((fbInsights['clicks'] as num?)?.toInt() ?? 0);
              adSetTotals['totalReach'] =
                  (adSetTotals['totalReach'] as int) +
                  ((fbInsights['reach'] as num?)?.toInt() ?? 0);
            }

            // Aggregate GHL metrics (counts from ad set, cashAmount from ads)
            if (weekStartDate != null && weekEndDate != null) {
              final ghlData = adSetData['ghlData'] as Map<String, dynamic>?;
              if (ghlData != null) {
                adSetTotals['totalLeads'] =
                    (adSetTotals['totalLeads'] as int) +
                    ((ghlData['leads'] as num?)?.toInt() ?? 0);
                adSetTotals['totalBookings'] =
                    (adSetTotals['totalBookings'] as int) +
                    ((ghlData['bookedAppointments'] as num?)?.toInt() ?? 0);
                adSetTotals['totalDeposits'] =
                    (adSetTotals['totalDeposits'] as int) +
                    ((ghlData['deposits'] as num?)?.toInt() ?? 0);
                adSetTotals['totalCashCollected'] =
                    (adSetTotals['totalCashCollected'] as int) +
                    ((ghlData['cashCollected'] as num?)?.toInt() ?? 0);
              }

              // Aggregate cashAmount from ads that belong to this ad set
              if (adsMap != null) {
                double weekCashAmount = 0.0;
                for (var adEntry in adsMap.entries) {
                  final adData = adEntry.value as Map<String, dynamic>?;
                  final adAdSetId = adData?['adSetId'] as String?;
                  if (adAdSetId == adSetId) {
                    final adGhlData =
                        adData?['ghlData'] as Map<String, dynamic>?;
                    final adCashAmount =
                        (adGhlData?['cashAmount'] as num?)?.toDouble() ?? 0.0;
                    weekCashAmount += adCashAmount;
                  }
                }
                adSetTotals['totalCashAmount'] =
                    (adSetTotals['totalCashAmount'] as double) + weekCashAmount;
              }
            }

            // Collect dates
            if (weekStartDate != null) {
              (adSetTotals['weekStartDates'] as List<DateTime>).add(
                weekStartDate,
              );
            }
            if (weekEndDate != null) {
              (adSetTotals['weekEndDates'] as List<DateTime>).add(weekEndDate);
            }
          }
        }

        // Convert map to list and calculate derived metrics
        List<AdSet> allTimeAdSets = [];

        for (var adSetEntry in adSetsMap.entries) {
          final adSetTotals = adSetEntry.value;

          final totalSpend = adSetTotals['totalSpend'] as double;
          final totalImpressions = adSetTotals['totalImpressions'] as int;
          final totalClicks = adSetTotals['totalClicks'] as int;
          final totalReach = adSetTotals['totalReach'] as int;
          final totalLeads = adSetTotals['totalLeads'] as int;
          final totalBookings = adSetTotals['totalBookings'] as int;
          final totalDeposits = adSetTotals['totalDeposits'] as int;
          final totalCashCollected = adSetTotals['totalCashCollected'] as int;
          final totalCashAmount = adSetTotals['totalCashAmount'] as double;
          final adIds = adSetTotals['adIds'] as Set<String>;

          final totalProfit = totalCashAmount - totalSpend;
          final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0.0;
          final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0.0;
          final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0.0;
          final ctr = totalImpressions > 0
              ? (totalClicks / totalImpressions) * 100
              : 0.0;
          final cpm = totalImpressions > 0
              ? (totalSpend / totalImpressions) * 1000
              : 0.0;
          final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0.0;

          // Calculate first and last ad dates
          final weekStartDates =
              adSetTotals['weekStartDates'] as List<DateTime>;
          final weekEndDates = adSetTotals['weekEndDates'] as List<DateTime>;
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

          final adSet = AdSet(
            adSetId: adSetTotals['adSetId'] as String,
            adSetName: adSetTotals['adSetName'] as String,
            campaignId: campaignId,
            campaignName: campaignName,
            totalSpend: totalSpend,
            totalImpressions: totalImpressions,
            totalClicks: totalClicks,
            totalReach: totalReach,
            avgCPM: cpm,
            avgCPC: cpc,
            avgCTR: ctr,
            totalLeads: totalLeads,
            totalBookings: totalBookings,
            totalDeposits: totalDeposits,
            totalCashCollected: totalCashCollected,
            totalCashAmount: totalCashAmount,
            totalProfit: totalProfit,
            cpl: cpl,
            cpb: cpb,
            cpa: cpa,
            adCount: adIds.length,
            lastUpdated: null,
            createdAt: null,
            firstAdDate: firstAdDate,
            lastAdDate: lastAdDate,
          );

          allTimeAdSets.add(adSet);
        }

        // Sort by the requested field
        _sortAdSets(allTimeAdSets, orderBy, descending);

        // Apply limit
        if (limit > 0 && allTimeAdSets.length > limit) {
          allTimeAdSets = allTimeAdSets.sublist(0, limit);
        }

        if (kDebugMode) {
          print(
            '   ✅ Loaded ${allTimeAdSets.length} ad sets from SUMMARY (all time)',
          );
        }

        return allTimeAdSets;
      }

      // OPTIMIZED: Get ad sets with pre-calculated totals (SINGLE FETCH)
      // This reduces Firestore reads from 1+N to 1 (where N = number of ad sets)
      final adSetsData = await _summaryService.getAdSetsWithCalculatedTotals(
        campaignId: campaignId,
        startDate: startDate,
        endDate: endDate,
      );

      if (kDebugMode) {
        print(
          '   ✅ Received ${adSetsData.length} ad sets with pre-calculated totals',
        );
      }

      // Build AdSet objects from pre-calculated data
      List<AdSet> adSetsWithDateFilteredTotals = [];

      for (var adSetData in adSetsData) {
        final totals = adSetData['totals'] as Map<String, dynamic>;

        // Only include ad sets with activity
        if (totals['adsInRange'] == 0) continue;

        final adSet = AdSet(
          adSetId: adSetData['adSetId'] as String,
          adSetName: adSetData['adSetName'] as String,
          campaignId: campaignId,
          campaignName: adSetData['campaignName'] as String,
          totalSpend: totals['totalSpend'] ?? 0.0,
          totalImpressions: totals['totalImpressions'] ?? 0,
          totalClicks: totals['totalClicks'] ?? 0,
          totalReach: totals['totalReach'] ?? 0,
          avgCPM: totals['cpm'] ?? 0.0,
          avgCPC: totals['cpc'] ?? 0.0,
          avgCTR: totals['ctr'] ?? 0.0,
          totalLeads: totals['totalLeads'] ?? 0,
          totalBookings: totals['totalBookings'] ?? 0,
          totalDeposits: totals['totalDeposits'] ?? 0,
          totalCashCollected: totals['totalCashCollected'] ?? 0,
          totalCashAmount: totals['totalCashAmount'] ?? 0.0,
          totalProfit: totals['totalProfit'] ?? 0.0,
          cpl: totals['cpl'] ?? 0.0,
          cpb: totals['cpb'] ?? 0.0,
          cpa: totals['cpa'] ?? 0.0,
          adCount: adSetData['adCount'] ?? 0,
          // Optional fields - not available in summary, use null
          lastUpdated: null,
          createdAt: null,
          firstAdDate: adSetData['firstAdDate'] as String?,
          lastAdDate: adSetData['lastAdDate'] as String?,
        );

        adSetsWithDateFilteredTotals.add(adSet);
      }

      if (kDebugMode) {
        print(
          '   ✅ ${adSetsWithDateFilteredTotals.length} ad sets with data in range',
        );
      }

      // Sort by the requested field
      _sortAdSets(adSetsWithDateFilteredTotals, orderBy, descending);

      // Apply limit
      if (adSetsWithDateFilteredTotals.length > limit) {
        adSetsWithDateFilteredTotals = adSetsWithDateFilteredTotals.sublist(
          0,
          limit,
        );
      }

      if (kDebugMode) {
        print(
          '✅ Returning ${adSetsWithDateFilteredTotals.length} ad sets with date-filtered totals',
        );
      }

      return adSetsWithDateFilteredTotals;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting ad sets with date-filtered totals: $e');
      }
      rethrow;
    }
  }

  /// Helper method to sort ad sets
  void _sortAdSets(List<AdSet> adSets, String orderBy, bool descending) {
    adSets.sort((a, b) {
      int comparison = 0;
      switch (orderBy) {
        case 'totalProfit':
          comparison = a.totalProfit.compareTo(b.totalProfit);
          break;
        case 'totalSpend':
          comparison = a.totalSpend.compareTo(b.totalSpend);
          break;
        case 'totalLeads':
          comparison = a.totalLeads.compareTo(b.totalLeads);
          break;
        case 'totalBookings':
          comparison = a.totalBookings.compareTo(b.totalBookings);
          break;
        default:
          comparison = a.totalProfit.compareTo(b.totalProfit);
      }
      return descending ? -comparison : comparison;
    });
  }

  /// Calculate weekly totals for an ad within a specific date range
  /// Reads from the ads/{adId}/weeklyInsights subcollection
  Future<Map<String, dynamic>> _calculateWeeklyTotalsForDateRange({
    required String adId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Query weekly insights for this ad
      Query query = _firestore
          .collection('ads')
          .doc(adId)
          .collection('weeklyInsights');

      final snapshot = await query.get();

      double spend = 0;
      int impressions = 0;
      int clicks = 0;
      int reach = 0;

      final startDateStr = startDate != null
          ? _dateTimeToString(startDate)
          : null;
      final endDateStr = endDate != null ? _dateTimeToString(endDate) : null;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get week date range (stored as strings in format YYYY-MM-DD)
        final dateStart = data['dateStart'];
        final dateStop = data['dateStop'];

        // Convert Timestamp to string if needed
        String? weekStartStr;
        String? weekStopStr;

        if (dateStart is Timestamp) {
          final dt = dateStart.toDate();
          weekStartStr = _dateTimeToString(dt);
        } else if (dateStart is String) {
          weekStartStr = dateStart;
        }

        if (dateStop is Timestamp) {
          final dt = dateStop.toDate();
          weekStopStr = _dateTimeToString(dt);
        } else if (dateStop is String) {
          weekStopStr = dateStop;
        }

        // Check if week overlaps with the specified date range
        bool inRange = true;
        if (startDateStr != null && weekStopStr != null) {
          if (weekStopStr.compareTo(startDateStr) < 0) {
            inRange = false; // Week ended before start date
          }
        }
        if (endDateStr != null && weekStartStr != null) {
          if (weekStartStr.compareTo(endDateStr) > 0) {
            inRange = false; // Week started after end date
          }
        }

        if (!inRange) continue;

        // Aggregate this week's data
        spend += (data['spend'] as num?)?.toDouble() ?? 0;
        impressions += (data['impressions'] as num?)?.toInt() ?? 0;
        clicks += (data['clicks'] as num?)?.toInt() ?? 0;
        reach += (data['reach'] as num?)?.toInt() ?? 0;
      }

      return {
        'spend': spend,
        'impressions': impressions,
        'clicks': clicks,
        'reach': reach,
      };
    } catch (e) {
      print('Error calculating weekly totals for ad $adId: $e');
      // Return zeros if there's an error or no weekly data
      return {'spend': 0.0, 'impressions': 0, 'clicks': 0, 'reach': 0};
    }
  }

  /// Helper method to convert DateTime to YYYY-MM-DD string
  static String _dateTimeToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculate ad set totals for a specific date range by aggregating from ads
  /// This provides month-specific or date-range-specific totals instead of lifetime totals
  /// Uses weekly insights to get accurate month-specific spend data
  Future<Map<String, dynamic>> calculateAdSetTotalsForDateRange({
    required String adSetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Query ads for this ad set
      Query query = _firestore
          .collection('ads')
          .where('adSetId', isEqualTo: adSetId);

      final snapshot = await query.get();

      double totalSpend = 0;
      int totalImpressions = 0;
      int totalClicks = 0;
      int totalReach = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      int adsInRange = 0;

      final startDateStr = startDate != null
          ? _dateTimeToString(startDate)
          : null;
      final endDateStr = endDate != null ? _dateTimeToString(endDate) : null;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final adId = doc.id;

        // Get ad date range - use _parseDateField for backward compatibility
        final firstInsightDate = _parseDateField(data['firstInsightDate']);
        final lastInsightDate = _parseDateField(data['lastInsightDate']);

        // Check if ad falls within the specified date range
        bool inRange = true;
        if (startDateStr != null && lastInsightDate != null) {
          if (lastInsightDate.compareTo(startDateStr) < 0) {
            inRange = false; // Ad ended before start date
          }
        }
        if (endDateStr != null && firstInsightDate != null) {
          if (firstInsightDate.compareTo(endDateStr) > 0) {
            inRange = false; // Ad started after end date
          }
        }

        if (!inRange) continue;

        adsInRange++;

        // Aggregate Facebook stats
        final facebookStats = data['facebookStats'] as Map<String, dynamic>?;
        if (facebookStats != null) {
          totalSpend += (facebookStats['spend'] as num?)?.toDouble() ?? 0;
          totalImpressions +=
              (facebookStats['impressions'] as num?)?.toInt() ?? 0;
          totalClicks += (facebookStats['clicks'] as num?)?.toInt() ?? 0;
          totalReach += (facebookStats['reach'] as num?)?.toInt() ?? 0;
        }
        // Check if ad spans multiple months (needs weekly insights for accuracy)
        bool spansMultipleMonths = false;
        if (firstInsightDate != null &&
            lastInsightDate != null &&
            startDateStr != null &&
            endDateStr != null) {
          // Extract month from dates (YYYY-MM format)
          final adStartMonth = firstInsightDate.substring(0, 7);
          final adEndMonth = lastInsightDate.substring(0, 7);

          // If ad spans multiple months, we need weekly insights for accuracy
          spansMultipleMonths = adStartMonth != adEndMonth;
        }

        // Use weekly insights ONLY if ad spans multiple months (for accuracy)
        // Otherwise use the ad's aggregated facebookStats (much faster!)
        if (spansMultipleMonths) {
          final weeklyTotals = await _calculateWeeklyTotalsForDateRange(
            adId: adId,
            startDate: startDate,
            endDate: endDate,
          );

          totalSpend += (weeklyTotals['spend'] as num?)?.toDouble() ?? 0;
          totalImpressions +=
              (weeklyTotals['impressions'] as num?)?.toInt() ?? 0;
          totalClicks += (weeklyTotals['clicks'] as num?)?.toInt() ?? 0;
          totalReach += (weeklyTotals['reach'] as num?)?.toInt() ?? 0;
        } else {
          // Ad is within a single month - use aggregated stats (fast!)
          final facebookStats = data['facebookStats'] as Map<String, dynamic>?;
          if (facebookStats != null) {
            totalSpend += (facebookStats['spend'] as num?)?.toDouble() ?? 0;
            totalImpressions +=
                (facebookStats['impressions'] as num?)?.toInt() ?? 0;
            totalClicks += (facebookStats['clicks'] as num?)?.toInt() ?? 0;
            totalReach += (facebookStats['reach'] as num?)?.toInt() ?? 0;
          }
        }

        // Aggregate GHL stats by querying opportunities for this ad and filtering by date
        // NOTE: ghlStats in ads collection are LIFETIME stats, not month-specific!
        final opportunitiesQuery = await _firestore
            .collection('ghlOpportunities')
            .where('adId', isEqualTo: adId)
            .get();

        for (var oppDoc in opportunitiesQuery.docs) {
          final oppData = oppDoc.data();
          final createdAt = _parseTimestampField(oppData['createdAt']);

          // Filter by date range
          if (createdAt != null) {
            if (startDate != null && createdAt.isBefore(startDate)) continue;
            if (endDate != null && createdAt.isAfter(endDate)) continue;
          }

          // Count by stage category
          final stageCategory = oppData['stageCategory'] as String? ?? '';
          final monetaryValue =
              (oppData['monetaryValue'] as num?)?.toDouble() ?? 0;

          if (stageCategory == 'leads') {
            totalLeads++;
          } else if (stageCategory == 'bookedAppointments') {
            totalBookings++;
          } else if (stageCategory == 'deposits') {
            totalDeposits++;
            totalCashAmount += monetaryValue;
          } else if (stageCategory == 'cashCollected') {
            totalCashCollected++;
            totalCashAmount += monetaryValue;
          }
        }
      }

      // Calculate derived metrics
      final totalProfit = totalCashAmount - totalSpend;
      final cpl = totalLeads > 0 ? totalSpend / totalLeads : 0;
      final cpb = totalBookings > 0 ? totalSpend / totalBookings : 0;
      final cpa = totalDeposits > 0 ? totalSpend / totalDeposits : 0;
      final ctr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0;
      final cpm = totalImpressions > 0
          ? (totalSpend / totalImpressions) * 1000
          : 0;
      final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0;

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
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': adsInRange,
      };
    } catch (e) {
      print('Error calculating ad set totals for date range: $e');
      rethrow;
    }
  }

  /// Get ad sets with month-specific totals from pre-aggregated monthlyTotals
  /// This is FAST and ACCURATE - uses pre-calculated monthly data
  Future<List<AdSet>> getAdSetsWithMonthTotals({
    required String campaignId,
    required String month, // Format: "2025-11"
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      // Get all ad sets for this campaign
      final snapshot = await _firestore
          .collection('adSets')
          .where('campaignId', isEqualTo: campaignId)
          .get();

      List<AdSet> adSetsWithMonthData = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final monthlyTotals = data['monthlyTotals'] as Map<String, dynamic>?;

        // Check if this ad set has data for the requested month
        if (monthlyTotals == null || !monthlyTotals.containsKey(month)) {
          continue; // Skip ad sets without data for this month
        }

        final monthData = monthlyTotals[month] as Map<String, dynamic>;

        // Create ad set with month-specific data
        final adSet = AdSet(
          adSetId: doc.id,
          adSetName: data['adSetName'] ?? '',
          campaignId: data['campaignId'] ?? '',
          campaignName: data['campaignName'] ?? '',
          totalSpend: (monthData['spend'] as num?)?.toDouble() ?? 0,
          totalImpressions: (monthData['impressions'] as num?)?.toInt() ?? 0,
          totalClicks: (monthData['clicks'] as num?)?.toInt() ?? 0,
          totalReach: (monthData['reach'] as num?)?.toInt() ?? 0,
          avgCPM: (monthData['cpm'] as num?)?.toDouble() ?? 0,
          avgCPC: (monthData['cpc'] as num?)?.toDouble() ?? 0,
          avgCTR: (monthData['ctr'] as num?)?.toDouble() ?? 0,
          totalLeads: (monthData['leads'] as num?)?.toInt() ?? 0,
          totalBookings: (monthData['bookings'] as num?)?.toInt() ?? 0,
          totalDeposits: (monthData['deposits'] as num?)?.toInt() ?? 0,
          totalCashCollected:
              (monthData['cashCollected'] as num?)?.toInt() ?? 0,
          totalCashAmount: (monthData['cashAmount'] as num?)?.toDouble() ?? 0,
          totalProfit: (monthData['profit'] as num?)?.toDouble() ?? 0,
          cpl: (monthData['cpl'] as num?)?.toDouble() ?? 0,
          cpb: (monthData['cpb'] as num?)?.toDouble() ?? 0,
          cpa: (monthData['cpa'] as num?)?.toDouble() ?? 0,
          adCount: (monthData['adCount'] as num?)?.toInt() ?? 0,
          lastUpdated: _parseTimestampField(data['lastUpdated']),
          createdAt: _parseTimestampField(data['createdAt']),
          firstAdDate: _parseDateField(data['firstAdDate']),
          lastAdDate: _parseDateField(data['lastAdDate']),
        );

        adSetsWithMonthData.add(adSet);
      }

      // Sort by the requested field
      if (orderBy != null) {
        adSetsWithMonthData.sort((a, b) {
          dynamic aValue, bValue;
          switch (orderBy) {
            case 'totalSpend':
              aValue = a.totalSpend;
              bValue = b.totalSpend;
              break;
            case 'totalProfit':
              aValue = a.totalProfit;
              bValue = b.totalProfit;
              break;
            case 'totalLeads':
              aValue = a.totalLeads;
              bValue = b.totalLeads;
              break;
            default:
              aValue = a.totalProfit;
              bValue = b.totalProfit;
          }

          final comparison = (aValue as num).compareTo(bValue as num);
          return descending ? -comparison : comparison;
        });
      }

      return adSetsWithMonthData;
    } catch (e) {
      print('Error getting ad sets with month totals: $e');
      rethrow;
    }
  }

  /// DEPRECATED: Use getAdSetsWithMonthTotals instead for month filtering
  /// Get ad sets for a campaign with date-range-specific totals (not lifetime totals)
  /// This is the correct method to use when filtering by month
  @Deprecated('Use getAdSetsWithMonthTotals for better performance')
  Future<List<AdSet>> getAdSetsWithDateRangeTotals({
    required String campaignId,
    DateTime? startDate,
    DateTime? endDate,
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      // First, get ad sets for this campaign
      final adSets = await getAdSetsForCampaign(
        campaignId,
        orderBy: 'lastUpdated', // Use a simple order first
        descending: true,
      );

      // Calculate date-range-specific totals for each ad set
      List<AdSet> adSetsWithTotals = [];

      for (var adSet in adSets) {
        final totals = await calculateAdSetTotalsForDateRange(
          adSetId: adSet.adSetId,
          startDate: startDate,
          endDate: endDate,
        );

        // Create a new ad set with updated totals
        final updatedAdSet = AdSet(
          adSetId: adSet.adSetId,
          adSetName: adSet.adSetName,
          campaignId: adSet.campaignId,
          campaignName: adSet.campaignName,
          totalSpend: totals['totalSpend'],
          totalImpressions: totals['totalImpressions'],
          totalClicks: totals['totalClicks'],
          totalReach: totals['totalReach'],
          avgCPM: totals['cpm'],
          avgCPC: totals['cpc'],
          avgCTR: totals['ctr'],
          totalLeads: totals['totalLeads'],
          totalBookings: totals['totalBookings'],
          totalDeposits: totals['totalDeposits'],
          totalCashCollected: totals['totalCashCollected'],
          totalCashAmount: totals['totalCashAmount'],
          totalProfit: totals['totalProfit'],
          cpl: totals['cpl'],
          cpb: totals['cpb'],
          cpa: totals['cpa'],
          adCount: totals['adsInRange'],
          lastUpdated: adSet.lastUpdated,
          createdAt: adSet.createdAt,
          firstAdDate: adSet.firstAdDate,
          lastAdDate: adSet.lastAdDate,
        );

        // Only include ad sets with spend in the date range
        if (totals['totalSpend'] > 0 || totals['totalLeads'] > 0) {
          adSetsWithTotals.add(updatedAdSet);
        }
      }

      // Sort by the requested field
      if (orderBy != null) {
        adSetsWithTotals.sort((a, b) {
          dynamic aValue, bValue;
          switch (orderBy) {
            case 'totalSpend':
              aValue = a.totalSpend;
              bValue = b.totalSpend;
              break;
            case 'totalProfit':
              aValue = a.totalProfit;
              bValue = b.totalProfit;
              break;
            case 'totalLeads':
              aValue = a.totalLeads;
              bValue = b.totalLeads;
              break;
            default:
              aValue = a.totalProfit;
              bValue = b.totalProfit;
          }

          final comparison = (aValue as num).compareTo(bValue as num);
          return descending ? -comparison : comparison;
        });
      }

      return adSetsWithTotals;
    } catch (e) {
      print('Error getting ad sets with date range totals: $e');
      rethrow;
    }
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

  /// Parse DateTime field from Firestore (handles both Timestamp and ISO String)
  static DateTime? _parseTimestampField(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing timestamp string: $e');
        return null;
      }
    }
    return null;
  }
}
