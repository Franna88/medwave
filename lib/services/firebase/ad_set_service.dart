import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/performance/ad_set.dart';

/// Service for managing ad set data from the split collections schema
class AdSetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Helper method to convert DateTime to YYYY-MM-DD string
  static String _dateTimeToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculate ad set totals for a specific date range by aggregating from ads
  /// This provides month-specific or date-range-specific totals instead of lifetime totals
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

        // Get ad date range
        final firstInsightDate = data['firstInsightDate'] as String?;
        final lastInsightDate = data['lastInsightDate'] as String?;

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

        // Aggregate GHL stats
        final ghlStats = data['ghlStats'] as Map<String, dynamic>?;
        if (ghlStats != null) {
          totalLeads += (ghlStats['leads'] as num?)?.toInt() ?? 0;
          totalBookings += (ghlStats['bookings'] as num?)?.toInt() ?? 0;
          totalDeposits += (ghlStats['deposits'] as num?)?.toInt() ?? 0;
          totalCashCollected +=
              (ghlStats['cashCollected'] as num?)?.toInt() ?? 0;
          totalCashAmount += (ghlStats['cashAmount'] as num?)?.toDouble() ?? 0;
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
          lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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

  static String? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;

    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    return null;
  }
}
