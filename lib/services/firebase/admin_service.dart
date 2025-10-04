import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/practitioner_application.dart';
import '../../models/admin/admin_user.dart';

/// Firebase service for admin operations
/// Handles fetching practitioner data, approvals, and analytics for admin users
class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _practitionerApplicationsCollection => 
      _firestore.collection('practitionerApplications');
  static CollectionReference get _patientsCollection => 
      _firestore.collection('patients');
  static CollectionReference get _sessionsCollection => 
      _firestore.collection('sessions');
  static CollectionReference get _adminUsersCollection => 
      _firestore.collection('adminUsers');

  /// Get all practitioner applications (for admin use)
  static Stream<List<PractitionerApplication>> getAllPractitionersStream() {
    return _practitionerApplicationsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('🏥 ADMIN SERVICE: Found ${snapshot.docs.length} practitioner applications');
      }
      return snapshot.docs.map((doc) => PractitionerApplication.fromFirestore(doc)).toList();
    });
  }

  /// Get approved practitioners only
  static Stream<List<PractitionerApplication>> getApprovedPractitionersStream() {
    return _practitionerApplicationsCollection
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Found ${snapshot.docs.length} approved practitioners');
      }
      return snapshot.docs.map((doc) => PractitionerApplication.fromFirestore(doc)).toList();
    });
  }

  /// Get pending practitioner applications
  static Stream<List<PractitionerApplication>> getPendingPractitionersStream() {
    return _practitionerApplicationsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('⏳ ADMIN SERVICE: Found ${snapshot.docs.length} pending practitioner applications');
      }
      return snapshot.docs.map((doc) => PractitionerApplication.fromFirestore(doc)).toList();
    });
  }

  /// Get practitioners by country
  static Stream<List<PractitionerApplication>> getPractitionersByCountryStream(String country) {
    return _practitionerApplicationsCollection
        .where('country', isEqualTo: country)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('🌍 ADMIN SERVICE: Found ${snapshot.docs.length} practitioners in $country');
      }
      return snapshot.docs.map((doc) => PractitionerApplication.fromFirestore(doc)).toList();
    });
  }

  /// Approve a practitioner application
  static Future<void> approvePractitioner(String applicationId, String reason) async {
    try {
      await _practitionerApplicationsCollection.doc(applicationId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
        'approvalReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Approved practitioner application $applicationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to approve practitioner: $e');
      }
      rethrow;
    }
  }

  /// Reject a practitioner application
  static Future<void> rejectPractitioner(String applicationId, String reason) async {
    try {
      await _practitionerApplicationsCollection.doc(applicationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('❌ ADMIN SERVICE: Rejected practitioner application $applicationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to reject practitioner: $e');
      }
      rethrow;
    }
  }

  /// Get practitioner statistics
  static Future<Map<String, int>> getPractitionerStats() async {
    try {
      final allSnapshot = await _practitionerApplicationsCollection.get();
      final approvedSnapshot = await _practitionerApplicationsCollection
          .where('status', isEqualTo: 'approved')
          .get();
      final pendingSnapshot = await _practitionerApplicationsCollection
          .where('status', isEqualTo: 'pending')
          .get();

      return {
        'total': allSnapshot.docs.length,
        'approved': approvedSnapshot.docs.length,
        'pending': pendingSnapshot.docs.length,
        'rejected': allSnapshot.docs.length - approvedSnapshot.docs.length - pendingSnapshot.docs.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get practitioner stats: $e');
      }
      return {
        'total': 0,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
      };
    }
  }

  /// Get total patients across all practitioners
  static Future<int> getTotalPatientsCount() async {
    try {
      final snapshot = await _patientsCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get total patients count: $e');
      }
      return 0;
    }
  }

  /// Get total sessions across all practitioners
  static Future<int> getTotalSessionsCount() async {
    try {
      final snapshot = await _sessionsCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get total sessions count: $e');
      }
      return 0;
    }
  }

  /// Get analytics data for admin dashboard
  static Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final practitionerStats = await getPractitionerStats();
      final totalPatients = await getTotalPatientsCount();
      final totalSessions = await getTotalSessionsCount();

      return {
        'practitioners': practitionerStats,
        'totalPatients': totalPatients,
        'totalSessions': totalSessions,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get admin analytics: $e');
      }
      return {
        'practitioners': {'total': 0, 'approved': 0, 'pending': 0, 'rejected': 0},
        'totalPatients': 0,
        'totalSessions': 0,
        'lastUpdated': DateTime.now(),
      };
    }
  }

  // ============================================================================
  // ADMIN USER MANAGEMENT METHODS
  // ============================================================================

  /// Get all admin users (Super Admin only)
  static Stream<List<AdminUser>> getAdminUsersStream() {
    return _adminUsersCollection
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Found ${snapshot.docs.length} admin users');
      }
      return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
    });
  }

  /// Create a new admin user (Super Admin only)
  static Future<String> createAdminUser({
    required String email,
    required String firstName,
    required String lastName,
    required AdminRole role,
    required String country,
    String? countryName,
    required String createdBy,
    String? notes,
  }) async {
    try {
      // Create Firebase Auth user first
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _generateTemporaryPassword(), // Generate a temporary password
      );

      final String userId = userCredential.user!.uid;

      // Create admin user document
      final adminUser = AdminUser(
        id: '', // Will be set by Firestore
        userId: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
        status: AdminUserStatus.active,
        country: country,
        countryName: countryName,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        notes: notes,
      );

      final docRef = await _adminUsersCollection.add(adminUser.toFirestore());

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Created admin user: ${adminUser.fullName} (${adminUser.email})');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to create admin user: $e');
      }
      rethrow;
    }
  }

  /// Update admin user status
  static Future<void> updateAdminUserStatus(String adminUserId, AdminUserStatus status) async {
    try {
      await _adminUsersCollection.doc(adminUserId).update({
        'status': status.value,
        'updatedAt': Timestamp.now(),
      });

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Updated admin user status: $adminUserId -> ${status.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update admin user status: $e');
      }
      rethrow;
    }
  }

  /// Update admin user details
  static Future<void> updateAdminUser(String adminUserId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _adminUsersCollection.doc(adminUserId).update(updates);

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Updated admin user: $adminUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update admin user: $e');
      }
      rethrow;
    }
  }

  /// Delete admin user (Super Admin only)
  static Future<void> deleteAdminUser(String adminUserId, String userId) async {
    try {
      // Delete from Firestore
      await _adminUsersCollection.doc(adminUserId).delete();

      // Note: Firebase Auth user deletion requires admin privileges
      // This would typically be done via Firebase Admin SDK on the backend
      
      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Deleted admin user: $adminUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to delete admin user: $e');
      }
      rethrow;
    }
  }

  /// Update admin user last login
  static Future<void> updateAdminUserLastLogin(String userId) async {
    try {
      final querySnapshot = await _adminUsersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'lastLogin': Timestamp.now(),
        });

        if (kDebugMode) {
          print('✅ ADMIN SERVICE: Updated last login for user: $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update last login: $e');
      }
    }
  }

  /// Generate a temporary password for new admin users
  static String _generateTemporaryPassword() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'TempPass${random.toString().substring(7)}!';
  }
}
