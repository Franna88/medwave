import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing iOS TestFlight download requests
class TestFlightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Submit a new TestFlight access request
  /// 
  /// This stores the user's information in Firestore for manual processing
  /// by administrators who will then invite them to TestFlight
  Future<void> submitTestFlightRequest({
    required String firstName,
    required String lastName,
    required String contactNumber,
    required String email,
  }) async {
    try {
      await _firestore.collection('testflight_requests').add({
        'firstName': firstName,
        'lastName': lastName,
        'contactNumber': contactNumber,
        'email': email,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to submit TestFlight request: $e');
    }
  }
  
  /// Check if a TestFlight request already exists for an email
  /// 
  /// Returns the request status if found, null otherwise
  Future<Map<String, dynamic>?> checkRequestStatus(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('testflight_requests')
          .where('email', isEqualTo: email)
          .orderBy('requestedAt', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = querySnapshot.docs.first;
      return {
        'id': doc.id,
        ...doc.data(),
      };
    } catch (e) {
      throw Exception('Failed to check request status: $e');
    }
  }
}

