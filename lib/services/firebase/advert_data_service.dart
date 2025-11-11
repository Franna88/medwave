import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/performance/advert_data_models.dart';

/// Service for managing advert data from the new advertData collection
/// This collection has a cleaner structure with Facebook and GHL data in synchronized weekly subcollections
class AdvertDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection reference
  static const String _collectionName = 'advertData';
  
  // Cloud Function endpoints
  static const String _cloudFunctionBaseUrl = 'https://us-central1-medx-ai.cloudfunctions.net/api';

  // ========== READ OPERATIONS ==========

  /// Get all adverts
  static Future<List<Map<String, dynamic>>> getAllAdverts() async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching all adverts from advertData collection...');
      }

      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('lastUpdated', descending: true)
          .get();

      final adverts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${adverts.length} adverts');
      }

      return adverts;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching adverts: $e');
      }
      rethrow;
    }
  }

  /// Get a single advert by ID
  static Future<Map<String, dynamic>?> getAdvert(String adId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(adId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('⚠️ Advert not found: $adId');
        }
        return null;
      }

      return {
        'id': doc.id,
        ...doc.data()!,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching advert $adId: $e');
      }
      rethrow;
    }
  }

  /// Get Facebook weekly insights for an advert
  static Future<List<Map<String, dynamic>>> getAdvertInsights(String adId) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching Facebook insights for ad $adId...');
      }

      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(adId)
          .collection('insights')
          .orderBy('dateStart', descending: false)
          .get();

      final insights = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'weekId': doc.id,
          'weekNumber': data['weekNumber'] ?? 0,
          'dateStart': (data['dateStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'dateStop': (data['dateStop'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'spend': (data['spend'] ?? 0).toDouble(),
          'impressions': data['impressions'] ?? 0,
          'reach': data['reach'] ?? 0,
          'clicks': data['clicks'] ?? 0,
          'cpm': (data['cpm'] ?? 0).toDouble(),
          'cpc': (data['cpc'] ?? 0).toDouble(),
          'ctr': (data['ctr'] ?? 0).toDouble(),
          'fetchedAt': (data['fetchedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${insights.length} weeks of Facebook insights');
      }

      return insights;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching insights for ad $adId: $e');
      }
      rethrow;
    }
  }

  /// Get GHL weekly data for an advert
  static Future<List<Map<String, dynamic>>> getAdvertGHLWeekly(String adId) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching GHL weekly data for ad $adId...');
      }

      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(adId)
          .collection('ghlWeekly')
          .orderBy('dateStart', descending: false)
          .get();

      final weeklyData = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'weekId': doc.id,
          'weekNumber': data['weekNumber'] ?? 0,
          'dateStart': (data['dateStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'dateStop': (data['dateStop'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'leads': data['leads'] ?? 0,
          'bookedAppointments': data['bookedAppointments'] ?? 0,
          'deposits': data['deposits'] ?? 0,
          'cashCollected': data['cashCollected'] ?? 0,
          'cashAmount': (data['cashAmount'] ?? 0).toDouble(),
          'lastUpdated': (data['lastUpdated'] as Timestamp?)?.toDate(),
        };
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${weeklyData.length} weeks of GHL data');
      }

      return weeklyData;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GHL weekly data for ad $adId: $e');
      }
      rethrow;
    }
  }

  /// Get complete weekly data (Facebook + GHL) for an advert
  static Future<Map<String, dynamic>> getAdvertWeeklyData(String adId) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching complete weekly data for ad $adId...');
      }

      final advert = await getAdvert(adId);
      final facebookInsights = await getAdvertInsights(adId);
      final ghlWeekly = await getAdvertGHLWeekly(adId);

      // Create a map of weekId to combined data
      final weeklyMap = <String, Map<String, dynamic>>{};

      // Add Facebook insights
      for (final insight in facebookInsights) {
        weeklyMap[insight['weekId']] = {
          ...insight,
          'facebook': insight,
        };
      }

      // Add GHL data
      for (final ghlWeek in ghlWeekly) {
        if (weeklyMap.containsKey(ghlWeek['weekId'])) {
          weeklyMap[ghlWeek['weekId']]!['ghl'] = ghlWeek;
        } else {
          weeklyMap[ghlWeek['weekId']] = {
            'weekId': ghlWeek['weekId'],
            'weekNumber': ghlWeek['weekNumber'],
            'dateStart': ghlWeek['dateStart'],
            'dateStop': ghlWeek['dateStop'],
            'ghl': ghlWeek,
          };
        }
      }

      // Convert to sorted list
      final weekly = weeklyMap.values.toList()
        ..sort((a, b) => (a['weekNumber'] as int).compareTo(b['weekNumber'] as int));

      return {
        'advert': advert,
        'weekly': weekly,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching complete weekly data for ad $adId: $e');
      }
      rethrow;
    }
  }

  /// Get GHL totals for an advert by summing all weekly documents
  static Future<Map<String, dynamic>> getAdvertGHLTotals(String adId) async {
    try {
      final weeklyData = await getAdvertGHLWeekly(adId);

      final totals = {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0.0,
      };

      for (final week in weeklyData) {
        totals['leads'] = (totals['leads'] as int) + (week['leads'] as int);
        totals['bookedAppointments'] = (totals['bookedAppointments'] as int) + (week['bookedAppointments'] as int);
        totals['deposits'] = (totals['deposits'] as int) + (week['deposits'] as int);
        totals['cashCollected'] = (totals['cashCollected'] as int) + (week['cashCollected'] as int);
        totals['cashAmount'] = (totals['cashAmount'] as double) + (week['cashAmount'] as double);
      }

      if (kDebugMode) {
        print('✅ Calculated GHL totals for ad $adId: $totals');
      }

      return totals;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calculating GHL totals for ad $adId: $e');
      }
      rethrow;
    }
  }

  /// Stream adverts in real-time
  static Stream<List<Map<String, dynamic>>> streamAdverts() {
    return _firestore
        .collection(_collectionName)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
          final adverts = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          
          if (kDebugMode) {
            print('📊 Real-time update: ${adverts.length} adverts');
          }
          
          return adverts;
        });
  }

  /// Stream weekly data for a specific advert
  static Stream<Map<String, dynamic>> streamAdvertWeeklyData(String adId) async* {
    // This combines multiple streams - not ideal but necessary for the structure
    // Consider using StreamGroup or similar if performance becomes an issue
    
    await for (final _ in _firestore.collection(_collectionName).doc(adId).snapshots()) {
      try {
        final weeklyData = await getAdvertWeeklyData(adId);
        yield weeklyData;
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error streaming weekly data: $e');
        }
        yield {'error': e.toString()};
      }
    }
  }

  // ========== SYNC OPERATIONS ==========

  /// Trigger Facebook ads sync to advertData collection
  static Future<Map<String, dynamic>> triggerFacebookSync({int monthsBack = 6}) async {
    try {
      if (kDebugMode) {
        print('🔄 Triggering Facebook sync via Cloud Function...');
      }

      final url = Uri.parse('$_cloudFunctionBaseUrl/advertdata/sync-facebook');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'monthsBack': monthsBack,
        }),
      ).timeout(const Duration(minutes: 5)); // 5 minute timeout for large syncs

      if (response.statusCode != 200) {
        throw Exception('Facebook sync failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✅ Facebook sync completed');
        print('   - Result: ${result['message']}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error triggering Facebook sync: $e');
      }
      rethrow;
    }
  }

  /// Get advertData collection stats
  static Future<Map<String, dynamic>> getCollectionStats() async {
    try {
      if (kDebugMode) {
        print('📊 Fetching advertData collection stats...');
      }

      final url = Uri.parse('$_cloudFunctionBaseUrl/advertdata/stats');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Stats fetch failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✅ Stats fetched: ${result['stats']}');
      }

      return result['stats'] as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching stats: $e');
      }
      rethrow;
    }
  }

  /// Get GHL totals from Cloud Function (server-side calculation)
  static Future<Map<String, dynamic>> getGHLTotalsFromAPI(String adId) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching GHL totals from API for ad $adId...');
      }

      final url = Uri.parse('$_cloudFunctionBaseUrl/advertdata/$adId/totals');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Totals fetch failed: ${response.statusCode} ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✅ GHL totals fetched: ${result['totals']}');
      }

      return result['totals'] as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GHL totals from API: $e');
      }
      rethrow;
    }
  }

  // ========== NEW METHODS FOR AGGREGATED DATA WITH MONTH-FIRST STRUCTURE ==========

  /// Get all available months from advertData collection
  /// Filters out placeholder months like "_placeh" and "unknown"
  static Future<List<String>> getAvailableMonths() async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching available months from advertData collection...');
      }

      final snapshot = await _firestore.collection(_collectionName).get();
      
      // Filter to only valid month documents (have totalAds field and valid format YYYY-MM)
      final months = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final id = doc.id;
            // Must have totalAds field and match YYYY-MM format (not _placeh or unknown)
            return data.containsKey('totalAds') && 
                   id.contains('-') && 
                   !id.startsWith('_') && 
                   id != 'unknown';
          })
          .map((doc) => doc.id)
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Newest first

      if (kDebugMode) {
        print('✅ Found ${months.length} valid months: $months');
      }

      return months;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching available months: $e');
      }
      rethrow;
    }
  }

  /// Get all adverts with aggregated totals from weekly subcollections
  /// Uses month-first structure: advertData/{month}/ads/{adId}
  /// Optionally filter by date range (filters client-side after fetching)
  static Future<List<AdvertDataWithTotals>> getAllAdvertsWithTotals({
    required List<String> months,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching adverts with totals from advertData collection...');
        print('   📅 Months: $months');
        if (startDate != null) {
          print('   📅 Start date: ${startDate.toIso8601String()}');
        }
        if (endDate != null) {
          print('   📅 End date: ${endDate.toIso8601String()}');
        }
      }

      final List<AdvertDataWithTotals> advertsWithTotals = [];

      // Query each month's ads subcollection
      for (final month in months) {
        try {
          if (kDebugMode) {
            print('   🔍 Querying month: $month');
          }

          final snapshot = await _firestore
              .collection(_collectionName)
              .doc(month)
              .collection('ads')
              .get();

          if (kDebugMode) {
            print('   ✅ Found ${snapshot.docs.length} ads in $month');
          }

          // Fetch and aggregate data for each advert
          for (final doc in snapshot.docs) {
            try {
              final advertData = AdvertData.fromFirestore(doc.data(), doc.id);
              
              // Fetch and aggregate Facebook insights
              final facebookInsights = await _fetchFacebookInsights(doc.id, month);
              final facebookTotals = FacebookInsightTotals.fromWeeklyInsights(facebookInsights);
              
              // Fetch and aggregate GHL weekly data
              final ghlWeekly = await _fetchGHLWeekly(doc.id, month);
              final ghlTotals = GHLDataTotals.fromWeeklyData(ghlWeekly);
              
              // Debug print for this ad's raw data from Firebase
              if (kDebugMode) {
                print('      📦 RAW FIREBASE DATA for ${advertData.adName} (${doc.id}):');
                print('         FB Weeks: ${facebookInsights.length}');
                print('         FB Total Spend: \$${facebookTotals.totalSpend.toStringAsFixed(2)}');
                print('         FB Total Impressions: ${facebookTotals.totalImpressions}');
                print('         FB Total Clicks: ${facebookTotals.totalClicks}');
                print('         FB Total Reach: ${facebookTotals.totalReach}');
                print('         GHL Weeks: ${ghlWeekly.length}');
                print('         GHL Total Leads: ${ghlTotals.totalLeads}');
                print('         GHL Total Cash: \$${ghlTotals.totalCashAmount.toStringAsFixed(2)}');
                print('         GHL Total Booked Appointments: ${ghlTotals.totalBookedAppointments}');
              }
              
              // Apply date filtering if provided
              bool includeAd = true;
              if (startDate != null || endDate != null) {
                DateTime? adDate = advertData.lastUpdated;
                
                // Try to parse dateStart from Facebook totals if lastUpdated is null
                if (adDate == null && facebookTotals.dateStart.isNotEmpty) {
                  try {
                    adDate = DateTime.parse(facebookTotals.dateStart);
                  } catch (e) {
                    // Ignore parse errors
                  }
                }
                
                if (adDate != null) {
                  if (startDate != null && adDate.isBefore(startDate)) {
                    includeAd = false;
                  }
                  if (endDate != null && adDate.isAfter(endDate)) {
                    includeAd = false;
                  }
                }
              }
              
              if (includeAd) {
                advertsWithTotals.add(AdvertDataWithTotals(
                  advert: advertData,
                  facebookTotals: facebookTotals,
                  ghlTotals: ghlTotals,
                ));
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Error aggregating data for ad ${doc.id} in month $month: $e');
              }
              // Continue with other ads even if one fails
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error querying month $month: $e');
          }
          // Continue with other months even if one fails
        }
      }

      if (kDebugMode) {
        print('✅ Successfully aggregated ${advertsWithTotals.length} adverts with totals');
        final withGHL = advertsWithTotals.where((a) => a.hasGHLData).length;
        final withFB = advertsWithTotals.where((a) => a.hasFacebookData).length;
        print('   - With Facebook data: $withFB');
        print('   - With GHL data: $withGHL');
      }

      return advertsWithTotals;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching adverts with totals: $e');
      }
      rethrow;
    }
  }

  /// Get aggregated totals for a single advert
  /// Requires month parameter for new structure
  static Future<AdvertDataWithTotals> getAdvertTotals(String adId, String month) async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching totals for ad $adId in month $month...');
      }

      // Get main advert document from month-first structure
      final doc = await _firestore
          .collection(_collectionName)
          .doc(month)
          .collection('ads')
          .doc(adId)
          .get();
      
      if (!doc.exists) {
        throw Exception('Advert not found: $adId in month $month');
      }

      final advertData = AdvertData.fromFirestore(doc.data()!, doc.id);
      
      // Fetch and aggregate Facebook insights
      final facebookInsights = await _fetchFacebookInsights(adId, month);
      final facebookTotals = FacebookInsightTotals.fromWeeklyInsights(facebookInsights);
      
      // Fetch and aggregate GHL weekly data
      final ghlWeekly = await _fetchGHLWeekly(adId, month);
      final ghlTotals = GHLDataTotals.fromWeeklyData(ghlWeekly);

      if (kDebugMode) {
        print('✅ Aggregated totals for ad $adId');
        print('   - FB Spend: \$${facebookTotals.totalSpend.toStringAsFixed(2)}');
        print('   - GHL Leads: ${ghlTotals.totalLeads}');
        print('   - GHL Cash: \$${ghlTotals.totalCashAmount.toStringAsFixed(2)}');
      }

      return AdvertDataWithTotals(
        advert: advertData,
        facebookTotals: facebookTotals,
        ghlTotals: ghlTotals,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching totals for ad $adId: $e');
      }
      rethrow;
    }
  }

  /// Helper: Fetch Facebook insights for an ad from month-first structure
  static Future<List<FacebookInsightWeekly>> _fetchFacebookInsights(String adId, String month) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(month)
          .collection('ads')
          .doc(adId)
          .collection('insights')
          .get();

      return snapshot.docs
          .map((doc) => FacebookInsightWeekly.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error fetching Facebook insights for ad $adId in month $month: $e');
      }
      return []; // Return empty list on error
    }
  }

  /// Helper: Fetch GHL weekly data for an ad from month-first structure
  static Future<List<GHLWeeklyData>> _fetchGHLWeekly(String adId, String month) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(month)
          .collection('ads')
          .doc(adId)
          .collection('ghlWeekly')
          .get();

      return snapshot.docs
          .map((doc) => GHLWeeklyData.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error fetching GHL weekly data for ad $adId in month $month: $e');
      }
      return []; // Return empty list on error
    }
  }
}

