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

      // Ensure dates are provided
      if (startDate == null || endDate == null) {
        if (kDebugMode) {
          print('   ⚠️ Start date or end date is null, returning empty list');
        }
        return [];
      }

      // Get ad IDs with activity in date range from summary collection
      final adIds = await _summaryService.getAdIdsWithActivityInDateRange(
        campaignId: campaignId,
        adSetId: adSetId,
        startDate: startDate,
        endDate: endDate,
      );

      if (kDebugMode) {
        print(
          '   📋 Found ${adIds.length} ads in ad set from SUMMARY collection',
        );
        if (adIds.isNotEmpty) {
          print(
            '   📋 Ad IDs: ${adIds.take(5).join(", ")}${adIds.length > 5 ? "..." : ""}',
          );
        }
      }

      List<Ad> adsWithDateFilteredTotals = [];
      int adsWithData = 0;
      double totalSpendFromSummary = 0.0;
      double totalSpendFromIncludedAds = 0.0;
      List<String> adsSkipped = [];
      List<String> adsIncluded = [];

      // Get ad set and campaign metadata for building Ad objects
      String adSetName = 'Unknown Ad Set';
      String campaignName = 'Unknown Campaign';
      try {
        final adSetDoc = await _firestore
            .collection('adSets')
            .doc(adSetId)
            .get();
        if (adSetDoc.exists) {
          final adSetData = adSetDoc.data();
          adSetName = adSetData?['adSetName'] ?? adSetName;
          campaignName = adSetData?['campaignName'] ?? campaignName;
        }
      } catch (e) {
        if (kDebugMode) {
          print('   ⚠️ Could not fetch ad set metadata: $e');
        }
      }

      for (var adId in adIds) {
        if (kDebugMode) {
          print(
            '   ┌─────────────────────────────────────────────────────────',
          );
          print('   │ Processing ad ID: $adId');
          print('   │ Ad Set ID: $adSetId');
        }

        // Get totals from summary collection
        final summaryTotals = await _summaryService
            .calculateAdTotalsFromSummary(
              campaignId: campaignId,
              adId: adId,
              startDate: startDate,
              endDate: endDate,
            );

        if (summaryTotals == null) {
          if (kDebugMode) {
            print('   │ ❌ SKIPPING: totals is null (no data found in summary)');
            print(
              '   └─────────────────────────────────────────────────────────',
            );
          }
          adsSkipped.add('$adId - null totals from summary');
          continue;
        }

        final weeksUsed = summaryTotals['adsInRange'] ?? 0;
        if (weeksUsed == 0) {
          if (kDebugMode) {
            print('   │ ❌ SKIPPING: weeksUsed == 0 (no weeks matched)');
            print(
              '   └─────────────────────────────────────────────────────────',
            );
          }
          adsSkipped.add('$adId - weeksUsed=0');
          continue;
        }

        final spend = (summaryTotals['totalSpend'] as num?)?.toDouble() ?? 0.0;
        totalSpendFromSummary += spend;

        // Try to get ad metadata from ads collection (fallback - will migrate to fb_ads later)
        String adName = 'Ad $adId';
        String status = 'ACTIVE';
        DateTime? lastUpdated;
        DateTime? lastFacebookSync;
        DateTime? lastGHLSync;
        DateTime? createdAt;
        String? firstInsightDate;
        String? lastInsightDate;
        String? dateStart;
        String? dateStop;

        try {
          final adDoc = await _firestore.collection('ads').doc(adId).get();
          if (adDoc.exists) {
            final adData = adDoc.data();
            adName = adData?['adName'] ?? adName;
            status = adData?['status'] ?? status;
            lastUpdated = (adData?['lastUpdated'] as Timestamp?)?.toDate();
            lastFacebookSync = (adData?['lastFacebookSync'] as Timestamp?)
                ?.toDate();
            lastGHLSync = (adData?['lastGHLSync'] as Timestamp?)?.toDate();
            createdAt = (adData?['createdAt'] as Timestamp?)?.toDate();
            firstInsightDate = adData?['firstInsightDate'];
            lastInsightDate = adData?['lastInsightDate'];
            final fbStats = adData?['facebookStats'] as Map<String, dynamic>?;
            dateStart = fbStats?['dateStart'];
            dateStop = fbStats?['dateStop'];
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '   │ ⚠️ Could not fetch ad metadata from ads collection: $e',
            );
            print('   │    Using defaults');
          }
        }

        if (kDebugMode) {
          print('   │ ✅ Using SUMMARY collection (fast, accurate)');
          print('   │    Ad Name: $adName');
          print('   │    Spend: \$${spend.toStringAsFixed(2)}');
          print('   │    Weeks used: $weeksUsed');
          print(
            '   │    Impressions: ${summaryTotals['totalImpressions'] ?? 0}',
          );
          print('   │    Clicks: ${summaryTotals['totalClicks'] ?? 0}');
        }

        // Create a new ad with updated totals from summary
        // Calculate derived metrics
        final profit =
            summaryTotals['totalCashAmount'] - summaryTotals['totalSpend'];
        final cpl = summaryTotals['totalLeads'] > 0
            ? summaryTotals['totalSpend'] / summaryTotals['totalLeads']
            : 0.0;
        final cpb = summaryTotals['totalBookings'] > 0
            ? summaryTotals['totalSpend'] / summaryTotals['totalBookings']
            : 0.0;
        final cpa = summaryTotals['totalDeposits'] > 0
            ? summaryTotals['totalSpend'] / summaryTotals['totalDeposits']
            : 0.0;

        final updatedAd = Ad(
          adId: adId,
          adName: adName,
          adSetId: adSetId,
          adSetName: adSetName,
          campaignId: campaignId,
          campaignName: campaignName,
          facebookStats: FacebookStats(
            spend: summaryTotals['totalSpend'] ?? 0.0,
            impressions: summaryTotals['totalImpressions'] ?? 0,
            clicks: summaryTotals['totalClicks'] ?? 0,
            reach: summaryTotals['totalReach'] ?? 0,
            cpm: summaryTotals['cpm'] ?? 0.0,
            cpc: summaryTotals['cpc'] ?? 0.0,
            ctr: summaryTotals['ctr'] ?? 0.0,
            dateStart: dateStart ?? '',
            dateStop: dateStop ?? '',
          ),
          ghlStats: GHLStats(
            leads: summaryTotals['totalLeads'] ?? 0,
            bookings: summaryTotals['totalBookings'] ?? 0,
            deposits: summaryTotals['totalDeposits'] ?? 0,
            cashCollected: summaryTotals['totalCashCollected'] ?? 0,
            cashAmount: summaryTotals['totalCashAmount'] ?? 0.0,
          ),
          profit: profit,
          cpl: cpl,
          cpb: cpb,
          cpa: cpa,
          status: status,
          lastUpdated: lastUpdated,
          createdAt: createdAt,
          firstInsightDate: firstInsightDate,
          lastInsightDate: lastInsightDate,
          lastFacebookSync: lastFacebookSync,
          lastGHLSync: lastGHLSync,
        );

        adsWithDateFilteredTotals.add(updatedAd);
        adsWithData++;
        adsIncluded.add(
          '$adId ($adName) - spend=\$${spend.toStringAsFixed(2)}',
        );
        totalSpendFromIncludedAds += spend;

        if (kDebugMode) {
          print('   │ ✅ INCLUDED in results');
          print(
            '   └─────────────────────────────────────────────────────────',
          );
        }
      }

      if (kDebugMode) {
        print(
          '   ════════════════════════════════════════════════════════════',
        );
        print('   📊 AD FILTERING SUMMARY:');
        print('   │ Total ads in SUMMARY collection: ${adIds.length}');
        print('   │ Ads included: $adsWithData');
        print('   │ Ads skipped: ${adsSkipped.length}');
        print('   │');
        print('   │ 💰 SPEND BREAKDOWN:');
        print(
          '   │    Total spend from all ads (summary): \$${totalSpendFromSummary.toStringAsFixed(2)}',
        );
        print(
          '   │    Total spend from included ads: \$${totalSpendFromIncludedAds.toStringAsFixed(2)}',
        );
        print(
          '   │    Missing spend: \$${(totalSpendFromSummary - totalSpendFromIncludedAds).toStringAsFixed(2)}',
        );
        print('   │');
        if (adsIncluded.isNotEmpty) {
          print('   │ ✅ INCLUDED ADS:');
          for (var adInfo in adsIncluded) {
            print('   │    - $adInfo');
          }
        }
        if (adsSkipped.isNotEmpty) {
          print('   │ ❌ SKIPPED ADS:');
          for (var adInfo in adsSkipped) {
            print('   │    - $adInfo');
          }
        }
        print(
          '   ════════════════════════════════════════════════════════════',
        );
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
