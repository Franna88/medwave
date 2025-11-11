import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/performance/ad.dart';

/// Service for managing ad data from the split collections schema
class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      
      return snapshot.docs
          .map((doc) => Ad.fromFirestore(doc))
          .toList();
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
      
      return snapshot.docs
          .map((doc) => Ad.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting ads for campaign: $e');
      rethrow;
    }
  }
  
  /// Get a single ad by ID
  Future<Ad?> getAd(String adId) async {
    try {
      final doc = await _firestore
          .collection('ads')
          .doc(adId)
          .get();
      
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
        return snapshot.docs
            .map((doc) => Ad.fromFirestore(doc))
            .toList();
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
        return snapshot.docs
            .map((doc) => Ad.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error streaming ads: $e');
      rethrow;
    }
  }
  
  /// Stream a single ad
  Stream<Ad?> streamAd(String adId) {
    try {
      return _firestore
          .collection('ads')
          .doc(adId)
          .snapshots()
          .map((doc) {
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
}

