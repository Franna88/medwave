import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/appointment.dart';

class AppointmentNotificationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Schedule a reminder notification for an appointment
  static Future<bool> scheduleAppointmentReminder(
    String appointmentId, {
    Duration reminderTime = const Duration(hours: 24), // 24 hours before
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('scheduleAppointmentReminder');
      final result = await callable.call({
        'appointmentId': appointmentId,
        'userId': userId,
        'reminderTimeMinutes': reminderTime.inMinutes,
      });

      return result.data['success'] == true;
    } catch (e) {
      // For now, just return false on error
      // In production, you'd want proper error handling
      print('Failed to schedule appointment reminder: $e');
      return false;
    }
  }

  /// Cancel a scheduled reminder notification
  static Future<bool> cancelAppointmentReminder(String appointmentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('cancelAppointmentReminder');
      final result = await callable.call({
        'appointmentId': appointmentId,
        'userId': userId,
      });

      return result.data['success'] == true;
    } catch (e) {
      print('Failed to cancel appointment reminder: $e');
      return false;
    }
  }

  /// Send immediate notification for appointment status change
  static Future<bool> sendAppointmentStatusNotification(
    Appointment appointment,
    AppointmentStatus oldStatus,
    AppointmentStatus newStatus,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('sendAppointmentStatusNotification');
      final result = await callable.call({
        'appointmentId': appointment.id,
        'patientId': appointment.patientId,
        'patientName': appointment.patientName,
        'appointmentTitle': appointment.title,
        'appointmentDate': appointment.startTime.toIso8601String(),
        'oldStatus': oldStatus.name,
        'newStatus': newStatus.name,
        'practitionerId': userId,
      });

      return result.data['success'] == true;
    } catch (e) {
      print('Failed to send status notification: $e');
      return false;
    }
  }

  /// Get notification preferences for the current user
  static Future<Map<String, bool>> getNotificationPreferences() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('getNotificationPreferences');
      final result = await callable.call({'userId': userId});

      return Map<String, bool>.from(result.data['preferences'] ?? {
        'appointmentReminders': true,
        'statusChanges': true,
        'conflicts': true,
        'dailySummary': false,
      });
    } catch (e) {
      print('Failed to get notification preferences: $e');
      // Return default preferences
      return {
        'appointmentReminders': true,
        'statusChanges': true,
        'conflicts': true,
        'dailySummary': false,
      };
    }
  }

  /// Update notification preferences for the current user
  static Future<bool> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final callable = _functions.httpsCallable('updateNotificationPreferences');
      final result = await callable.call({
        'userId': userId,
        'preferences': preferences,
      });

      return result.data['success'] == true;
    } catch (e) {
      print('Failed to update notification preferences: $e');
      return false;
    }
  }

  /// Utility method to generate notification content
  static Map<String, String> generateNotificationContent(
    Appointment appointment,
    String notificationType,
  ) {
    switch (notificationType) {
      case 'reminder':
        return {
          'title': 'Appointment Reminder',
          'body': 'You have an appointment with ${appointment.patientName} tomorrow at ${appointment.timeRange}',
        };
      case 'statusChange':
        return {
          'title': 'Appointment Status Updated',
          'body': 'Appointment with ${appointment.patientName} status changed to ${appointment.status.displayName}',
        };
      case 'conflict':
        return {
          'title': 'Appointment Conflict',
          'body': 'Potential conflict detected with appointment for ${appointment.patientName}',
        };
      default:
        return {
          'title': 'Appointment Notification',
          'body': 'You have an appointment with ${appointment.patientName}',
        };
    }
  }
}

/// Local notification helper for development/testing
class LocalAppointmentNotifications {
  /// Simple local notification simulation
  static void showLocalNotification(String title, String body) {
    // In a real implementation, you'd use flutter_local_notifications
    // For now, just print to console for development
    print('📅 NOTIFICATION: $title - $body');
  }

  /// Schedule local notification (development only)
  static void scheduleLocalReminder(Appointment appointment) {
    final reminderTime = appointment.startTime.subtract(const Duration(hours: 24));
    final now = DateTime.now();
    
    if (reminderTime.isAfter(now)) {
      final content = AppointmentNotificationService.generateNotificationContent(
        appointment,
        'reminder',
      );
      
      // Simulate scheduling
      print('🔔 Scheduled reminder for ${appointment.patientName} at $reminderTime');
      print('   Title: ${content['title']}');
      print('   Body: ${content['body']}');
    }
  }

  /// Show immediate notification for status changes
  static void showStatusChangeNotification(
    Appointment appointment,
    AppointmentStatus oldStatus,
    AppointmentStatus newStatus,
  ) {
    final content = AppointmentNotificationService.generateNotificationContent(
      appointment,
      'statusChange',
    );
    
    showLocalNotification(content['title']!, content['body']!);
  }
}
