import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/practitioner_application.dart';

class PractitionerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _practitionerApplicationsCollection => 
      _firestore.collection('practitionerApplications');

  /// Get the current practitioner's application details
  static Future<PractitionerApplication?> getCurrentPractitionerDetails() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ PRACTITIONER SERVICE: User not authenticated');
        return null;
      }

      print('🏥 PRACTITIONER SERVICE: Fetching details for user: $userId');

      // Query for approved practitioner application for current user
      final querySnapshot = await _practitionerApplicationsCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ PRACTITIONER SERVICE: No approved application found for user: $userId');
        return null;
      }

      final practitionerApp = PractitionerApplication.fromFirestore(querySnapshot.docs.first);
      print('✅ PRACTITIONER SERVICE: Found practitioner: ${practitionerApp.firstName} ${practitionerApp.lastName}');
      
      return practitionerApp;
    } catch (e) {
      print('❌ PRACTITIONER SERVICE ERROR: Failed to get practitioner details: $e');
      return null;
    }
  }

  /// Get formatted practitioner name
  static Future<String> getPractitionerName() async {
    final practitioner = await getCurrentPractitionerDetails();
    if (practitioner == null) return '';
    
    return '${practitioner.firstName} ${practitioner.lastName}';
  }

  /// Get practitioner license/practice number
  static Future<String> getPractitionerLicenseNumber() async {
    final practitioner = await getCurrentPractitionerDetails();
    if (practitioner == null) return '';
    
    return practitioner.licenseNumber;
  }

  /// Get formatted practitioner contact details
  static Future<String> getPractitionerContactDetails() async {
    final practitioner = await getCurrentPractitionerDetails();
    if (practitioner == null) return '';
    
    // Format: "License: 123456, Location: Cape Town, Specialization: Wound Care"
    final contactParts = <String>[];
    
    if (practitioner.licenseNumber.isNotEmpty) {
      contactParts.add('License: ${practitioner.licenseNumber}');
    }
    
    if (practitioner.practiceLocation.isNotEmpty) {
      contactParts.add('Location: ${practitioner.practiceLocation}');
    }
    
    if (practitioner.specialization.isNotEmpty) {
      contactParts.add('Specialization: ${practitioner.specialization}');
    }
    
    if (practitioner.city.isNotEmpty && practitioner.province.isNotEmpty) {
      contactParts.add('Address: ${practitioner.city}, ${practitioner.province}');
    }
    
    return contactParts.join(', ');
  }

  /// Get comprehensive practitioner info for reports
  static Future<Map<String, String?>> getPractitionerInfo() async {
    final practitioner = await getCurrentPractitionerDetails();
    
    if (practitioner == null) {
      return {
        'name': null,
        'licenseNumber': null,
        'contactDetails': null,
        'specialization': null,
        'practiceLocation': null,
      };
    }
    
    return {
      'name': '${practitioner.firstName} ${practitioner.lastName}',
      'licenseNumber': practitioner.licenseNumber.isNotEmpty ? practitioner.licenseNumber : null,
      'contactDetails': await getPractitionerContactDetails(),
      'specialization': practitioner.specialization.isNotEmpty ? practitioner.specialization : null,
      'practiceLocation': practitioner.practiceLocation.isNotEmpty ? practitioner.practiceLocation : null,
    };
  }
}
