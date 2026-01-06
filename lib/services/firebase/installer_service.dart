import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/admin/installer.dart';

/// Service for managing installers in Firebase
class InstallerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'installers';

  /// Get all installers
  Future<List<Installer>> getAllInstallers({
    String? orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all installers: $e');
      }
      rethrow;
    }
  }

  /// Get active installers only
  Future<List<Installer>> getActiveInstallers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'active')
          .get();

      final installers =
          snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
      // Sort in memory to avoid index requirement
      installers.sort((a, b) => a.fullName.compareTo(b.fullName));
      return installers;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting active installers: $e');
      }
      rethrow;
    }
  }

  /// Get a single installer by ID
  Future<Installer?> getInstaller(String installerId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(installerId).get();

      if (!doc.exists) {
        return null;
      }

      return Installer.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting installer $installerId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all installers
  Stream<List<Installer>> installersStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final installers =
          snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
      // Sort in memory instead of using orderBy to avoid index requirement
      installers.sort((a, b) => a.fullName.compareTo(b.fullName));
      return installers;
    });
  }

  /// Stream of active installers only
  Stream<List<Installer>> activeInstallersStream() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final installers =
          snapshot.docs.map((doc) => Installer.fromFirestore(doc)).toList();
      installers.sort((a, b) => a.fullName.compareTo(b.fullName));
      return installers;
    });
  }

  /// Create a new installer
  Future<String> createInstaller(Installer installer) async {
    try {
      final docRef =
          await _firestore.collection(_collection).add(installer.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating installer: $e');
      }
      rethrow;
    }
  }

  /// Update an existing installer
  Future<void> updateInstaller(Installer installer) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(installer.id)
          .update(installer.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating installer: $e');
      }
      rethrow;
    }
  }

  /// Delete an installer
  Future<void> deleteInstaller(String installerId) async {
    try {
      await _firestore.collection(_collection).doc(installerId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting installer: $e');
      }
      rethrow;
    }
  }

  /// Update installer status
  Future<void> updateInstallerStatus(
    String installerId,
    InstallerStatus status,
  ) async {
    try {
      await _firestore.collection(_collection).doc(installerId).update({
        'status': status.value,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating installer status: $e');
      }
      rethrow;
    }
  }

  /// Search installers by name, email, or service area
  Future<List<Installer>> searchInstallers(String query) async {
    try {
      final allInstallers = await getAllInstallers();

      final lowerQuery = query.toLowerCase();
      return allInstallers.where((installer) {
        return installer.fullName.toLowerCase().contains(lowerQuery) ||
            installer.email.toLowerCase().contains(lowerQuery) ||
            installer.serviceArea.toLowerCase().contains(lowerQuery) ||
            installer.city.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching installers: $e');
      }
      rethrow;
    }
  }

  /// Get installers by service area
  Future<List<Installer>> getInstallersByServiceArea(String area) async {
    try {
      final allInstallers = await getActiveInstallers();

      final lowerArea = area.toLowerCase();
      return allInstallers.where((installer) {
        return installer.serviceArea.toLowerCase().contains(lowerArea) ||
            installer.city.toLowerCase().contains(lowerArea);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting installers by service area: $e');
      }
      rethrow;
    }
  }
}

