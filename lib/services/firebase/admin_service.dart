import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../models/practitioner_application.dart';
import '../../models/admin/admin_user.dart';
import '../../models/admin/installer.dart';
import '../../models/admin/warehouse_user.dart';
import '../emailjs_service.dart';

/// Firebase service for admin operations
/// Handles fetching practitioner data, approvals, and analytics for admin users
class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _practitionerApplicationsCollection => 
      _firestore.collection('practitionerApplications');
  static CollectionReference get _usersCollection => 
      _firestore.collection('users');
  static CollectionReference get _patientsCollection => 
      _firestore.collection('patients');
  static CollectionReference get _sessionsCollection => 
      _firestore.collection('sessions');
  static CollectionReference get _adminUsersCollection => 
      _firestore.collection('adminUsers');

  // ============================================================================
  // REAL PRACTITIONERS FROM USERS COLLECTION (Mobile App Data)
  // ============================================================================

  /// Get all real practitioners from users collection (approved practitioners using the app)
  static Stream<List<Map<String, dynamic>>> getRealPractitionersStream() {
    return _usersCollection
        .where('role', isEqualTo: 'practitioner')
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('👥 ADMIN SERVICE: Found ${snapshot.docs.length} real practitioners from users collection');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['uid'] = doc.id; // User ID
        return data;
      }).toList();
    });
  }

  /// Get practitioner statistics from users collection
  static Future<Map<String, int>> getRealPractitionerStats() async {
    try {
      final practitionersSnapshot = await _usersCollection
          .where('role', isEqualTo: 'practitioner')
          .get();
      
      final approved = practitionersSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isApproved'] == true)
          .length;
      
      final pending = practitionersSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isApproved'] != true)
          .length;

      return {
        'total': practitionersSnapshot.docs.length,
        'approved': approved,
        'pending': pending,
        'rejected': 0, // Not tracked in users collection
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get real practitioner stats: $e');
      }
      return {
        'total': 0,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
      };
    }
  }

  /// Get real practitioners by country from users collection
  static Stream<List<Map<String, dynamic>>> getRealPractitionersByCountry(String country) {
    return _usersCollection
        .where('role', isEqualTo: 'practitioner')
        .where('country', isEqualTo: country)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('🌍 ADMIN SERVICE: Found ${snapshot.docs.length} real practitioners in $country');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Approve a real practitioner (update isApproved in users collection)
  static Future<void> approveRealPractitioner(String userId) async {
    try {
      // First, get practitioner details for email
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      
      // Update approval status
      await _usersCollection.doc(userId).update({
        'isApproved': true,
        'accountStatus': 'approved', // This is the field that login checks
        'approvalDate': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Approved practitioner $userId');
      }
      
      // Send approval email to practitioner
      // Do this asynchronously without blocking
      if (userData != null) {
        final practitionerName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        final practitionerEmail = userData['email'] as String?;
        
        if (practitionerEmail != null && practitionerEmail.isNotEmpty) {
          EmailJSService.sendPractitionerApprovalEmail(
            practitionerName: practitionerName.isNotEmpty ? practitionerName : 'Practitioner',
            practitionerEmail: practitionerEmail,
            approvalDate: DateFormat('MMMM d, yyyy').format(DateTime.now()),
          ).catchError((error) {
            if (kDebugMode) {
              print('⚠️ Failed to send approval email: $error');
            }
            // Don't throw - email failure shouldn't block approval
            return false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to approve practitioner: $e');
      }
      rethrow;
    }
  }

  /// Reject a real practitioner (update isApproved in users collection)
  static Future<void> rejectRealPractitioner(String userId, String reason) async {
    try {
      await _usersCollection.doc(userId).update({
        'isApproved': false,
        'accountStatus': 'rejected', // Update account status as well
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
        'rejectionReason': reason,
      });

      if (kDebugMode) {
        print('❌ ADMIN SERVICE: Rejected practitioner $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to reject practitioner: $e');
      }
      rethrow;
    }
  }

  // ============================================================================
  // PRACTITIONER APPLICATIONS (For New Applicants - may be empty)
  // ============================================================================

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

  /// Get analytics data for admin dashboard (uses REAL practitioners from users collection)
  static Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      // Use REAL practitioners from users collection (not applications)
      final practitionerStats = await getRealPractitionerStats();
      final totalPatients = await getTotalPatientsCount();
      final totalSessions = await getTotalSessionsCount();

      if (kDebugMode) {
        print('📊 ADMIN SERVICE: Analytics - Practitioners: ${practitionerStats['total']}, Patients: $totalPatients, Sessions: $totalSessions');
      }

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

  /// Get ALL patients stream for admin (not filtered by practitioner)
  static Stream<List<Map<String, dynamic>>> getAllPatientsStream() {
    return _patientsCollection
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('👥 ADMIN SERVICE: Found ${snapshot.docs.length} total patients');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get ALL sessions stream for admin (not filtered by practitioner)
  static Stream<List<Map<String, dynamic>>> getAllSessionsStream() {
    return _sessionsCollection
        .orderBy('date', descending: true)
        .limit(100) // Limit to recent 100 sessions for performance
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('📋 ADMIN SERVICE: Found ${snapshot.docs.length} total sessions');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get patients by country for admin
  static Stream<List<Map<String, dynamic>>> getPatientsByCountry(String country) {
    return _patientsCollection
        .where('country', isEqualTo: country)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('🌍 ADMIN SERVICE: Found ${snapshot.docs.length} patients in $country');
      }
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get sessions by country for admin
  static Future<int> getSessionsCountByCountry(String country) async {
    try {
      // Get all practitioners in the country first
      final practitionersSnapshot = await _practitionerApplicationsCollection
          .where('country', isEqualTo: country)
          .where('status', isEqualTo: 'approved')
          .get();
      
      final practitionerIds = practitionersSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['userId'] as String?;
          })
          .whereType<String>()
          .toList();
      
      if (practitionerIds.isEmpty) return 0;
      
      // Count sessions for these practitioners
      int totalSessions = 0;
      for (final practitionerId in practitionerIds) {
        final sessionsSnapshot = await _sessionsCollection
            .where('practitionerId', isEqualTo: practitionerId)
            .get();
        totalSessions += sessionsSnapshot.docs.length;
      }
      
      return totalSessions;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get sessions count by country: $e');
      }
      return 0;
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

  /// Get admin email by Firebase Auth userId (used e.g. for contract sent BCC).
  /// Returns null if no admin user document matches.
  static Future<String?> getAdminEmailByUserId(String userId) async {
    try {
      final querySnapshot = await _adminUsersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isEmpty) return null;
      final adminUser = AdminUser.fromFirestore(querySnapshot.docs.first);
      return adminUser.email;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE: getAdminEmailByUserId failed for $userId: $e');
      }
      return null;
    }
  }

  /// Create a new admin user (Super Admin only)
  static Future<String> createAdminUser({
    required String email,
    required String password,
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
        password: password,
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

  // ============================================================================
  // INSTALLER MANAGEMENT METHODS
  // ============================================================================

  /// Collection reference for installers
  static CollectionReference get _installersCollection =>
      _firestore.collection('installers');

  /// Get all installers (Super Admin only)
  static Stream<List<Installer>> getInstallersStream() {
    return _installersCollection.snapshots().map((snapshot) {
      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Found ${snapshot.docs.length} installers');
      }
      return snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
    });
  }

  /// Get installers by country
  static Stream<List<Installer>> getInstallersByCountryStream(String country) {
    return _installersCollection
        .where('country', isEqualTo: country)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print(
            '🌍 ADMIN SERVICE: Found ${snapshot.docs.length} installers in $country');
      }
      return snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
    });
  }

  /// Create a new installer (Super Admin only)
  static Future<String> createInstaller({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String country,
    String? countryName,
    required String serviceArea,
    required String createdBy,
    String? notes,
  }) async {
    try {
      // Create Firebase Auth user first
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Create installer document
      final installer = Installer(
        id: '', // Will be set by Firestore
        userId: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        address: address,
        city: city,
        province: province,
        postalCode: postalCode,
        country: country,
        countryName: countryName,
        serviceArea: serviceArea,
        status: InstallerStatus.active,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        notes: notes,
      );

      final docRef = await _installersCollection.add(installer.toFirestore());

      if (kDebugMode) {
        print(
            '✅ ADMIN SERVICE: Created installer: ${installer.fullName} (${installer.email})');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to create installer: $e');
      }
      rethrow;
    }
  }

  /// Update installer status
  static Future<void> updateInstallerStatus(
      String installerId, InstallerStatus status) async {
    try {
      await _installersCollection.doc(installerId).update({
        'status': status.value,
        'updatedAt': Timestamp.now(),
      });

      if (kDebugMode) {
        print(
            '✅ ADMIN SERVICE: Updated installer status: $installerId -> ${status.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update installer status: $e');
      }
      rethrow;
    }
  }

  /// Update installer details
  static Future<void> updateInstaller(
      String installerId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _installersCollection.doc(installerId).update(updates);

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Updated installer: $installerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update installer: $e');
      }
      rethrow;
    }
  }

  /// Delete installer (Super Admin only)
  static Future<void> deleteInstaller(String installerId, String userId) async {
    try {
      // Delete from Firestore
      await _installersCollection.doc(installerId).delete();

      // Note: Firebase Auth user deletion requires admin privileges
      // This would typically be done via Firebase Admin SDK on the backend

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Deleted installer: $installerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to delete installer: $e');
      }
      rethrow;
    }
  }

  /// Update installer last login
  static Future<void> updateInstallerLastLogin(String userId) async {
    try {
      final querySnapshot = await _installersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'lastLogin': Timestamp.now(),
        });

        if (kDebugMode) {
          print(
              '✅ ADMIN SERVICE: Updated last login for installer: $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update installer last login: $e');
      }
    }
  }

  /// Get installer by user ID
  static Future<Installer?> getInstallerByUserId(String userId) async {
    try {
      final querySnapshot = await _installersCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Installer.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get installer by userId: $e');
      }
      return null;
    }
  }

  // ============================================================================
  // WAREHOUSE USER MANAGEMENT METHODS
  // ============================================================================

  /// Get all warehouse users (Super Admin only)
  /// Queries users collection where role='warehouse'
  static Stream<List<WarehouseUser>> getWarehouseUsersStream() {
    return _usersCollection
        .where('role', isEqualTo: 'warehouse')
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Found ${snapshot.docs.length} warehouse users');
      }
      return snapshot.docs.map((doc) => WarehouseUser.fromFirestore(doc)).toList();
    });
  }

  /// Get warehouse users by country
  static Stream<List<WarehouseUser>> getWarehouseUsersByCountryStream(String country) {
    return _usersCollection
        .where('role', isEqualTo: 'warehouse')
        .where('country', isEqualTo: country)
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('🌍 ADMIN SERVICE: Found ${snapshot.docs.length} warehouse users in $country');
      }
      return snapshot.docs.map((doc) => WarehouseUser.fromFirestore(doc)).toList();
    });
  }

  /// Create a new warehouse user (Super Admin only)
  /// Creates Firebase Auth user and stores profile in users collection with role='warehouse'
  static Future<String> createWarehouseUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String country,
    String? countryName,
    required String createdBy,
    String? notes,
  }) async {
    try {
      // Create Firebase Auth user first
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userId = userCredential.user!.uid;

      // Create warehouse user document in users collection
      final warehouseUser = WarehouseUser(
        id: userId, // Use auth UID as document ID
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        address: address,
        city: city,
        province: province,
        postalCode: postalCode,
        country: country,
        countryName: countryName,
        status: WarehouseUserStatus.active,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        notes: notes,
      );

      // Store in users collection with the auth UID as document ID
      await _usersCollection.doc(userId).set(warehouseUser.toFirestore());

      if (kDebugMode) {
        print(
            '✅ ADMIN SERVICE: Created warehouse user: ${warehouseUser.fullName} (${warehouseUser.email})');
      }

      return userId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to create warehouse user: $e');
      }
      rethrow;
    }
  }

  /// Update warehouse user status
  static Future<void> updateWarehouseUserStatus(
      String userId, WarehouseUserStatus status) async {
    try {
      // Convert status to accountStatus for users collection
      String accountStatus;
      switch (status) {
        case WarehouseUserStatus.active:
          accountStatus = 'approved';
        case WarehouseUserStatus.suspended:
          accountStatus = 'suspended';
        case WarehouseUserStatus.inactive:
          accountStatus = 'pending';
      }

      await _usersCollection.doc(userId).update({
        'accountStatus': accountStatus,
        'updatedAt': Timestamp.now(),
      });

      if (kDebugMode) {
        print(
            '✅ ADMIN SERVICE: Updated warehouse user status: $userId -> ${status.value}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update warehouse user status: $e');
      }
      rethrow;
    }
  }

  /// Update warehouse user details
  static Future<void> updateWarehouseUser(
      String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _usersCollection.doc(userId).update(updates);

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Updated warehouse user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update warehouse user: $e');
      }
      rethrow;
    }
  }

  /// Delete warehouse user (Super Admin only)
  static Future<void> deleteWarehouseUser(String userId) async {
    try {
      // Delete from Firestore users collection
      await _usersCollection.doc(userId).delete();

      // Note: Firebase Auth user deletion requires admin privileges
      // This would typically be done via Firebase Admin SDK on the backend

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Deleted warehouse user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to delete warehouse user: $e');
      }
      rethrow;
    }
  }

  /// Update warehouse user last login
  static Future<void> updateWarehouseUserLastLogin(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastLogin': Timestamp.now(),
      });

      if (kDebugMode) {
        print('✅ ADMIN SERVICE: Updated last login for warehouse user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to update warehouse user last login: $e');
      }
    }
  }

  /// Get warehouse user by user ID
  static Future<WarehouseUser?> getWarehouseUserByUserId(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] == 'warehouse') {
          return WarehouseUser.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ADMIN SERVICE ERROR: Failed to get warehouse user by userId: $e');
      }
      return null;
    }
  }
}
