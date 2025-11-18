import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/performance/ad.dart';
import 'summary_service.dart';

/// Service for managing ad data from the split collections schema
class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SummaryService _summaryService = SummaryService();

  /// Get all ads for an ad set
  Future<List<Ad>> getAdsForAdSet(
    String adSetId, {
    String? orderBy = 'facebookStats.spend',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('ads')
          .where('adSetId', isEqualTo: adSetId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => Ad.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting ads for ad set: $e');
      rethrow;
    }
  }

  /// Get all ads for a campaign
  Future<List<Ad>> getAdsForCampaign(
    String campaignId, {
    String? orderBy = 'lastUpdated',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('ads')
          .where('campaignId', isEqualTo: campaignId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => Ad.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting ads for campaign: $e');
      rethrow;
    }
  }

  /// Get a single ad by ID
  Future<Ad?> getAd(String adId) async {
    try {
      final doc = await _firestore.collection('ads').doc(adId).get();

      if (!doc.exists) {
        return null;
      }

      return Ad.fromFirestore(doc);
    } catch (e) {
      print('Error getting ad $adId: $e');
      rethrow;
    }
  }

  /// Stream ads for an ad set
  Stream<List<Ad>> streamAdsForAdSet(
    String adSetId, {
    String? orderBy = 'facebookStats.spend',
    bool descending = true,
  }) {
    try {
      Query query = _firestore
          .collection('ads')
          .where('adSetId', isEqualTo: adSetId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Ad.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error streaming ads: $e');
      rethrow;
    }
  }

  /// Stream ads for a campaign
  Stream<List<Ad>> streamAdsForCampaign(
    String campaignId, {
    String? orderBy = 'lastUpdated',
    bool descending = true,
  }) {
    try {
      Query query = _firestore
          .collection('ads')
          .where('campaignId', isEqualTo: campaignId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Ad.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error streaming ads: $e');
      rethrow;
    }
  }

  /// Stream a single ad
  Stream<Ad?> streamAd(String adId) {
    try {
      return _firestore.collection('ads').doc(adId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return Ad.fromFirestore(doc);
      });
    } catch (e) {
      print('Error streaming ad $adId: $e');
      rethrow;
    }
  }

  /// Get ads with date-filtered totals from summary collection ONLY
  /// This method queries summary collection directly (not ads collection)
  Future<List<Ad>> getAdsWithDateFilteredTotals({
    required String campaignId,
    required String adSetId,
    DateTime? startDate,
    DateTime? endDate,
    String orderBy = 'facebookStats.spend',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔄 Loading ads with date-filtered totals for ad set $adSetId from SUMMARY collection',
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
          print('   📋 No date range specified, loading all ads from SUMMARY collection');
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

        // Get ad set name from first week that has this ad set
        String? adSetName;
        for (var weekEntry in weeksMap.entries) {
          final weekData = weekEntry.value as Map<String, dynamic>?;
          final adSetsMap = weekData?['adSets'] as Map<String, dynamic>?;
          final adSetData = adSetsMap?[adSetId] as Map<String, dynamic>?;
          if (adSetData != null) {
            adSetName = adSetData['adSetName'] as String? ?? 'Unknown Ad Set';
            break;
          }
        }
        adSetName ??= 'Unknown Ad Set';

        // Map to store ad data: adId -> {totals, metadata, dates}
        final Map<String, Map<String, dynamic>> adsMap = {};

        // Iterate through ALL weeks (no date filtering)
        for (var weekEntry in weeksMap.entries) {
          final weekData = weekEntry.value as Map<String, dynamic>?;
          if (weekData == null) continue;

          // Parse week dates for firstInsightDate/lastInsightDate
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
                  23,
                  59,
                  59,
                  999,
                );
              }
            }
          } catch (e) {
            // Skip invalid week IDs
          }

          // Get ads map for this week
          final weekAdsMap = weekData['ads'] as Map<String, dynamic>?;
          if (weekAdsMap == null) continue;

          // Process each ad in this week
          for (var adEntry in weekAdsMap.entries) {
            final adId = adEntry.key;
            final adData = adEntry.value as Map<String, dynamic>?;
            if (adData == null) continue;

            // Check if ad belongs to this ad set
            final adAdSetId = adData['adSetId'] as String?;
            if (adAdSetId != adSetId) continue;

            // Initialize ad if not seen before
            if (!adsMap.containsKey(adId)) {
              final adName = adData['adName'] as String? ?? 'Unknown Ad';
              adsMap[adId] = {
                'adId': adId,
                'adName': adName,
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
              };
            }

            final adTotals = adsMap[adId]!;

            // Aggregate Facebook metrics
            final fbInsights =
                adData['facebookInsights'] as Map<String, dynamic>?;
            if (fbInsights != null) {
              adTotals['totalSpend'] =
                  (adTotals['totalSpend'] as double) +
                  ((fbInsights['spend'] as num?)?.toDouble() ?? 0.0);
              adTotals['totalImpressions'] =
                  (adTotals['totalImpressions'] as int) +
                  ((fbInsights['impressions'] as num?)?.toInt() ?? 0);
              adTotals['totalClicks'] =
                  (adTotals['totalClicks'] as int) +
                  ((fbInsights['clicks'] as num?)?.toInt() ?? 0);
              adTotals['totalReach'] =
                  (adTotals['totalReach'] as int) +
                  ((fbInsights['reach'] as num?)?.toInt() ?? 0);
            }

            // Aggregate GHL metrics from ad ghlData
            final ghlData = adData['ghlData'] as Map<String, dynamic>?;
            if (ghlData != null) {
              adTotals['totalLeads'] =
                  (adTotals['totalLeads'] as int) +
                  ((ghlData['leads'] as num?)?.toInt() ?? 0);
              adTotals['totalBookings'] =
                  (adTotals['totalBookings'] as int) +
                  ((ghlData['bookedAppointments'] as num?)?.toInt() ?? 0);
              adTotals['totalDeposits'] =
                  (adTotals['totalDeposits'] as int) +
                  ((ghlData['deposits'] as num?)?.toInt() ?? 0);
              adTotals['totalCashCollected'] =
                  (adTotals['totalCashCollected'] as int) +
                  ((ghlData['cashCollected'] as num?)?.toInt() ?? 0);
              adTotals['totalCashAmount'] =
                  (adTotals['totalCashAmount'] as double) +
                  ((ghlData['cashAmount'] as num?)?.toDouble() ?? 0.0);
            }

            // Collect dates
            if (weekStartDate != null) {
              (adTotals['weekStartDates'] as List<DateTime>).add(weekStartDate);
            }
            if (weekEndDate != null) {
              (adTotals['weekEndDates'] as List<DateTime>).add(weekEndDate);
            }
          }
        }

        // Convert map to list and calculate derived metrics
        List<Ad> allTimeAds = [];

        for (var adEntry in adsMap.entries) {
          final adTotals = adEntry.value;

          final totalSpend = adTotals['totalSpend'] as double;
          final totalImpressions = adTotals['totalImpressions'] as int;
          final totalClicks = adTotals['totalClicks'] as int;
          final totalReach = adTotals['totalReach'] as int;
          final totalLeads = adTotals['totalLeads'] as int;
          final totalBookings = adTotals['totalBookings'] as int;
          final totalDeposits = adTotals['totalDeposits'] as int;
          final totalCashCollected = adTotals['totalCashCollected'] as int;
          final totalCashAmount = adTotals['totalCashAmount'] as double;

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

          // Calculate first and last insight dates
          final weekStartDates = adTotals['weekStartDates'] as List<DateTime>;
          final weekEndDates = adTotals['weekEndDates'] as List<DateTime>;
          String? firstInsightDate;
          String? lastInsightDate;
          if (weekStartDates.isNotEmpty) {
            weekStartDates.sort();
            weekEndDates.sort();
            final earliest = weekStartDates.first;
            final latest = weekEndDates.last;

            firstInsightDate =
                '${earliest.year}-${earliest.month.toString().padLeft(2, '0')}-${earliest.day.toString().padLeft(2, '0')}';
            lastInsightDate =
                '${latest.year}-${latest.month.toString().padLeft(2, '0')}-${latest.day.toString().padLeft(2, '0')}';
          }

          final ad = Ad(
            adId: adTotals['adId'] as String,
            adName: adTotals['adName'] as String,
            adSetId: adSetId,
            adSetName: adSetName,
            campaignId: campaignId,
            campaignName: campaignName,
            facebookStats: FacebookStats(
              spend: totalSpend,
              impressions: totalImpressions,
              clicks: totalClicks,
              reach: totalReach,
              cpm: cpm,
              cpc: cpc,
              ctr: ctr,
              dateStart: firstInsightDate ?? '',
              dateStop: lastInsightDate ?? '',
            ),
            ghlStats: GHLStats(
              leads: totalLeads,
              bookings: totalBookings,
              deposits: totalDeposits,
              cashCollected: totalCashCollected,
              cashAmount: totalCashAmount,
            ),
            profit: totalProfit,
            cpl: cpl,
            cpb: cpb,
            cpa: cpa,
            status: 'ACTIVE', // Default status, not available in summary
            lastUpdated: null,
            createdAt: null,
            firstInsightDate: firstInsightDate,
            lastInsightDate: lastInsightDate,
            lastFacebookSync: null,
            lastGHLSync: null,
          );

          allTimeAds.add(ad);
        }

        // Sort by the requested field
        _sortAds(allTimeAds, orderBy, descending);

        if (kDebugMode) {
          print(
            '   ✅ Loaded ${allTimeAds.length} ads from SUMMARY (all time)',
          );
        }

        return allTimeAds;
      }

      // OPTIMIZED: Get ads with pre-calculated totals (SINGLE FETCH)
      // This reduces Firestore reads from 2+M to 1 (where M = number of ads)
      final adsData = await _summaryService.getAdsWithCalculatedTotals(
        campaignId: campaignId,
        adSetId: adSetId,
        startDate: startDate,
        endDate: endDate,
      );

      if (kDebugMode) {
        print(
          '   ✅ Received ${adsData.length} ads with pre-calculated totals',
        );
      }

      // Build Ad objects from pre-calculated data
      List<Ad> adsWithDateFilteredTotals = [];

      for (var adData in adsData) {
        final totals = adData['totals'] as Map<String, dynamic>;

        // Skip ads with no activity
        if (totals['adsInRange'] == 0) continue;

        final ad = Ad(
          adId: adData['adId'] as String,
          adName: adData['adName'] as String,
          adSetId: adSetId,
          adSetName: adData['adSetName'] as String,
          campaignId: campaignId,
          campaignName: adData['campaignName'] as String,
          facebookStats: FacebookStats(
            spend: totals['totalSpend'] ?? 0.0,
            impressions: totals['totalImpressions'] ?? 0,
            clicks: totals['totalClicks'] ?? 0,
            reach: totals['totalReach'] ?? 0,
            cpm: totals['cpm'] ?? 0.0,
            cpc: totals['cpc'] ?? 0.0,
            ctr: totals['ctr'] ?? 0.0,
            dateStart: adData['firstInsightDate'] as String? ?? '',
            dateStop: adData['lastInsightDate'] as String? ?? '',
          ),
          ghlStats: GHLStats(
            leads: totals['totalLeads'] ?? 0,
            bookings: totals['totalBookings'] ?? 0,
            deposits: totals['totalDeposits'] ?? 0,
            cashCollected: totals['totalCashCollected'] ?? 0,
            cashAmount: totals['totalCashAmount'] ?? 0.0,
          ),
          profit: totals['totalProfit'] ?? 0.0,
          cpl: totals['cpl'] ?? 0.0,
          cpb: totals['cpb'] ?? 0.0,
          cpa: totals['cpa'] ?? 0.0,
          status: 'ACTIVE', // Default status, not available in summary
          // Optional fields - not available in summary, use null
          lastUpdated: null,
          createdAt: null,
          firstInsightDate: adData['firstInsightDate'] as String?,
          lastInsightDate: adData['lastInsightDate'] as String?,
          lastFacebookSync: null,
          lastGHLSync: null,
        );

        adsWithDateFilteredTotals.add(ad);
      }

      if (kDebugMode) {
        print('   ✅ ${adsWithDateFilteredTotals.length} ads with data in range');
      }

      // Sort by the requested field
      _sortAds(adsWithDateFilteredTotals, orderBy, descending);

      if (kDebugMode) {
        print(
          '✅ Returning ${adsWithDateFilteredTotals.length} ads with date-filtered totals',
        );
      }

      return adsWithDateFilteredTotals;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting ads with date-filtered totals: $e');
      }
      rethrow;
    }
  }

  /// Calculate ad totals from weeklyInsights subcollection (fallback method)
  Future<Map<String, dynamic>?> _calculateAdTotalsFromWeeklyInsights({
    required String adId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Query weekly insights for this ad
      final snapshot = await _firestore
          .collection('ads')
          .doc(adId)
          .collection('weeklyInsights')
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      double totalSpend = 0;
      int totalImpressions = 0;
      int totalClicks = 0;
      int totalReach = 0;
      int weeksUsed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Get week date range
        final dateStart = data['dateStart'];
        final dateStop = data['dateStop'];

        // Convert Timestamp to DateTime if needed
        DateTime? weekStart;
        DateTime? weekEnd;

        if (dateStart is Timestamp) {
          weekStart = dateStart.toDate();
        } else if (dateStart is String) {
          weekStart = DateTime.tryParse(dateStart);
        }

        if (dateStop is Timestamp) {
          weekEnd = dateStop.toDate();
        } else if (dateStop is String) {
          weekEnd = DateTime.tryParse(dateStop);
        }

        // Check if week overlaps with the specified date range
        bool inRange = true;
        if (startDate != null && weekEnd != null) {
          if (weekEnd.isBefore(startDate)) {
            inRange = false; // Week ended before start date
          }
        }
        if (endDate != null && weekStart != null) {
          if (weekStart.isAfter(endDate)) {
            inRange = false; // Week started after end date
          }
        }

        if (!inRange) continue;

        // Aggregate this week's data
        totalSpend += (data['spend'] as num?)?.toDouble() ?? 0;
        totalImpressions += (data['impressions'] as num?)?.toInt() ?? 0;
        totalClicks += (data['clicks'] as num?)?.toInt() ?? 0;
        totalReach += (data['reach'] as num?)?.toInt() ?? 0;
        weeksUsed++;
      }

      if (weeksUsed == 0) {
        return null;
      }

      // Calculate derived metrics
      final ctr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0.0;
      final cpm = totalImpressions > 0
          ? (totalSpend / totalImpressions) * 1000
          : 0.0;
      final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0.0;

      // Note: GHL stats would need to be fetched from ghlOpportunities
      // For simplicity in fallback, we'll return 0 for GHL metrics
      return {
        'totalSpend': totalSpend,
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'totalReach': totalReach,
        'totalLeads': 0,
        'totalBookings': 0,
        'totalDeposits': 0,
        'totalCashCollected': 0,
        'totalCashAmount': 0.0,
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': weeksUsed,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating ad totals from weekly insights: $e');
      }
      return null;
    }
  }

  /// Helper method to sort ads
  void _sortAds(List<Ad> ads, String orderBy, bool descending) {
    ads.sort((a, b) {
      int comparison = 0;
      switch (orderBy) {
        case 'facebookStats.spend':
          comparison = a.facebookStats.spend.compareTo(b.facebookStats.spend);
          break;
        case 'facebookStats.impressions':
          comparison = a.facebookStats.impressions.compareTo(
            b.facebookStats.impressions,
          );
          break;
        case 'facebookStats.clicks':
          comparison = a.facebookStats.clicks.compareTo(b.facebookStats.clicks);
          break;
        case 'ghlStats.leads':
          final aLeads = a.ghlStats.leads;
          final bLeads = b.ghlStats.leads;
          comparison = aLeads.compareTo(bLeads);
          break;
        default:
          comparison = a.facebookStats.spend.compareTo(b.facebookStats.spend);
      }
      return descending ? -comparison : comparison;
    });
  }
}
