import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/performance/ad_performance_data.dart';

/// Service for managing ad performance data in Firebase
/// This service reads Facebook + GHL combined data from Firebase instead of making direct API calls
class AdPerformanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection reference
  static const String _collectionName = 'adPerformance';
  
  // Cloud Function endpoints (adjust URL based on deployment)
  static const String _cloudFunctionBaseUrl = 'https://us-central1-medx-ai.cloudfunctions.net/api';

  // ========== READ OPERATIONS ==========

  /// Get all ad performance data
  static Future<List<AdPerformanceData>> getAllAdPerformance() async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching all ad performance data from Firebase...');
      }

      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('lastUpdated', descending: true)
          .get();

      final adPerformanceList = snapshot.docs
          .map((doc) => AdPerformanceData.fromFirestore(doc))
          .toList();

      if (kDebugMode) {
        print('✅ Fetched ${adPerformanceList.length} ad performance records');
        final matched = adPerformanceList.where((a) => a.matchingStatus == MatchingStatus.matched).length;
        final unmatched = adPerformanceList.where((a) => a.matchingStatus == MatchingStatus.unmatched).length;
        print('   - Matched (FB + GHL): $matched');
        print('   - Unmatched (FB only): $unmatched');
      }

      return adPerformanceList;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance data: $e');
      }
      rethrow;
    }
  }

  /// Get a single ad performance record by ad ID
  static Future<AdPerformanceData?> getAdPerformance(String adId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(adId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('⚠️ Ad performance record not found: $adId');
        }
        return null;
      }

      return AdPerformanceData.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance for $adId: $e');
      }
      rethrow;
    }
  }

  /// Stream all ad performance data in real-time
  static Stream<List<AdPerformanceData>> streamAdPerformance() {
    return _firestore
        .collection(_collectionName)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
          final ads = snapshot.docs
              .map((doc) => AdPerformanceData.fromFirestore(doc))
              .toList();
          
          if (kDebugMode) {
            print('📊 Real-time update: ${ads.length} ad performance records');
          }
          
          return ads;
        });
  }

  /// Get ad performance data wrapped in AdPerformanceWithProduct
  static Future<List<AdPerformanceWithProduct>> getAdPerformanceWithProducts() async {
    try {
      final adPerformanceList = await getAllAdPerformance();
      
      // Wrap ad performance data (no product linking anymore)
      final combined = adPerformanceList.map((ad) {
        return AdPerformanceWithProduct(
          data: ad,
        );
      }).toList();
      
      return combined;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance: $e');
      }
      rethrow;
    }
  }

  // ========== SYNC OPERATIONS ==========

  /// Trigger Facebook data sync via Cloud Function
  static Future<Map<String, dynamic>> triggerFacebookSync({
    bool forceRefresh = true,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Triggering Facebook sync via Cloud Function...');
      }

      final url = Uri.parse('$_cloudFunctionBaseUrl/facebook/sync-ads');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'forceRefresh': forceRefresh,
        }),
      ).timeout(const Duration(seconds: 120)); // 2 minute timeout

      if (response.statusCode != 200) {
        throw Exception('Facebook sync failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✅ Facebook sync completed');
        print('   - Result: ${result['message']}');
        if (result['stats'] != null) {
          print('   - Stats: ${result['stats']}');
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error triggering Facebook sync: $e');
      }
      rethrow;
    }
  }

  /// Trigger GHL data sync via Cloud Function
  static Future<Map<String, dynamic>> triggerGHLSync() async {
    try {
      if (kDebugMode) {
        print('🔄 Triggering GHL sync via Cloud Function...');
      }

      final url = Uri.parse('$_cloudFunctionBaseUrl/ghl/sync-opportunity-history');
      final response = await http.post(url).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception('GHL sync failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✅ GHL sync completed');
        print('   - Result: ${result['message']}');
        if (result['stats'] != null) {
          print('   - Stats: ${result['stats']}');
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error triggering GHL sync: $e');
      }
      rethrow;
    }
  }

  // ========== UTILITY OPERATIONS ==========

  /// Get sync status information
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      // Get the most recently updated record to determine last sync time
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'hasData': false,
          'lastSync': null,
          'totalAds': 0,
        };
      }

      final lastDoc = snapshot.docs.first;
      final data = lastDoc.data();
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
      
      // Get total count
      final countSnapshot = await _firestore
          .collection(_collectionName)
          .count()
          .get();

      return {
        'hasData': true,
        'lastSync': lastUpdated,
        'totalAds': countSnapshot.count,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting sync status: $e');
      }
      rethrow;
    }
  }

  /// Delete an ad performance record (admin only)
  static Future<void> deleteAdPerformance(String adId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting ad performance record: $adId');
      }

      await _firestore
          .collection(_collectionName)
          .doc(adId)
          .delete();

      if (kDebugMode) {
        print('✅ Ad performance record deleted: $adId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting ad performance record: $e');
      }
      rethrow;
    }
  }
}

