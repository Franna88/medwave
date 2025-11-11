import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/performance/campaign_metrics_snapshot.dart';

/// Service for managing campaign metrics history for time-series comparisons
class MetricsHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get weekly snapshot for a campaign
  Future<CampaignMetricsSnapshot?> getWeeklySnapshot(
    String campaignId,
    int year,
    int month,
    int week,
  ) async {
    try {
      final docId = '${campaignId}__$year-${month.toString().padLeft(2, '0')}-${week.toString().padLeft(2, '0')}';
      
      final doc = await _firestore
          .collection('campaignMetricsHistory')
          .doc(docId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return CampaignMetricsSnapshot.fromFirestore(doc);
    } catch (e) {
      print('Error getting weekly snapshot: $e');
      rethrow;
    }
  }
  
  /// Get monthly snapshot for a campaign
  Future<CampaignMetricsSnapshot?> getMonthlySnapshot(
    String campaignId,
    int year,
    int month,
  ) async {
    try {
      final docId = '${campaignId}__$year-${month.toString().padLeft(2, '0')}-00';
      
      final doc = await _firestore
          .collection('campaignMetricsHistory')
          .doc(docId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return CampaignMetricsSnapshot.fromFirestore(doc);
    } catch (e) {
      print('Error getting monthly snapshot: $e');
      rethrow;
    }
  }
  
  /// Get all snapshots for a campaign
  Future<List<CampaignMetricsSnapshot>> getSnapshotsForCampaign(
    String campaignId, {
    int limit = 52, // Default to 1 year of weekly data
  }) async {
    try {
      Query query = _firestore
          .collection('campaignMetricsHistory')
          .where('campaignId', isEqualTo: campaignId)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => CampaignMetricsSnapshot.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting snapshots for campaign: $e');
      rethrow;
    }
  }
  
  /// Get week-over-week comparison
  Future<Map<String, dynamic>?> getWeeklyComparison(
    String campaignId,
    int thisYear,
    int thisMonth,
    int thisWeek,
    int lastYear,
    int lastMonth,
    int lastWeek,
  ) async {
    try {
      final thisWeekSnapshot = await getWeeklySnapshot(
        campaignId,
        thisYear,
        thisMonth,
        thisWeek,
      );
      
      final lastWeekSnapshot = await getWeeklySnapshot(
        campaignId,
        lastYear,
        lastMonth,
        lastWeek,
      );
      
      if (thisWeekSnapshot == null || lastWeekSnapshot == null) {
        return null;
      }
      
      // Calculate changes
      final changes = {
        'spend': thisWeekSnapshot.totalSpend - lastWeekSnapshot.totalSpend,
        'leads': thisWeekSnapshot.totalLeads - lastWeekSnapshot.totalLeads,
        'bookings': thisWeekSnapshot.totalBookings - lastWeekSnapshot.totalBookings,
        'deposits': thisWeekSnapshot.totalDeposits - lastWeekSnapshot.totalDeposits,
        'cash': thisWeekSnapshot.totalCashAmount - lastWeekSnapshot.totalCashAmount,
        'profit': thisWeekSnapshot.totalProfit - lastWeekSnapshot.totalProfit,
      };
      
      // Calculate percentage changes
      final percentChanges = {
        'spend': lastWeekSnapshot.totalSpend > 0
            ? (changes['spend']! / lastWeekSnapshot.totalSpend) * 100
            : 0.0,
        'leads': lastWeekSnapshot.totalLeads > 0
            ? (changes['leads']! / lastWeekSnapshot.totalLeads) * 100
            : 0.0,
        'bookings': lastWeekSnapshot.totalBookings > 0
            ? (changes['bookings']! / lastWeekSnapshot.totalBookings) * 100
            : 0.0,
        'deposits': lastWeekSnapshot.totalDeposits > 0
            ? (changes['deposits']! / lastWeekSnapshot.totalDeposits) * 100
            : 0.0,
        'cash': lastWeekSnapshot.totalCashAmount > 0
            ? (changes['cash']! / lastWeekSnapshot.totalCashAmount) * 100
            : 0.0,
        'profit': lastWeekSnapshot.totalProfit > 0
            ? (changes['profit']! / lastWeekSnapshot.totalProfit) * 100
            : 0.0,
      };
      
      return {
        'thisWeek': thisWeekSnapshot,
        'lastWeek': lastWeekSnapshot,
        'changes': changes,
        'percentChanges': percentChanges,
      };
    } catch (e) {
      print('Error getting weekly comparison: $e');
      rethrow;
    }
  }
  
  /// Get month-over-month comparison
  Future<Map<String, dynamic>?> getMonthlyComparison(
    String campaignId,
    int thisYear,
    int thisMonth,
    int lastYear,
    int lastMonth,
  ) async {
    try {
      final thisMonthSnapshot = await getMonthlySnapshot(
        campaignId,
        thisYear,
        thisMonth,
      );
      
      final lastMonthSnapshot = await getMonthlySnapshot(
        campaignId,
        lastYear,
        lastMonth,
      );
      
      if (thisMonthSnapshot == null || lastMonthSnapshot == null) {
        return null;
      }
      
      // Calculate changes
      final changes = {
        'spend': thisMonthSnapshot.totalSpend - lastMonthSnapshot.totalSpend,
        'leads': thisMonthSnapshot.totalLeads - lastMonthSnapshot.totalLeads,
        'bookings': thisMonthSnapshot.totalBookings - lastMonthSnapshot.totalBookings,
        'deposits': thisMonthSnapshot.totalDeposits - lastMonthSnapshot.totalDeposits,
        'cash': thisMonthSnapshot.totalCashAmount - lastMonthSnapshot.totalCashAmount,
        'profit': thisMonthSnapshot.totalProfit - lastMonthSnapshot.totalProfit,
      };
      
      // Calculate percentage changes
      final percentChanges = {
        'spend': lastMonthSnapshot.totalSpend > 0
            ? (changes['spend']! / lastMonthSnapshot.totalSpend) * 100
            : 0.0,
        'leads': lastMonthSnapshot.totalLeads > 0
            ? (changes['leads']! / lastMonthSnapshot.totalLeads) * 100
            : 0.0,
        'bookings': lastMonthSnapshot.totalBookings > 0
            ? (changes['bookings']! / lastMonthSnapshot.totalBookings) * 100
            : 0.0,
        'deposits': lastMonthSnapshot.totalDeposits > 0
            ? (changes['deposits']! / lastMonthSnapshot.totalDeposits) * 100
            : 0.0,
        'cash': lastMonthSnapshot.totalCashAmount > 0
            ? (changes['cash']! / lastMonthSnapshot.totalCashAmount) * 100
            : 0.0,
        'profit': lastMonthSnapshot.totalProfit > 0
            ? (changes['profit']! / lastMonthSnapshot.totalProfit) * 100
            : 0.0,
      };
      
      return {
        'thisMonth': thisMonthSnapshot,
        'lastMonth': lastMonthSnapshot,
        'changes': changes,
        'percentChanges': percentChanges,
      };
    } catch (e) {
      print('Error getting monthly comparison: $e');
      rethrow;
    }
  }
}

