import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
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

  /// Get ALL patients stream (for admin users only)
  static Stream<List<Patient>> getAllPatientsStream() {
    debugPrint('PatientService: Querying ALL patients (admin mode)');
    return _patientsCollection
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Found ${snapshot.docs.length} total patients in database');
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
      if (userId == null) {
        print('❌ PHOTO DEBUG: User not authenticated');
        throw Exception('User not authenticated');
      }

      print('📸 PHOTO DEBUG: Starting photo upload for patient $patientId');
      print('📸 PHOTO DEBUG: User ID: $userId');
      print('📸 PHOTO DEBUG: Photo type: $photoType');
      print('📸 PHOTO DEBUG: Number of photos: ${imagePaths.length}');

      final uploadTasks = imagePaths.map((imagePath) async {
        print('📸 PHOTO DEBUG: Processing image: $imagePath');
        
        final file = File(imagePath);
        if (!file.existsSync()) {
          print('❌ PHOTO DEBUG: Image file not found: $imagePath');
          throw Exception('Image file not found: $imagePath');
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final storageRef = _storage.ref().child('patients/$patientId/$photoType/$fileName');

        print('📸 PHOTO DEBUG: Storage path: patients/$patientId/$photoType/$fileName');
        print('📸 PHOTO DEBUG: File size: ${await file.length()} bytes');

        try {
          final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(
              contentType: 'image/jpeg', // Assume JPEG for photos
            ),
          );
          
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          print('✅ PHOTO DEBUG: Photo uploaded successfully: $downloadUrl');
          return downloadUrl;
        } catch (uploadError) {
          print('❌ PHOTO DEBUG: Upload failed for $imagePath: $uploadError');
          
          // Try simplified upload without metadata
          try {
            final simpleUploadTask = storageRef.putFile(file);
            final snapshot = await simpleUploadTask;
            final downloadUrl = await snapshot.ref.getDownloadURL();
            
            print('✅ PHOTO DEBUG: Photo uploaded (fallback): $downloadUrl');
            return downloadUrl;
          } catch (fallbackError) {
            print('❌ PHOTO DEBUG: Fallback upload also failed: $fallbackError');
            throw Exception('Failed to upload photo: $fallbackError');
          }
        }
      });

      final results = await Future.wait(uploadTasks);
      print('✅ PHOTO DEBUG: All photos uploaded successfully. Count: ${results.length}');
      return results;
    } catch (e) {
      print('❌ PHOTO DEBUG: Error uploading photos: $e');
      throw Exception('Failed to upload photos: $e');
    }
  }

  /// Upload signature images from file paths
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

  /// Upload signature images from bytes data
  static Future<Map<String, String>> uploadSignatureBytes(
    String patientId,
    Map<String, Uint8List> signatureBytes, // 'account', 'wound', 'witness'
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ SIGNATURE DEBUG: User not authenticated');
        throw Exception('User not authenticated');
      }

      print('🖋️ SIGNATURE DEBUG: Starting signature upload for patient $patientId');
      print('🖋️ SIGNATURE DEBUG: User ID: $userId');
      print('🖋️ SIGNATURE DEBUG: Signatures to upload: ${signatureBytes.keys.toList()}');

      final uploadResults = <String, String>{};

      for (final entry in signatureBytes.entries) {
        final signatureType = entry.key;
        final bytes = entry.value;

        if (bytes.isNotEmpty) {
          print('🖋️ SIGNATURE DEBUG: Uploading $signatureType signature (${bytes.length} bytes)');
          
          try {
            // Use consistent path structure
            final fileName = '${signatureType}_${DateTime.now().millisecondsSinceEpoch}.png';
            final storageRef = _storage.ref().child('signatures/$patientId/$fileName');

            print('🖋️ SIGNATURE DEBUG: Storage path: signatures/$patientId/$fileName');
            print('🖋️ SIGNATURE DEBUG: Storage bucket: ${_storage.bucket}');

            // Try upload with minimal metadata
            final uploadTask = storageRef.putData(
              bytes,
              SettableMetadata(
                contentType: 'image/png',
                customMetadata: {
                  'uploadedBy': userId,
                  'patientId': patientId,
                },
              ),
            );
            
            print('🖋️ SIGNATURE DEBUG: Upload task created, waiting for completion...');
            final snapshot = await uploadTask;
            print('🖋️ SIGNATURE DEBUG: Upload completed, getting download URL...');
            
            final downloadUrl = await snapshot.ref.getDownloadURL();
            
            uploadResults[signatureType] = downloadUrl;
            print('✅ SIGNATURE DEBUG: $signatureType signature uploaded: $downloadUrl');
          } catch (uploadError) {
            print('❌ SIGNATURE DEBUG: Primary upload failed for $signatureType: $uploadError');
            
            // Try simplified approach with basic path and no metadata
            try {
              final fileName = '${patientId}_${signatureType}_${DateTime.now().millisecondsSinceEpoch}.png';
              final storageRef = _storage.ref().child('test_signatures/$fileName'); // Different path to avoid conflicts

              print('🖋️ SIGNATURE DEBUG: Trying simplified path: test_signatures/$fileName');

              // No metadata at all to avoid HTTP 412
              final uploadTask = storageRef.putData(bytes);
              
              final snapshot = await uploadTask;
              final downloadUrl = await snapshot.ref.getDownloadURL();
              
              uploadResults[signatureType] = downloadUrl;
              print('✅ SIGNATURE DEBUG: $signatureType signature uploaded (fallback): $downloadUrl');
            } catch (fallbackError) {
              print('❌ SIGNATURE DEBUG: Fallback upload also failed for $signatureType: $fallbackError');
              
              // Final attempt with timestamp-based unique path
              try {
                final uniqueId = DateTime.now().millisecondsSinceEpoch;
                final finalFileName = 'sig_${uniqueId}_${signatureType}.png';
                final finalStorageRef = _storage.ref().child('uploads/$finalFileName');
                
                print('🖋️ SIGNATURE DEBUG: Final attempt with path: uploads/$finalFileName');
                
                // Most basic upload possible
                final finalUploadTask = finalStorageRef.putData(bytes);
                final finalSnapshot = await finalUploadTask;
                final finalDownloadUrl = await finalSnapshot.ref.getDownloadURL();
                
                uploadResults[signatureType] = finalDownloadUrl;
                print('✅ SIGNATURE DEBUG: $signatureType signature uploaded (final attempt): $finalDownloadUrl');
              } catch (finalError) {
                print('❌ SIGNATURE DEBUG: All upload attempts failed for $signatureType: $finalError');
                print('⚠️ SIGNATURE DEBUG: Skipping $signatureType signature due to upload failure');
              }
            }
          }
        } else {
          print('⚠️ SIGNATURE DEBUG: Skipping empty $signatureType signature');
        }
      }

      print('✅ SIGNATURE DEBUG: Upload process completed. Results: ${uploadResults.keys.toList()}');
      return uploadResults;
    } catch (e) {
      print('❌ SIGNATURE DEBUG: Error uploading signatures: $e');
      throw Exception('Failed to upload signature bytes: $e');
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
    // Reduced debug logging to improve performance
    print('📋 SESSIONS: Getting sessions for patient $patientId');
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('patientId', isEqualTo: patientId)
          .orderBy('sessionNumber')
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('📋 SESSIONS: No sessions found for patient $patientId');
        return [];
      }
      
      final sessions = snapshot.docs.map((doc) {
        return Session.fromFirestore(doc);
      }).toList();
      
      print('✅ SESSIONS: Loaded ${sessions.length} sessions for patient $patientId');
      return sessions;
    } catch (e) {
      print('❌ SESSIONS: Error getting sessions: $e');
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
