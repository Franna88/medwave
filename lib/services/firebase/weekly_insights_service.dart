import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/facebook/facebook_ad_data.dart';

/// Service for fetching weekly insights from Firestore
class WeeklyInsightsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch weekly insights for a specific ad from Firestore
  static Future<List<FacebookWeeklyInsight>> fetchWeeklyInsightsForAd(
    String adId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching weekly insights for ad $adId from Firestore...');
      }

      Query query = _firestore
          .collection('adPerformance')
          .doc(adId)
          .collection('weeklyInsights');

      // Apply date filters if provided
      if (startDate != null) {
        query = query.where('dateStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('dateStart', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      // Order by date
      query = query.orderBy('dateStart', descending: false);

      final snapshot = await query.get();

      final weeklyInsights = snapshot.docs.map((doc) {
        return FacebookWeeklyInsight.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${weeklyInsights.length} weeks for ad $adId');
      }

      return weeklyInsights;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching weekly insights for ad $adId: $e');
      }
      return [];
    }
  }

  /// Fetch weekly insights for multiple ads
  static Future<Map<String, List<FacebookWeeklyInsight>>> fetchWeeklyInsightsForAds(
    List<String> adIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final results = <String, List<FacebookWeeklyInsight>>{};

    for (final adId in adIds) {
      final weeklyData = await fetchWeeklyInsightsForAd(
        adId,
        startDate: startDate,
        endDate: endDate,
      );
      results[adId] = weeklyData;
    }

    return results;
  }

  /// Fetch ALL weekly insights for a date range using collection group query (FAST)
  /// This is much faster than querying each ad individually
  static Future<Map<String, List<FacebookWeeklyInsight>>> fetchAllWeeklyInsightsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching ALL weekly insights for date range: ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}');
      }

      // Use collection group query to get all weeklyInsights across all ads in one query
      Query query = _firestore.collectionGroup('weeklyInsights');

      // Apply date filters
      query = query
          .where('dateStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('dateStart', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('dateStart', descending: false);

      final snapshot = await query.get();

      if (kDebugMode) {
        print('✅ Fetched ${snapshot.docs.length} total weekly insights from Firestore');
      }

      // Group by adId
      final results = <String, List<FacebookWeeklyInsight>>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final insight = FacebookWeeklyInsight.fromFirestore(data);
        
        if (!results.containsKey(insight.adId)) {
          results[insight.adId] = [];
        }
        results[insight.adId]!.add(insight);
      }

      if (kDebugMode) {
        print('✅ Grouped into ${results.length} ads with data');
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching weekly insights for date range: $e');
      }
      return {};
    }
  }

  /// Get the most recent week for an ad
  static Future<FacebookWeeklyInsight?> getLatestWeekForAd(String adId) async {
    try {
      final snapshot = await _firestore
          .collection('adPerformance')
          .doc(adId)
          .collection('weeklyInsights')
          .orderBy('dateStart', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return FacebookWeeklyInsight.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching latest week for ad $adId: $e');
      }
      return null;
    }
  }

  /// Get week count for an ad
  static Future<int> getWeekCountForAd(String adId) async {
    try {
      final snapshot = await _firestore
          .collection('adPerformance')
          .doc(adId)
          .collection('weeklyInsights')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error counting weeks for ad $adId: $e');
      }
      return 0;
    }
  }

  /// Get aggregated metrics across all weeks for an ad
  static Future<Map<String, dynamic>> getAggregatedMetrics(
    String adId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final weeklyData = await fetchWeeklyInsightsForAd(
      adId,
      startDate: startDate,
      endDate: endDate,
    );

    if (weeklyData.isEmpty) {
      return {
        'totalSpend': 0.0,
        'totalImpressions': 0,
        'totalReach': 0,
        'totalClicks': 0,
        'avgCpm': 0.0,
        'avgCpc': 0.0,
        'avgCtr': 0.0,
        'weekCount': 0,
      };
    }

    final totalSpend = weeklyData.fold<double>(0, (sum, week) => sum + week.spend);
    final totalImpressions = weeklyData.fold<int>(0, (sum, week) => sum + week.impressions);
    final totalReach = weeklyData.fold<int>(0, (sum, week) => sum + week.reach);
    final totalClicks = weeklyData.fold<int>(0, (sum, week) => sum + week.clicks);
    
    final avgCpm = weeklyData.fold<double>(0, (sum, week) => sum + week.cpm) / weeklyData.length;
    final avgCpc = weeklyData.fold<double>(0, (sum, week) => sum + week.cpc) / weeklyData.length;
    final avgCtr = weeklyData.fold<double>(0, (sum, week) => sum + week.ctr) / weeklyData.length;

    return {
      'totalSpend': totalSpend,
      'totalImpressions': totalImpressions,
      'totalReach': totalReach,
      'totalClicks': totalClicks,
      'avgCpm': avgCpm,
      'avgCpc': avgCpc,
      'avgCtr': avgCtr,
      'weekCount': weeklyData.length,
    };
  }

  /// Stream weekly insights for real-time updates
  static Stream<List<FacebookWeeklyInsight>> streamWeeklyInsightsForAd(
    String adId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('adPerformance')
        .doc(adId)
        .collection('weeklyInsights');

    // Apply date filters if provided
    if (startDate != null) {
      query = query.where('dateStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('dateStart', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    // Order by date
    query = query.orderBy('dateStart', descending: false);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return FacebookWeeklyInsight.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}

