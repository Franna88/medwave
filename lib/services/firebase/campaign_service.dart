import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/performance/campaign.dart';

/// Service for managing campaign data from the split collections schema
class CampaignService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all campaigns with cached totals
  /// Returns campaigns sorted by totalProfit (descending) by default
  Future<List<Campaign>> getAllCampaigns({
    int limit = 100,
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('campaigns');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all campaigns: $e');
      rethrow;
    }
  }

  /// Get a single campaign by ID
  Future<Campaign?> getCampaign(String campaignId) async {
    try {
      final doc = await _firestore
          .collection('campaigns')
          .doc(campaignId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Campaign.fromFirestore(doc);
    } catch (e) {
      print('Error getting campaign $campaignId: $e');
      rethrow;
    }
  }

  /// Get campaigns filtered by status
  Future<List<Campaign>> getCampaignsByStatus(
    String status, {
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('campaigns')
          .where('status', isEqualTo: status)
          .orderBy('lastUpdated', descending: true);

      if (limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting campaigns by status: $e');
      rethrow;
    }
  }

  /// Get campaigns within a date range using string date comparison
  Future<List<Campaign>> getCampaignsByDateRange({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('campaigns');

      if (startDate != null) {
        final startDateStr = _dateTimeToString(startDate);
        query = query.where('lastAdDate', isGreaterThanOrEqualTo: startDateStr);
      }

      if (startDate != null) {
        query = query.orderBy('lastAdDate', descending: false);
      }

      query = query.orderBy(orderBy, descending: descending);

      final fetchLimit = limit > 0 ? limit * 2 : 200;
      query = query.limit(fetchLimit);

      final snapshot = await query.get();

      List<Campaign> campaigns = snapshot.docs
          .map((doc) => Campaign.fromFirestore(doc))
          .toList();

      if (endDate != null) {
        final endDateStr = _dateTimeToString(endDate);
        campaigns = campaigns.where((campaign) {
          if (campaign.firstAdDate == null) return true;
          return campaign.firstAdDate!.compareTo(endDateStr) <= 0;
        }).toList();
      }

      if (limit > 0 && campaigns.length > limit) {
        campaigns = campaigns.take(limit).toList();
      }

      return campaigns;
    } catch (e) {
      print('Error getting campaigns by date range: $e');
      rethrow;
    }
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

      final startDateStr = startDate != null ? _dateTimeToString(startDate) : null;
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
      return {
        'spend': 0.0,
        'impressions': 0,
        'clicks': 0,
        'reach': 0,
      };
    }
  }

  /// Helper method to convert DateTime to YYYY-MM-DD string
  static String _dateTimeToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Stream campaigns for real-time updates
  Stream<List<Campaign>> streamCampaigns({
    int limit = 100,
    String? orderBy = 'totalProfit',
    bool descending = true,
  }) {
    try {
      Query query = _firestore.collection('campaigns');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit > 0) {
        query = query.limit(limit);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error streaming campaigns: $e');
      rethrow;
    }
  }

  /// Stream a single campaign for real-time updates
  Stream<Campaign?> streamCampaign(String campaignId) {
    try {
      return _firestore.collection('campaigns').doc(campaignId).snapshots().map(
        (doc) {
          if (!doc.exists) {
            return null;
          }
          return Campaign.fromFirestore(doc);
        },
      );
    } catch (e) {
      print('Error streaming campaign $campaignId: $e');
      rethrow;
    }
  }

  /// Get top campaigns by profit
  Future<List<Campaign>> getTopCampaignsByProfit(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .orderBy('totalProfit', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting top campaigns by profit: $e');
      rethrow;
    }
  }

  /// Get top campaigns by spend
  Future<List<Campaign>> getTopCampaignsBySpend(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .orderBy('totalSpend', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting top campaigns by spend: $e');
      rethrow;
    }
  }

  /// Get top campaigns by leads
  Future<List<Campaign>> getTopCampaignsByLeads(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .orderBy('totalLeads', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting top campaigns by leads: $e');
      rethrow;
    }
  }

  /// Search campaigns by name
  Future<List<Campaign>> searchCampaignsByName(String searchTerm) async {
    try {
      // Note: Firestore doesn't support full-text search
      // This is a simple prefix search
      final snapshot = await _firestore
          .collection('campaigns')
          .orderBy('campaignName')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff'])
          .get();

      return snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching campaigns: $e');
      rethrow;
    }
  }

  /// Calculate campaign totals for a specific date range by aggregating from ads
  /// This provides month-specific or date-range-specific totals instead of lifetime totals
  /// Uses weekly insights to get accurate month-specific spend data
  Future<Map<String, dynamic>> calculateCampaignTotalsForDateRange({
    required String campaignId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Query ads for this campaign
      Query query = _firestore
          .collection('ads')
          .where('campaignId', isEqualTo: campaignId);

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

      final startDateStr = startDate != null ? _dateTimeToString(startDate) : null;
      final endDateStr = endDate != null ? _dateTimeToString(endDate) : null;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final adId = doc.id;
        
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

        // Check if ad spans multiple months (needs weekly insights for accuracy)
        bool spansMultipleMonths = false;
        if (firstInsightDate != null && lastInsightDate != null && 
            startDateStr != null && endDateStr != null) {
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
          totalImpressions += (weeklyTotals['impressions'] as num?)?.toInt() ?? 0;
          totalClicks += (weeklyTotals['clicks'] as num?)?.toInt() ?? 0;
          totalReach += (weeklyTotals['reach'] as num?)?.toInt() ?? 0;
        } else {
          // Ad is within a single month - use aggregated stats (fast!)
          final facebookStats = data['facebookStats'] as Map<String, dynamic>?;
          if (facebookStats != null) {
            totalSpend += (facebookStats['spend'] as num?)?.toDouble() ?? 0;
            totalImpressions += (facebookStats['impressions'] as num?)?.toInt() ?? 0;
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
          
          // Parse createdAt (can be either Timestamp or String)
          DateTime? createdAt;
          final createdAtField = oppData['createdAt'];
          if (createdAtField is Timestamp) {
            createdAt = createdAtField.toDate();
          } else if (createdAtField is String) {
            try {
              createdAt = DateTime.parse(createdAtField);
            } catch (e) {
              // Skip if date parsing fails
              continue;
            }
          }
          
          // Filter by date range
          if (createdAt != null) {
            if (startDate != null && createdAt.isBefore(startDate)) continue;
            if (endDate != null && createdAt.isAfter(endDate)) continue;
          }
          
          // Count by stage category
          final stageCategory = oppData['stageCategory'] as String? ?? '';
          final monetaryValue = (oppData['monetaryValue'] as num?)?.toDouble() ?? 0;
          
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
      final roi = totalSpend > 0 ? (totalProfit / totalSpend) * 100 : 0;
      final ctr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0;
      final cpm = totalImpressions > 0 ? (totalSpend / totalImpressions) * 1000 : 0;
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
        'roi': roi,
        'ctr': ctr,
        'cpm': cpm,
        'cpc': cpc,
        'adsInRange': adsInRange,
      };
    } catch (e) {
      print('Error calculating campaign totals for date range: $e');
      rethrow;
    }
  }

  /// Get campaigns with month-specific totals from pre-aggregated monthlyTotals
  /// This is FAST and ACCURATE - uses pre-calculated monthly data
  Future<List<Campaign>> getCampaignsWithMonthTotals({
    required String month, // Format: "2025-11"
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      // Get all campaigns (we'll filter by month data existence client-side)
      final snapshot = await _firestore
          .collection('campaigns')
          .limit(limit * 2) // Fetch more to account for filtering
          .get();

      List<Campaign> campaignsWithMonthData = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final monthlyTotals = data['monthlyTotals'] as Map<String, dynamic>?;

        // Check if this campaign has data for the requested month
        if (monthlyTotals == null || !monthlyTotals.containsKey(month)) {
          continue; // Skip campaigns without data for this month
        }

        final monthData = monthlyTotals[month] as Map<String, dynamic>;

        // Calculate conversion rates
        final leads = (monthData['leads'] as num?)?.toInt() ?? 0;
        final bookings = (monthData['bookings'] as num?)?.toInt() ?? 0;
        final deposits = (monthData['deposits'] as num?)?.toInt() ?? 0;
        final cashCollected = (monthData['cashCollected'] as num?)?.toInt() ?? 0;

        final leadToBookingRate = leads > 0 ? (bookings / leads) * 100 : 0.0;
        final bookingToDepositRate = bookings > 0 ? (deposits / bookings) * 100 : 0.0;
        final depositToCashRate = deposits > 0 ? (cashCollected / deposits) * 100 : 0.0;

        // Create campaign with month-specific data
        final campaign = Campaign(
          campaignId: doc.id,
          campaignName: data['campaignName'] ?? '',
          status: data['status'] ?? 'UNKNOWN',
          totalSpend: (monthData['spend'] as num?)?.toDouble() ?? 0,
          totalImpressions: (monthData['impressions'] as num?)?.toInt() ?? 0,
          totalClicks: (monthData['clicks'] as num?)?.toInt() ?? 0,
          totalReach: (monthData['reach'] as num?)?.toInt() ?? 0,
          avgCPM: (monthData['cpm'] as num?)?.toDouble() ?? 0,
          avgCPC: (monthData['cpc'] as num?)?.toDouble() ?? 0,
          avgCTR: (monthData['ctr'] as num?)?.toDouble() ?? 0,
          totalLeads: leads,
          totalBookings: bookings,
          totalDeposits: deposits,
          totalCashCollected: cashCollected,
          totalCashAmount: (monthData['cashAmount'] as num?)?.toDouble() ?? 0,
          totalProfit: (monthData['profit'] as num?)?.toDouble() ?? 0,
          cpl: (monthData['cpl'] as num?)?.toDouble() ?? 0,
          cpb: (monthData['cpb'] as num?)?.toDouble() ?? 0,
          cpa: (monthData['cpa'] as num?)?.toDouble() ?? 0,
          roi: (monthData['roi'] as num?)?.toDouble() ?? 0,
          leadToBookingRate: leadToBookingRate,
          bookingToDepositRate: bookingToDepositRate,
          depositToCashRate: depositToCashRate,
          adSetCount: data['adSetCount'] ?? 0,
          adCount: (monthData['adCount'] as num?)?.toInt() ?? 0,
          firstAdDate: data['firstAdDate'] != null ? _parseDateField(data['firstAdDate']) : null,
          lastAdDate: data['lastAdDate'] != null ? _parseDateField(data['lastAdDate']) : null,
          lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        );

        campaignsWithMonthData.add(campaign);
      }

      // Sort by the requested field
      campaignsWithMonthData.sort((a, b) {
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
          case 'roi':
            aValue = a.roi;
            bValue = b.roi;
            break;
          default:
            aValue = a.totalProfit;
            bValue = b.totalProfit;
        }

        final comparison = (aValue as num).compareTo(bValue as num);
        return descending ? -comparison : comparison;
      });

      // Apply limit
      if (limit > 0 && campaignsWithMonthData.length > limit) {
        campaignsWithMonthData = campaignsWithMonthData.take(limit).toList();
      }

      return campaignsWithMonthData;
    } catch (e) {
      print('Error getting campaigns with month totals: $e');
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

  /// DEPRECATED: Use getCampaignsWithMonthTotals instead for month filtering
  /// Get campaigns with date-range-specific totals (not lifetime totals)
  /// This is the correct method to use when filtering by month
  @Deprecated('Use getCampaignsWithMonthTotals for better performance')
  Future<List<Campaign>> getCampaignsWithDateRangeTotals({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      // First, get campaigns that have activity in the date range
      final campaigns = await getCampaignsByDateRange(
        startDate: startDate,
        endDate: endDate,
        limit: limit * 2, // Fetch more to account for recalculation
        orderBy: 'lastUpdated', // Use a simple order first
        descending: true,
      );

      // Calculate date-range-specific totals for each campaign
      List<Campaign> campaignsWithTotals = [];
      
      for (var campaign in campaigns) {
        final totals = await calculateCampaignTotalsForDateRange(
          campaignId: campaign.campaignId,
          startDate: startDate,
          endDate: endDate,
        );


        // Calculate conversion rates
        final leadToBookingRate = totals['totalLeads'] > 0 
            ? (totals['totalBookings'] / totals['totalLeads']) * 100 
            : 0.0;
        final bookingToDepositRate = totals['totalBookings'] > 0 
            ? (totals['totalDeposits'] / totals['totalBookings']) * 100 
            : 0.0;
        final depositToCashRate = totals['totalDeposits'] > 0 
            ? (totals['totalCashCollected'] / totals['totalDeposits']) * 100 
            : 0.0;

        // Create a new campaign with updated totals
        final updatedCampaign = Campaign(
          campaignId: campaign.campaignId,
          campaignName: campaign.campaignName,
          status: campaign.status,
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
          roi: totals['roi'],
          leadToBookingRate: leadToBookingRate,
          bookingToDepositRate: bookingToDepositRate,
          depositToCashRate: depositToCashRate,
          adSetCount: campaign.adSetCount,
          adCount: totals['adsInRange'],
          firstAdDate: campaign.firstAdDate,
          lastAdDate: campaign.lastAdDate,
          lastUpdated: campaign.lastUpdated,
          createdAt: campaign.createdAt,
        );

        // Only include campaigns with spend in the date range
        if (totals['totalSpend'] > 0 || totals['totalLeads'] > 0) {
          campaignsWithTotals.add(updatedCampaign);
        }
      }

      // Sort by the requested field
      campaignsWithTotals.sort((a, b) {
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
          case 'roi':
            aValue = a.roi;
            bValue = b.roi;
            break;
          default:
            aValue = a.totalProfit;
            bValue = b.totalProfit;
        }
        
        final comparison = (aValue as num).compareTo(bValue as num);
        return descending ? -comparison : comparison;
      });

      // Apply limit
      if (limit > 0 && campaignsWithTotals.length > limit) {
        campaignsWithTotals = campaignsWithTotals.take(limit).toList();
      }

      return campaignsWithTotals;
    } catch (e) {
      print('Error getting campaigns with date range totals: $e');
      rethrow;
    }
  }
}
