import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/practitioner_application.dart';
import '../models/country_analytics.dart';
import '../models/user_profile.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<PractitionerApplication> _pendingApplications = [];
  List<PractitionerApplication> _allApplications = [];
  Map<String, CountryAnalytics> _countryAnalytics = {};
  List<UserProfile> _practitioners = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<PractitionerApplication> get pendingApplications => List.unmodifiable(_pendingApplications);
  List<PractitionerApplication> get allApplications => List.unmodifiable(_allApplications);
  Map<String, CountryAnalytics> get countryAnalytics => Map.unmodifiable(_countryAnalytics);
  List<UserProfile> get practitioners => List.unmodifiable(_practitioners);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Filtered getters
  List<PractitionerApplication> get approvedApplications => 
      _allApplications.where((app) => app.isApproved).toList();
      
  List<PractitionerApplication> get rejectedApplications => 
      _allApplications.where((app) => app.isRejected).toList();
      
  List<PractitionerApplication> get underReviewApplications => 
      _allApplications.where((app) => app.isUnderReview).toList();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Load pending practitioner applications
  Future<void> loadPendingApplications() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final snapshot = await _firestore
        .collection('practitionerApplications')
        .where('status', 'in', ['pending', 'under_review'])
        .orderBy('submittedAt', descending: true)
        .get();
      
      _pendingApplications = snapshot.docs
        .map((doc) => PractitionerApplication.fromFirestore(doc))
        .toList();
        
      notifyListeners();
    } catch (e) {
      _setError('Failed to load pending applications: $e');
      debugPrint('Error loading pending applications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load all practitioner applications with pagination
  Future<void> loadAllApplications({DocumentSnapshot? startAfter, int limit = 20}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      Query query = _firestore
        .collection('practitionerApplications')
        .orderBy('submittedAt', descending: true)
        .limit(limit);
        
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final snapshot = await query.get();
      
      final applications = snapshot.docs
        .map((doc) => PractitionerApplication.fromFirestore(doc))
        .toList();
        
      if (startAfter == null) {
        _allApplications = applications;
      } else {
        _allApplications.addAll(applications);
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load applications: $e');
      debugPrint('Error loading applications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load country analytics data
  Future<void> loadCountryAnalytics() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final snapshot = await _firestore
        .collection('countryAnalytics')
        .orderBy('totalPractitioners', descending: true)
        .get();
      
      _countryAnalytics.clear();
      for (final doc in snapshot.docs) {
        final analytics = CountryAnalytics.fromFirestore(doc);
        _countryAnalytics[analytics.countryCode] = analytics;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load country analytics: $e');
      debugPrint('Error loading country analytics: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load all practitioners
  Future<void> loadPractitioners({String? country}) async {
    _setLoading(true);
    _setError(null);
    
    try {
      Query query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'practitioner')
        .orderBy('createdAt', descending: true);
        
      if (country != null && country.isNotEmpty) {
        query = query.where('country', isEqualTo: country);
      }
      
      final snapshot = await query.get();
      
      _practitioners = snapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .toList();
        
      notifyListeners();
    } catch (e) {
      _setError('Failed to load practitioners: $e');
      debugPrint('Error loading practitioners: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Review (approve/reject) a practitioner application
  Future<bool> reviewApplication(
    String applicationId, 
    bool approved, {
    String? rejectionReason,
    String? reviewNotes,
  }) async {
    _setLoading(true);
    _setError(null);
    
    try {
      // Note: In a real implementation, this would call a Cloud Function
      // For now, we'll implement it directly in the client
      
      final batch = _firestore.batch();
      
      // Update application status
      final appRef = _firestore.collection('practitionerApplications').doc(applicationId);
      batch.update(appRef, {
        'status': approved ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _auth.currentUser?.uid,
        'reviewNotes': reviewNotes,
        'rejectionReason': approved ? null : rejectionReason,
      });
      
      // Get application data to update user profile
      final appDoc = await appRef.get();
      if (appDoc.exists) {
        final appData = appDoc.data() as Map<String, dynamic>;
        final userId = appData['userId'] as String;
        
        // Update user account status
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'accountStatus': approved ? 'approved' : 'rejected',
          'approvalDate': approved ? FieldValue.serverTimestamp() : null,
          'approvedBy': approved ? _auth.currentUser?.uid : null,
          'rejectionReason': approved ? null : rejectionReason,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      // Refresh applications list
      await loadPendingApplications();
      
      return true;
    } catch (e) {
      _setError('Failed to review application: $e');
      debugPrint('Error reviewing application: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update application verification status
  Future<bool> updateVerificationStatus(
    String applicationId, {
    bool? documentsVerified,
    bool? licenseVerified,
    bool? referencesVerified,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (documentsVerified != null) {
        updateData['documentsVerified'] = documentsVerified;
      }
      if (licenseVerified != null) {
        updateData['licenseVerified'] = licenseVerified;
      }
      if (referencesVerified != null) {
        updateData['referencesVerified'] = referencesVerified;
      }
      
      if (updateData.isNotEmpty) {
        await _firestore
          .collection('practitionerApplications')
          .doc(applicationId)
          .update(updateData);
          
        // Refresh applications
        await loadPendingApplications();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update verification status: $e');
      debugPrint('Error updating verification status: $e');
      return false;
    }
  }

  /// Suspend or reactivate a practitioner
  Future<bool> updatePractitionerStatus(String userId, String status) async {
    _setLoading(true);
    _setError(null);
    
    try {
      await _firestore.collection('users').doc(userId).update({
        'accountStatus': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Refresh practitioners list
      await loadPractitioners();
      
      return true;
    } catch (e) {
      _setError('Failed to update practitioner status: $e');
      debugPrint('Error updating practitioner status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get applications by country
  List<PractitionerApplication> getApplicationsByCountry(String country) {
    return _allApplications.where((app) => app.country == country).toList();
  }

  /// Get applications by status
  List<PractitionerApplication> getApplicationsByStatus(ApplicationStatus status) {
    return _allApplications.where((app) => app.status == status).toList();
  }

  /// Search applications by name or email
  List<PractitionerApplication> searchApplications(String query) {
    if (query.isEmpty) return _allApplications;
    
    final lowercaseQuery = query.toLowerCase();
    return _allApplications.where((app) {
      return app.firstName.toLowerCase().contains(lowercaseQuery) ||
             app.lastName.toLowerCase().contains(lowercaseQuery) ||
             app.email.toLowerCase().contains(lowercaseQuery) ||
             app.licenseNumber.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Get summary statistics
  Map<String, int> getSummaryStats() {
    return {
      'total': _allApplications.length,
      'pending': _pendingApplications.length,
      'approved': approvedApplications.length,
      'rejected': rejectedApplications.length,
      'underReview': underReviewApplications.length,
    };
  }

  /// Clear all data
  void clearData() {
    _pendingApplications.clear();
    _allApplications.clear();
    _countryAnalytics.clear();
    _practitioners.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
