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
      
      return snapshot.docs
          .map((doc) => AdSet.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting ad sets for campaign: $e');
      rethrow;
    }
  }
  
  /// Get a single ad set by ID
  Future<AdSet?> getAdSet(String adSetId) async {
    try {
      final doc = await _firestore
          .collection('adSets')
          .doc(adSetId)
          .get();
      
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
        return snapshot.docs
            .map((doc) => AdSet.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming ad sets: $e');
      rethrow;
    }
  }
  
  /// Stream a single ad set
  Stream<AdSet?> streamAdSet(String adSetId) {
    try {
      return _firestore
          .collection('adSets')
          .doc(adSetId)
          .snapshots()
          .map((doc) {
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
}

