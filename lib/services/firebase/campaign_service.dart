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
}
