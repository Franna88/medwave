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

  /// Get ads with date-filtered totals from summary collection
  /// Similar to AdSetService.getAdSetsWithDateFilteredTotals()
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
        print('🔄 Loading ads with date-filtered totals for ad set $adSetId');
        if (startDate != null || endDate != null) {
          print(
            '   📅 Date range: ${startDate?.toIso8601String() ?? "any"} to ${endDate?.toIso8601String() ?? "any"}',
          );
        }
      }

      // Get all ads for this ad set (without date filtering)
      final snapshot = await _firestore
          .collection('ads')
          .where('adSetId', isEqualTo: adSetId)
          .get();

      if (kDebugMode) {
        print('   📋 Found ${snapshot.docs.length} ads in ad set');
      }

      List<Ad> adsWithDateFilteredTotals = [];
      int adsWithData = 0;

      for (var doc in snapshot.docs) {
        final ad = Ad.fromFirestore(doc);
        final adId = ad.adId;

        if (kDebugMode) {
          print('   Calculating totals for ad: ${ad.adName}');
          print('   🚀 Trying summary collection for ad $adId');
        }

        // TRY SUMMARY COLLECTION FIRST (fast path - 1 query, no overlap issues)
        final summaryTotals = await _summaryService
            .calculateAdTotalsFromSummary(
              campaignId: campaignId,
              adId: adId,
              startDate: startDate,
              endDate: endDate,
            );

        Map<String, dynamic>? totals;

        if (summaryTotals != null) {
          if (kDebugMode) {
            print('   ✅ Using SUMMARY collection (fast, accurate)');
          }
          totals = summaryTotals;
        } else {
          // FALLBACK: Calculate from weekly insights if summary data not available
          if (kDebugMode) {
            print('   ⚠️ No summary data, falling back to weeklyInsights');
          }
          totals = await _calculateAdTotalsFromWeeklyInsights(
            adId: adId,
            startDate: startDate,
            endDate: endDate,
          );
        }

        // Skip ads with no data in the date range
        if (totals == null || totals['adsInRange'] == 0) {
          if (kDebugMode) {
            print('   ⏭️ Skipping ad $adId (no data in range)');
          }
          continue;
        }

        // Create a new ad with updated totals
        // Calculate derived metrics
        final profit = totals['totalCashAmount'] - totals['totalSpend'];
        final cpl = totals['totalLeads'] > 0
            ? totals['totalSpend'] / totals['totalLeads']
            : 0.0;
        final cpb = totals['totalBookings'] > 0
            ? totals['totalSpend'] / totals['totalBookings']
            : 0.0;
        final cpa = totals['totalDeposits'] > 0
            ? totals['totalSpend'] / totals['totalDeposits']
            : 0.0;

        final updatedAd = Ad(
          adId: ad.adId,
          adName: ad.adName,
          adSetId: ad.adSetId,
          adSetName: ad.adSetName,
          campaignId: ad.campaignId,
          campaignName: ad.campaignName,
          facebookStats: FacebookStats(
            spend: totals['totalSpend'],
            impressions: totals['totalImpressions'],
            clicks: totals['totalClicks'],
            reach: totals['totalReach'],
            cpm: totals['cpm'],
            cpc: totals['cpc'],
            ctr: totals['ctr'],
            dateStart: ad.facebookStats.dateStart,
            dateStop: ad.facebookStats.dateStop,
          ),
          ghlStats: GHLStats(
            leads: totals['totalLeads'],
            bookings: totals['totalBookings'],
            deposits: totals['totalDeposits'],
            cashCollected: totals['totalCashCollected'],
            cashAmount: totals['totalCashAmount'],
          ),
          profit: profit,
          cpl: cpl,
          cpb: cpb,
          cpa: cpa,
          status: ad.status,
          lastUpdated: ad.lastUpdated,
          createdAt: ad.createdAt,
          firstInsightDate: ad.firstInsightDate,
          lastInsightDate: ad.lastInsightDate,
          lastFacebookSync: ad.lastFacebookSync,
          lastGHLSync: ad.lastGHLSync,
        );

        adsWithDateFilteredTotals.add(updatedAd);
        adsWithData++;
      }

      if (kDebugMode) {
        print('   ✅ $adsWithData ads with data in range');
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
