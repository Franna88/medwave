import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../models/patient.dart';

class SessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _patientsCollection => _firestore.collection('patients');

  /// Get sessions for a specific patient
  static Stream<List<Session>> getPatientSessionsStream(String patientId) {
    return _patientsCollection
        .doc(patientId)
        .collection('sessions')
        .orderBy('sessionNumber')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
    });
  }

  /// Get all sessions for the current practitioner
  static Stream<List<Session>> getAllSessionsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _patientsCollection
        .where('practitionerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((patientsSnapshot) async {
      final allSessions = <Session>[];
      
      for (final patientDoc in patientsSnapshot.docs) {
        final sessionsSnapshot = await patientDoc.reference
            .collection('sessions')
            .orderBy('date', descending: true)
            .get();
        
        final sessions = sessionsSnapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList();
        
        allSessions.addAll(sessions);
      }
      
      // Sort all sessions by date
      allSessions.sort((a, b) => b.date.compareTo(a.date));
      return allSessions;
    });
  }

  /// Get a specific session by ID
  static Future<Session?> getSession(String patientId, String sessionId) async {
    try {
      final doc = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId)
          .get();
      
      if (doc.exists) {
        return Session.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get session: $e');
    }
  }

  /// Create a new session
  static Future<String> createSession(String patientId, Session session) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify patient ownership
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      if (patientData['practitionerId'] != userId) {
        throw Exception('Access denied: Patient belongs to another practitioner');
      }

      // Get the next session number
      final existingSessions = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .orderBy('sessionNumber', descending: true)
          .limit(1)
          .get();

      final nextSessionNumber = existingSessions.docs.isEmpty 
          ? 1 
          : (existingSessions.docs.first.data()['sessionNumber'] as int) + 1;

      // Create session with auto-generated session number
      final sessionData = session.copyWith(
        sessionNumber: nextSessionNumber,
        practitionerId: userId,
      );

      final docRef = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .add(sessionData.toFirestore());
      
      // Update the session document with its own ID
      await docRef.update({'id': docRef.id});

      // Update patient's current status with latest session data
      await _updatePatientProgressFromSession(patientId, sessionData);
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  /// Update an existing session
  static Future<void> updateSession(String patientId, String sessionId, Session session) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify patient ownership
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      if (patientData['practitionerId'] != userId) {
        throw Exception('Access denied: Patient belongs to another practitioner');
      }

      // Verify session exists
      final sessionDoc = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      // Update session
      final updatedSession = session.copyWith(
        practitionerId: userId,
      );

      await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId)
          .update(updatedSession.toFirestore());

      // Update patient's progress if this was the latest session
      final latestSession = await _getLatestSession(patientId);
      if (latestSession?.id == sessionId) {
        await _updatePatientProgressFromSession(patientId, updatedSession);
      }
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  /// Delete a session
  static Future<void> deleteSession(String patientId, String sessionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify patient ownership
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }
      
      final patientData = patientDoc.data() as Map<String, dynamic>;
      if (patientData['practitionerId'] != userId) {
        throw Exception('Access denied: Patient belongs to another practitioner');
      }

      // Get session data before deletion for photo cleanup
      final sessionDoc = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session = Session.fromFirestore(sessionDoc);

      // Delete session photos from storage
      await _deleteSessionPhotos(session.photos);

      // Delete session document
      await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .doc(sessionId)
          .delete();

      // Recalculate patient progress from remaining sessions
      await _recalculatePatientProgress(patientId);
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  /// Upload session photos to Firebase Storage
  static Future<List<String>> uploadSessionPhotos(
    String patientId,
    String sessionId,
    List<String> imagePaths,
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
        final storageRef = _storage.ref().child('sessions/$patientId/$sessionId/$fileName');

        final uploadTask = storageRef.putFile(file);
        final snapshot = await uploadTask;
        
        return await snapshot.ref.getDownloadURL();
      });

      return await Future.wait(uploadTasks);
    } catch (e) {
      throw Exception('Failed to upload session photos: $e');
    }
  }

  /// Get sessions for a date range
  static Future<List<Session>> getSessionsForDateRange(
    String patientId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date')
          .get();

      return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get sessions for date range: $e');
    }
  }

  /// Get recent sessions for dashboard
  static Future<List<Session>> getRecentSessions({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get patients for this practitioner
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final allSessions = <Session>[];

      for (final patientDoc in patientsSnapshot.docs) {
        final sessionsSnapshot = await patientDoc.reference
            .collection('sessions')
            .orderBy('date', descending: true)
            .limit(limit)
            .get();

        final sessions = sessionsSnapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList();

        allSessions.addAll(sessions);
      }

      // Sort and limit
      allSessions.sort((a, b) => b.date.compareTo(a.date));
      return allSessions.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get recent sessions: $e');
    }
  }

  /// Calculate progress metrics for a patient
  static Future<Map<String, double>> calculatePatientProgress(String patientId) async {
    try {
      // Get patient baseline data
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }

      final patient = Patient.fromFirestore(patientDoc);
      
      // Get all sessions
      final sessionsSnapshot = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .orderBy('sessionNumber')
          .get();

      final sessions = sessionsSnapshot.docs
          .map((doc) => Session.fromFirestore(doc))
          .toList();

      if (sessions.isEmpty) {
        return {
          'weightChange': 0.0,
          'painReduction': 0.0,
          'woundHealingProgress': 0.0,
        };
      }

      final latestSession = sessions.last;

      // Calculate weight change percentage
      final weightChange = patient.baselineWeight > 0
          ? ((latestSession.weight - patient.baselineWeight) / patient.baselineWeight) * 100
          : 0.0;

      // Calculate pain reduction percentage
      final painReduction = patient.baselineVasScore > 0
          ? ((patient.baselineVasScore - latestSession.vasScore) / patient.baselineVasScore) * 100
          : 0.0;

      // Calculate wound healing progress
      double woundHealingProgress = 0.0;
      if (patient.baselineWounds.isNotEmpty && latestSession.wounds.isNotEmpty) {
        final baselineArea = patient.baselineWounds.fold(0.0, (sum, w) => sum + w.area);
        final currentArea = latestSession.wounds.fold(0.0, (sum, w) => sum + w.area);
        if (baselineArea > 0) {
          woundHealingProgress = ((baselineArea - currentArea) / baselineArea) * 100;
        }
      }

      return {
        'weightChange': weightChange,
        'painReduction': painReduction,
        'woundHealingProgress': woundHealingProgress,
      };
    } catch (e) {
      throw Exception('Failed to calculate patient progress: $e');
    }
  }

  /// Get session statistics for dashboard
  static Future<Map<String, int>> getSessionStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Get patients for this practitioner
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      int totalSessions = 0;
      int monthSessions = 0;
      int todaySessions = 0;

      for (final patientDoc in patientsSnapshot.docs) {
        // Total sessions
        final totalSnapshot = await patientDoc.reference
            .collection('sessions')
            .get();
        totalSessions += totalSnapshot.docs.length;

        // This month sessions
        final monthSnapshot = await patientDoc.reference
            .collection('sessions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .get();
        monthSessions += monthSnapshot.docs.length;

        // Today sessions
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
        
        final todaySnapshot = await patientDoc.reference
            .collection('sessions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        todaySessions += todaySnapshot.docs.length;
      }

      return {
        'total': totalSessions,
        'thisMonth': monthSessions,
        'today': todaySessions,
        'patients': patientsSnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get session statistics: $e');
    }
  }

  /// Search sessions by notes or patient name
  static Future<List<Session>> searchSessions(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      if (query.isEmpty) {
        return await getRecentSessions(limit: 20);
      }

      // Get patients for this practitioner
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final allSessions = <Session>[];

      for (final patientDoc in patientsSnapshot.docs) {
        final sessionsSnapshot = await patientDoc.reference
            .collection('sessions')
            .orderBy('date', descending: true)
            .get();

        final sessions = sessionsSnapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .where((session) {
              final lowercaseQuery = query.toLowerCase();
              return session.notes.toLowerCase().contains(lowercaseQuery);
            })
            .toList();

        allSessions.addAll(sessions);
      }

      // Sort by date
      allSessions.sort((a, b) => b.date.compareTo(a.date));
      return allSessions;
    } catch (e) {
      throw Exception('Failed to search sessions: $e');
    }
  }

  // Private helper methods

  /// Update patient's current status from latest session
  static Future<void> _updatePatientProgressFromSession(String patientId, Session session) async {
    try {
      final progress = await calculatePatientProgress(patientId);
      
      await _patientsCollection.doc(patientId).update({
        'currentWeight': session.weight,
        'currentVasScore': session.vasScore,
        'currentWounds': session.wounds.map((w) => w.toFirestore()).toList(),
        'weightChange': progress['weightChange'],
        'painReduction': progress['painReduction'],
        'woundHealingProgress': progress['woundHealingProgress'],
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Warning: Failed to update patient progress: $e');
    }
  }

  /// Get the latest session for a patient
  static Future<Session?> _getLatestSession(String patientId) async {
    try {
      final snapshot = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .orderBy('sessionNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Session.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Recalculate patient progress from all remaining sessions
  static Future<void> _recalculatePatientProgress(String patientId) async {
    try {
      final latestSession = await _getLatestSession(patientId);
      if (latestSession != null) {
        await _updatePatientProgressFromSession(patientId, latestSession);
      } else {
        // No sessions left, reset to baseline
        final patientDoc = await _patientsCollection.doc(patientId).get();
        if (patientDoc.exists) {
          final patient = Patient.fromFirestore(patientDoc);
          await _patientsCollection.doc(patientId).update({
            'currentWeight': patient.baselineWeight,
            'currentVasScore': patient.baselineVasScore,
            'currentWounds': patient.baselineWounds.map((w) => w.toFirestore()).toList(),
            'weightChange': 0.0,
            'painReduction': 0.0,
            'woundHealingProgress': 0.0,
            'lastUpdated': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
    } catch (e) {
      print('Warning: Failed to recalculate patient progress: $e');
    }
  }

  /// Delete session photos from storage
  static Future<void> _deleteSessionPhotos(List<String> photoUrls) async {
    try {
      for (final photoUrl in photoUrls) {
        if (photoUrl.isNotEmpty) {
          final ref = _storage.refFromURL(photoUrl);
          await ref.delete();
        }
      }
    } catch (e) {
      // Log error but don't throw - deletion is best effort
      print('Warning: Failed to delete some session photos: $e');
    }
  }
}
