import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/performance/ghl_opportunity.dart';

/// Service for managing GHL opportunity data from the split collections schema
class GHLOpportunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get all opportunities for an ad
  Future<List<GHLOpportunity>> getOpportunitiesForAd(
    String adId, {
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('ghlOpportunities')
          .where('adId', isEqualTo: adId)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => GHLOpportunity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting opportunities for ad: $e');
      rethrow;
    }
  }
  
  /// Get all opportunities for a campaign
  Future<List<GHLOpportunity>> getOpportunitiesForCampaign(
    String campaignId, {
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('ghlOpportunities')
          .where('campaignId', isEqualTo: campaignId)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => GHLOpportunity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting opportunities for campaign: $e');
      rethrow;
    }
  }
  
  /// Get opportunities by stage category
  Future<List<GHLOpportunity>> getOpportunitiesByStageCategory(
    String stageCategory, {
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('ghlOpportunities')
          .where('stageCategory', isEqualTo: stageCategory)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => GHLOpportunity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting opportunities by stage: $e');
      rethrow;
    }
  }
  
  /// Get a single opportunity by ID
  Future<GHLOpportunity?> getOpportunity(String opportunityId) async {
    try {
      final doc = await _firestore
          .collection('ghlOpportunities')
          .doc(opportunityId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return GHLOpportunity.fromFirestore(doc);
    } catch (e) {
      print('Error getting opportunity $opportunityId: $e');
      rethrow;
    }
  }
  
  /// Stream opportunities for an ad
  Stream<List<GHLOpportunity>> streamOpportunitiesForAd(
    String adId, {
    int limit = 100,
  }) {
    try {
      Query query = _firestore
          .collection('ghlOpportunities')
          .where('adId', isEqualTo: adId)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => GHLOpportunity.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming opportunities: $e');
      rethrow;
    }
  }
  
  /// Stream opportunities for a campaign
  Stream<List<GHLOpportunity>> streamOpportunitiesForCampaign(
    String campaignId, {
    int limit = 100,
  }) {
    try {
      Query query = _firestore
          .collection('ghlOpportunities')
          .where('campaignId', isEqualTo: campaignId)
          .orderBy('createdAt', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => GHLOpportunity.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming opportunities: $e');
      rethrow;
    }
  }
}

