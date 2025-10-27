import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment.dart';
import '../models/sync_status.dart';
import '../config/google_calendar_config.dart';

/// Service for managing Google Calendar integration
/// 
/// Handles OAuth authentication, two-way sync between MedWave and Google Calendar,
/// and manages sync conflicts.
class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  GoogleSignIn? _googleSignIn;
  calendar.CalendarApi? _calendarApi;
  String? _googleCalendarId = 'primary'; // Use primary calendar by default

  /// Initialize Google Sign-In
  void _initGoogleSignIn() {
    if (_googleSignIn == null) {
      _googleSignIn = GoogleSignIn(
        scopes: GoogleCalendarConfig.scopes,
        clientId: GoogleCalendarConfig.webClientId,
      );
    }
  }

  /// Authenticate with Google and connect calendar
  /// Returns true if successful, false otherwise
  Future<bool> authenticateWithGoogle() async {
    try {
      _initGoogleSignIn();
      
      // Sign in with Google
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) {
        debugPrint('Google Sign-In cancelled by user');
        return false;
      }

      // Get authenticated HTTP client
      final auth.AuthClient? httpClient = await _googleSignIn!.authenticatedClient();
      if (httpClient == null) {
        debugPrint('Failed to get authenticated HTTP client');
        return false;
      }

      // Initialize Calendar API
      _calendarApi = calendar.CalendarApi(httpClient);

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? refreshToken = googleAuth.idToken; // Note: refreshToken might not be available
      
      if (accessToken == null) {
        debugPrint('Failed to get access token');
        return false;
      }

      // Calculate token expiration (typically 1 hour)
      final DateTime tokenExpiration = DateTime.now().add(const Duration(hours: 1));

      // Save connection info to Firestore
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('No authenticated user');
        return false;
      }

      await _firestore.collection('users').doc(userId).update({
        'googleCalendarConnected': true,
        'googleCalendarId': _googleCalendarId,
        'googleAccessToken': accessToken,
        'googleRefreshToken': refreshToken,
        'tokenExpiresAt': Timestamp.fromDate(tokenExpiration),
        'syncEnabled': true,
        'lastSyncTime': Timestamp.fromDate(DateTime.now()),
        'syncErrorCount': 0,
        'lastSyncError': null,
      });

      debugPrint('Successfully connected to Google Calendar');
      return true;
    } catch (e) {
      debugPrint('Error authenticating with Google Calendar: $e');
      return false;
    }
  }

  /// Disconnect Google Calendar
  Future<bool> disconnectGoogleCalendar() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Sign out from Google
      await _googleSignIn?.signOut();

      // Clear connection info from Firestore
      await _firestore.collection('users').doc(userId).update({
        'googleCalendarConnected': false,
        'googleCalendarId': null,
        'googleAccessToken': null,
        'googleRefreshToken': null,
        'tokenExpiresAt': null,
        'syncEnabled': false,
        'lastSyncError': null,
      });

      _calendarApi = null;
      debugPrint('Successfully disconnected from Google Calendar');
      return true;
    } catch (e) {
      debugPrint('Error disconnecting from Google Calendar: $e');
      return false;
    }
  }

  /// Check if Calendar API is ready
  Future<bool> _ensureCalendarApiReady() async {
    if (_calendarApi != null) return true;

    try {
      _initGoogleSignIn();
      
      // Try to sign in silently
      final GoogleSignInAccount? account = await _googleSignIn!.signInSilently();
      if (account == null) {
        debugPrint('Not signed in to Google');
        return false;
      }

      // Get authenticated HTTP client
      final auth.AuthClient? httpClient = await _googleSignIn!.authenticatedClient();
      if (httpClient == null) {
        debugPrint('Failed to get authenticated HTTP client');
        return false;
      }

      _calendarApi = calendar.CalendarApi(httpClient);
      return true;
    } catch (e) {
      debugPrint('Error ensuring Calendar API ready: $e');
      return false;
    }
  }

  /// Sync appointment to Google Calendar (create or update)
  Future<String?> syncAppointmentToGoogle(Appointment appointment) async {
    try {
      if (!await _ensureCalendarApiReady()) {
        throw Exception('Google Calendar API not ready');
      }

      final event = _appointmentToGoogleEvent(appointment);

      // Check if appointment already has a Google Event ID (update) or create new
      calendar.Event result;
      if (appointment.googleEventId != null) {
        // Update existing event
        result = await _calendarApi!.events.update(
          event,
          _googleCalendarId!,
          appointment.googleEventId!,
        );
        debugPrint('Updated Google Calendar event: ${result.id}');
      } else {
        // Create new event
        result = await _calendarApi!.events.insert(
          event,
          _googleCalendarId!,
        );
        debugPrint('Created Google Calendar event: ${result.id}');
      }

      // Update appointment with Google Event ID and sync status
      await _updateAppointmentSyncStatus(
        appointment.id,
        result.id!,
        'synced',
        null,
      );

      return result.id;
    } catch (e) {
      debugPrint('Error syncing appointment to Google Calendar: $e');
      await _updateAppointmentSyncStatus(
        appointment.id,
        appointment.googleEventId,
        'error',
        e.toString(),
      );
      return null;
    }
  }

  /// Delete appointment from Google Calendar
  Future<bool> deleteAppointmentFromGoogle(String googleEventId) async {
    try {
      if (!await _ensureCalendarApiReady()) {
        throw Exception('Google Calendar API not ready');
      }

      await _calendarApi!.events.delete(_googleCalendarId!, googleEventId);
      debugPrint('Deleted Google Calendar event: $googleEventId');
      return true;
    } catch (e) {
      debugPrint('Error deleting appointment from Google Calendar: $e');
      return false;
    }
  }

  /// Sync from Google Calendar to MedWave (pull changes)
  /// Returns list of synced appointment IDs
  Future<List<String>> syncFromGoogleCalendar({DateTime? startDate, DateTime? endDate}) async {
    try {
      if (!await _ensureCalendarApiReady()) {
        throw Exception('Google Calendar API not ready');
      }

      // Default to syncing last 30 days and next 90 days
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now().add(const Duration(days: 90));

      // Fetch events from Google Calendar
      final events = await _calendarApi!.events.list(
        _googleCalendarId!,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      final List<String> syncedIds = [];
      final userId = _auth.currentUser?.uid;
      if (userId == null) return syncedIds;

      // Process each event
      for (final event in events.items ?? []) {
        try {
          // Check if this event is linked to a MedWave appointment
          final appointmentQuery = await _firestore
              .collection('appointments')
              .where('googleEventId', isEqualTo: event.id)
              .where('practitionerId', isEqualTo: userId)
              .limit(1)
              .get();

          if (appointmentQuery.docs.isNotEmpty) {
            // Update existing appointment
            final appointmentDoc = appointmentQuery.docs.first;
            final appointment = Appointment.fromFirestore(appointmentDoc);
            
            // Check for conflicts
            if (_hasConflict(appointment, event)) {
              await _handleSyncConflict(appointment, event);
            } else {
              // Update appointment from Google event
              await _updateAppointmentFromGoogleEvent(appointment.id, event);
              syncedIds.add(appointment.id);
            }
          } else {
            // This is a new event from Google Calendar
            // Check if it's a MedWave-created event by checking description
            if (event.description?.contains('MedWave') ?? false) {
              // Create new appointment from Google event
              final newAppointmentId = await _createAppointmentFromGoogleEvent(event);
              if (newAppointmentId != null) {
                syncedIds.add(newAppointmentId);
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing Google Calendar event ${event.id}: $e');
        }
      }

      // Update last sync time
      await _firestore.collection('users').doc(userId).update({
        'lastSyncTime': Timestamp.fromDate(DateTime.now()),
        'syncErrorCount': 0,
        'lastSyncError': null,
      });

      debugPrint('Synced ${syncedIds.length} appointments from Google Calendar');
      return syncedIds;
    } catch (e) {
      debugPrint('Error syncing from Google Calendar: $e');
      
      // Update sync error info
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final errorCount = (userDoc.data()?['syncErrorCount'] ?? 0) + 1;
        
        await _firestore.collection('users').doc(userId).update({
          'syncErrorCount': errorCount,
          'lastSyncError': e.toString(),
        });
      }
      
      return [];
    }
  }

  /// Convert MedWave Appointment to Google Calendar Event
  calendar.Event _appointmentToGoogleEvent(Appointment appointment) {
    final bool includePatientName = GoogleCalendarConfig.includePatientNamesInGoogleEvents;
    
    final String title = includePatientName 
        ? appointment.title 
        : GoogleCalendarConfig.genericEventTitle;
    
    final String description = includePatientName
        ? 'MedWave Appointment\n\n'
          'Patient: ${appointment.patientName}\n'
          'Type: ${appointment.type.displayName}\n'
          'Location: ${appointment.location ?? 'Not specified'}\n\n'
          '${appointment.description ?? ''}'
        : 'MedWave Appointment\n\n${appointment.description ?? ''}';

    return calendar.Event(
      summary: title,
      description: description,
      location: appointment.location,
      start: calendar.EventDateTime(
        dateTime: appointment.startTime.toUtc(),
        timeZone: 'UTC',
      ),
      end: calendar.EventDateTime(
        dateTime: appointment.endTime.toUtc(),
        timeZone: 'UTC',
      ),
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(method: 'popup', minutes: 30),
        ],
      ),
    );
  }

  /// Update appointment sync status in Firestore
  Future<void> _updateAppointmentSyncStatus(
    String appointmentId,
    String? googleEventId,
    String syncStatus,
    String? errorMessage,
  ) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        if (googleEventId != null) 'googleEventId': googleEventId,
        'syncStatus': syncStatus,
        'lastSyncedAt': Timestamp.fromDate(DateTime.now()),
        if (errorMessage != null) 'syncError': errorMessage,
      });
    } catch (e) {
      debugPrint('Error updating appointment sync status: $e');
    }
  }

  /// Update appointment from Google Calendar event
  Future<void> _updateAppointmentFromGoogleEvent(
    String appointmentId,
    calendar.Event event,
  ) async {
    try {
      final updates = <String, dynamic>{
        'title': event.summary ?? 'Untitled',
        'description': event.description,
        'location': event.location,
        'startTime': Timestamp.fromDate(event.start!.dateTime!.toLocal()),
        'endTime': Timestamp.fromDate(event.end!.dateTime!.toLocal()),
        'syncStatus': 'synced',
        'lastSyncedAt': Timestamp.fromDate(DateTime.now()),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      };

      await _firestore.collection('appointments').doc(appointmentId).update(updates);
    } catch (e) {
      debugPrint('Error updating appointment from Google event: $e');
    }
  }

  /// Create appointment from Google Calendar event
  Future<String?> _createAppointmentFromGoogleEvent(calendar.Event event) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Parse patient name from description if available
      String patientName = 'Unknown Patient';
      if (event.description != null && event.description!.contains('Patient:')) {
        final lines = event.description!.split('\n');
        for (final line in lines) {
          if (line.contains('Patient:')) {
            patientName = line.replaceFirst('Patient:', '').trim();
            break;
          }
        }
      }

      final appointmentData = {
        'id': '', // Will be set after creation
        'patientId': 'google_sync_${DateTime.now().millisecondsSinceEpoch}',
        'patientName': patientName,
        'title': event.summary ?? 'Untitled',
        'description': event.description,
        'startTime': Timestamp.fromDate(event.start!.dateTime!.toLocal()),
        'endTime': Timestamp.fromDate(event.end!.dateTime!.toLocal()),
        'type': 'consultation',
        'status': 'scheduled',
        'practitionerId': userId,
        'location': event.location,
        'notes': ['Synced from Google Calendar'],
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
        'googleEventId': event.id,
        'syncStatus': 'synced',
        'lastSyncedAt': Timestamp.fromDate(DateTime.now()),
      };

      final docRef = await _firestore.collection('appointments').add(appointmentData);
      await docRef.update({'id': docRef.id});

      debugPrint('Created appointment from Google Calendar event: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating appointment from Google event: $e');
      return null;
    }
  }

  /// Check if there's a conflict between MedWave appointment and Google event
  bool _hasConflict(Appointment appointment, calendar.Event event) {
    final googleStart = event.start?.dateTime?.toLocal();
    final googleEnd = event.end?.dateTime?.toLocal();
    
    if (googleStart == null || googleEnd == null) return false;

    // Check if times differ
    if (appointment.startTime != googleStart || appointment.endTime != googleEnd) {
      return true;
    }

    // Check if titles differ significantly
    if (appointment.title != event.summary) {
      return true;
    }

    return false;
  }

  /// Handle sync conflict
  Future<void> _handleSyncConflict(
    Appointment appointment,
    calendar.Event event,
  ) async {
    try {
      // Mark as conflict for manual resolution
      await _firestore.collection('appointments').doc(appointment.id).update({
        'syncStatus': 'conflict',
        'lastSyncedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Store conflict information for UI resolution
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('syncConflicts')
          .add({
        'appointmentId': appointment.id,
        'medwaveData': {
          'title': appointment.title,
          'startTime': Timestamp.fromDate(appointment.startTime),
          'endTime': Timestamp.fromDate(appointment.endTime),
        },
        'googleData': {
          'title': event.summary,
          'startTime': Timestamp.fromDate(event.start!.dateTime!.toLocal()),
          'endTime': Timestamp.fromDate(event.end!.dateTime!.toLocal()),
        },
        'detectedAt': Timestamp.fromDate(DateTime.now()),
        'conflictReason': 'Time or title mismatch',
      });

      debugPrint('Conflict detected for appointment: ${appointment.id}');
    } catch (e) {
      debugPrint('Error handling sync conflict: $e');
    }
  }

  /// Resolve conflict manually - choose MedWave version
  Future<bool> resolveConflictWithMedWave(String appointmentId) async {
    try {
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) return false;

      final appointment = Appointment.fromFirestore(appointmentDoc);
      
      // Sync MedWave version to Google
      await syncAppointmentToGoogle(appointment);
      
      // Delete conflict record
      await _deleteConflictRecord(appointmentId);
      
      return true;
    } catch (e) {
      debugPrint('Error resolving conflict with MedWave: $e');
      return false;
    }
  }

  /// Resolve conflict manually - choose Google version
  Future<bool> resolveConflictWithGoogle(String appointmentId) async {
    try {
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!appointmentDoc.exists) return false;

      final appointment = Appointment.fromFirestore(appointmentDoc);
      
      if (appointment.googleEventId == null) return false;

      // Fetch Google event
      final event = await _calendarApi!.events.get(_googleCalendarId!, appointment.googleEventId!);
      
      // Update MedWave appointment from Google
      await _updateAppointmentFromGoogleEvent(appointmentId, event);
      
      // Delete conflict record
      await _deleteConflictRecord(appointmentId);
      
      return true;
    } catch (e) {
      debugPrint('Error resolving conflict with Google: $e');
      return false;
    }
  }

  /// Delete conflict record
  Future<void> _deleteConflictRecord(String appointmentId) async {
    try {
      final conflicts = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('syncConflicts')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      for (final doc in conflicts.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting conflict record: $e');
    }
  }

  /// Check connection status
  Future<GoogleCalendarConnection> getConnectionStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return GoogleCalendarConnection.disconnected();
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return GoogleCalendarConnection.disconnected();
      }

      return GoogleCalendarConnection.fromMap(userDoc.data()!);
    } catch (e) {
      debugPrint('Error getting connection status: $e');
      return GoogleCalendarConnection.disconnected();
    }
  }
}


