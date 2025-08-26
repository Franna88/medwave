import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../models/patient.dart';

class PatientService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _patientsCollection => _firestore.collection('patients');
  
  /// Get patients for the current authenticated practitioner
  static Stream<List<Patient>> getPatientsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    debugPrint('PatientService: Querying patients for practitioner $userId');
    return _patientsCollection
        .where('practitionerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      debugPrint('Found ${snapshot.docs.length} patients for practitioner $userId');
      if (snapshot.docs.isEmpty) {
        debugPrint('No patients found. Checking all patients...');
        // Let's query all patients to see what's there
        _patientsCollection.limit(5).get().then((allSnapshot) {
          debugPrint('Total patients in database (sample): ${allSnapshot.docs.length}');
          for (final doc in allSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('Patient ${doc.id}: practitionerId=${data['practitionerId']}, surname=${data['surname']}');
          }
        });
      }
      return snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
    });
  }

  /// Get a specific patient by ID
  static Future<Patient?> getPatient(String patientId) async {
    try {
      final doc = await _patientsCollection.doc(patientId).get();
      if (doc.exists) {
        return Patient.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get patient: $e');
    }
  }

  /// Create a new patient
  static Future<String> createPatient(Patient patient) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get practitioner info for location inheritance
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      // Create patient with inherited location data
      final patientData = patient.copyWith(
        practitionerId: userId,
        country: userData['country'],
        countryName: userData['countryName'],
        province: userData['province'],
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final docRef = await _patientsCollection.add(patientData.toFirestore());
      
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create patient: $e');
    }
  }

  /// Update an existing patient
  static Future<void> updatePatient(String patientId, Patient patient) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the patient belongs to the current practitioner
      final existingDoc = await _patientsCollection.doc(patientId).get();
      if (!existingDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final existingData = existingDoc.data() as Map<String, dynamic>;
      if (existingData['practitionerId'] != userId) {
        throw Exception('Access denied: Patient belongs to another practitioner');
      }

      final updatedPatient = patient.copyWith(
        lastUpdated: DateTime.now(),
      );

      await _patientsCollection.doc(patientId).update(updatedPatient.toFirestore());
    } catch (e) {
      throw Exception('Failed to update patient: $e');
    }
  }

  /// Delete a patient (only if no sessions exist)
  static Future<void> deletePatient(String patientId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the patient belongs to the current practitioner
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      if (patientData['practitionerId'] != userId) {
        throw Exception('Access denied: Patient belongs to another practitioner');
      }

      // Check if patient has sessions
      final sessionsSnapshot = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .limit(1)
          .get();

      if (sessionsSnapshot.docs.isNotEmpty) {
        throw Exception('Cannot delete patient with existing sessions');
      }

      // Delete patient photos from storage
      final photos = List<String>.from(patientData['baselinePhotos'] ?? []);
      await _deletePhotos(photos);

      // Delete patient document
      await _patientsCollection.doc(patientId).delete();
    } catch (e) {
      throw Exception('Failed to delete patient: $e');
    }
  }

  /// Upload patient photos to Firebase Storage
  static Future<List<String>> uploadPatientPhotos(
    String patientId, 
    List<String> imagePaths, 
    String photoType, // 'baseline', 'wound', 'session'
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final uploadTasks = imagePaths.map((imagePath) async {
        final file = File(imagePath);
        if (!file.existsSync()) {
          throw Exception('Image file not found: $imagePath');
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final storageRef = _storage.ref().child('patients/$patientId/$photoType/$fileName');

        final uploadTask = storageRef.putFile(file);
        final snapshot = await uploadTask;
        
        return await snapshot.ref.getDownloadURL();
      });

      return await Future.wait(uploadTasks);
    } catch (e) {
      throw Exception('Failed to upload photos: $e');
    }
  }

  /// Upload signature images
  static Future<Map<String, String>> uploadSignatures(
    String patientId,
    Map<String, String> signaturePaths, // 'account', 'wound', 'witness'
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final uploadResults = <String, String>{};

      for (final entry in signaturePaths.entries) {
        final signatureType = entry.key;
        final imagePath = entry.value;

        if (imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (file.existsSync()) {
            final fileName = '${signatureType}_${DateTime.now().millisecondsSinceEpoch}.png';
            final storageRef = _storage.ref().child('patients/$patientId/signatures/$fileName');

            final uploadTask = storageRef.putFile(file);
            final snapshot = await uploadTask;
            
            uploadResults[signatureType] = await snapshot.ref.getDownloadURL();
          }
        }
      }

      return uploadResults;
    } catch (e) {
      throw Exception('Failed to upload signatures: $e');
    }
  }

  /// Search patients by name or ID
  static Future<List<Patient>> searchPatients(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      if (query.isEmpty) {
        // Return all patients for the practitioner
        final snapshot = await _patientsCollection
            .where('practitionerId', isEqualTo: userId)
            .orderBy('lastUpdated', descending: true)
            .get();
        
        return snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
      }

      // Search by surname (Firestore doesn't support full-text search)
      final lowercaseQuery = query.toLowerCase();
      
      final snapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .orderBy('surname')
          .startAt([lowercaseQuery])
          .endAt([lowercaseQuery + '\uf8ff'])
          .get();

      return snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to search patients: $e');
    }
  }

  /// Get patients with recent updates (last 7 days)
  static Future<List<Patient>> getRecentlyUpdatedPatients() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get recently updated patients: $e');
    }
  }

  /// Get patients with upcoming appointments
  static Future<List<Patient>> getPatientsWithUpcomingAppointments() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // This would typically query appointments collection and cross-reference
      // For now, return patients with recent sessions
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      final snapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(threeDaysAgo))
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get patients with upcoming appointments: $e');
    }
  }

  /// Calculate and update patient progress metrics
  static Future<void> updatePatientProgress(String patientId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final patient = await getPatient(patientId);
      if (patient == null) throw Exception('Patient not found');

      // Get all sessions for the patient
      final sessions = await getPatientSessions(patientId);
      
      if (sessions.isNotEmpty) {
        final latestSession = sessions.last;
        
        // Calculate progress metrics
        final weightChange = patient.baselineWeight > 0 
            ? ((latestSession.weight - patient.baselineWeight) / patient.baselineWeight) * 100
            : 0.0;
            
        final painReduction = patient.baselineVasScore > 0
            ? ((patient.baselineVasScore - latestSession.vasScore) / patient.baselineVasScore) * 100
            : 0.0;

        // Calculate wound healing progress (simplified)
        double woundHealingProgress = 0.0;
        if (patient.baselineWounds.isNotEmpty && latestSession.wounds.isNotEmpty) {
          final baselineArea = patient.baselineWounds.fold(0.0, (sum, w) => sum + w.area);
          final currentArea = latestSession.wounds.fold(0.0, (sum, w) => sum + w.area);
          if (baselineArea > 0) {
            woundHealingProgress = ((baselineArea - currentArea) / baselineArea) * 100;
          }
        }

        // Update patient with calculated metrics
        await _patientsCollection.doc(patientId).update({
          'currentWeight': latestSession.weight,
          'currentVasScore': latestSession.vasScore,
          'currentWounds': latestSession.wounds.map((w) => w.toFirestore()).toList(),
          'weightChange': weightChange,
          'painReduction': painReduction,
          'woundHealingProgress': woundHealingProgress,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      throw Exception('Failed to update patient progress: $e');
    }
  }

  /// Get patient sessions
  static Future<List<Session>> getPatientSessions(String patientId) async {
    print('📋 GET SESSIONS DEBUG: getPatientSessions started - MAIN COLLECTION');
    print('📋 GET SESSIONS DEBUG: Patient ID: $patientId');
    
    try {
      print('📋 GET SESSIONS DEBUG: Querying main sessions collection...');
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('patientId', isEqualTo: patientId)
          .orderBy('sessionNumber')
          .get();
      
      print('📋 GET SESSIONS DEBUG: Query completed');
      print('📋 GET SESSIONS DEBUG: Number of session documents found: ${snapshot.docs.length}');
      
      if (snapshot.docs.isEmpty) {
        print('📋 GET SESSIONS DEBUG: No sessions found for patient $patientId');
        return [];
      }
      
      print('📋 GET SESSIONS DEBUG: Converting documents to Session objects...');
      final sessions = snapshot.docs.map((doc) {
        print('📋 GET SESSIONS DEBUG: Processing session doc ID: ${doc.id}');
        print('📋 GET SESSIONS DEBUG: Session doc data keys: ${doc.data().keys.toList()}');
        return Session.fromFirestore(doc);
      }).toList();
      
      print('✅ GET SESSIONS DEBUG: Successfully converted ${sessions.length} sessions');
      print('📋 GET SESSIONS DEBUG: Session IDs: ${sessions.map((s) => s.id).toList()}');
      return sessions;
    } catch (e) {
      print('❌ GET SESSIONS DEBUG: Error getting sessions: $e');
      throw Exception('Failed to get patient sessions: $e');
    }
  }

  /// Add a session to a patient
  static Future<String> addPatientSession(String patientId, Session session) async {
    print('🔥 PATIENT SERVICE DEBUG: addPatientSession started');
    print('🔥 PATIENT SERVICE DEBUG: Patient ID: $patientId');
    print('🔥 PATIENT SERVICE DEBUG: Session ID: ${session.id}');
    print('🔥 PATIENT SERVICE DEBUG: Session Number: ${session.sessionNumber}');
    
    try {
      final userId = _auth.currentUser?.uid;
      print('🔥 PATIENT SERVICE DEBUG: Current user ID: $userId');
      
      if (userId == null) {
        print('❌ PATIENT SERVICE DEBUG: User not authenticated');
        throw Exception('User not authenticated');
      }

      // Verify patient ownership
      print('🔥 PATIENT SERVICE DEBUG: Verifying patient ownership...');
      final patient = await getPatient(patientId);
      if (patient == null) {
        print('❌ PATIENT SERVICE DEBUG: Patient not found');
        throw Exception('Patient not found');
      }
      print('🔥 PATIENT SERVICE DEBUG: Patient found: ${patient.name}');
      print('🔥 PATIENT SERVICE DEBUG: Patient practitioner ID: ${patient.practitionerId}');
      
      if (patient.practitionerId != userId) {
        print('❌ PATIENT SERVICE DEBUG: Access denied - practitioner mismatch');
        throw Exception('Access denied: Patient belongs to another practitioner');
      }
      print('✅ PATIENT SERVICE DEBUG: Patient ownership verified');

      // Add session to subcollection
      print('🔥 PATIENT SERVICE DEBUG: Converting session to Firestore format...');
      final sessionData = session.toFirestore();
      print('🔥 PATIENT SERVICE DEBUG: Session data for Firestore: $sessionData');
      
      print('🔥 PATIENT SERVICE DEBUG: Adding session to Firebase subcollection...');
      final sessionRef = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .add(sessionData);
      print('✅ PATIENT SERVICE DEBUG: Session added to Firebase with auto-ID: ${sessionRef.id}');

      // Update session with its own ID
      print('🔥 PATIENT SERVICE DEBUG: Updating session document with its own ID...');
      await sessionRef.update({'id': sessionRef.id});
      print('✅ PATIENT SERVICE DEBUG: Session document updated with ID');

      // Update patient progress
      print('🔥 PATIENT SERVICE DEBUG: Updating patient progress...');
      await updatePatientProgress(patientId);
      print('✅ PATIENT SERVICE DEBUG: Patient progress updated');

      print('✅ PATIENT SERVICE DEBUG: addPatientSession completed successfully!');
      print('🔥 PATIENT SERVICE DEBUG: Final session ID: ${sessionRef.id}');
      return sessionRef.id;
    } catch (e) {
      print('❌ PATIENT SERVICE DEBUG: Error in addPatientSession: $e');
      throw Exception('Failed to add session: $e');
    }
  }

  /// Helper method to delete photos from storage
  static Future<void> _deletePhotos(List<String> photoUrls) async {
    try {
      for (final photoUrl in photoUrls) {
        if (photoUrl.isNotEmpty) {
          final ref = _storage.refFromURL(photoUrl);
          await ref.delete();
        }
      }
    } catch (e) {
      // Log error but don't throw - deletion is best effort
      print('Warning: Failed to delete some photos: $e');
    }
  }

  /// Get patient statistics for dashboard
  static Future<Map<String, int>> getPatientStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = snapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();
      
      final totalPatients = patients.length;
      final patientsWithImprovement = patients.where((p) => p.hasImprovement).length;
      final recentlyUpdated = patients.where((p) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        return p.lastUpdated?.isAfter(sevenDaysAgo) == true;
      }).length;

      return {
        'total': totalPatients,
        'withImprovement': patientsWithImprovement,
        'recentlyUpdated': recentlyUpdated,
      };
    } catch (e) {
      throw Exception('Failed to get patient statistics: $e');
    }
  }
}
