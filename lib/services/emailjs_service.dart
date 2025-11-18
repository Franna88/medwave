import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/appointment.dart';

/// EmailJS Service for sending appointment notifications
/// 
/// Uses EmailJS REST API to send emails directly from Flutter app without backend
class EmailJSService {
  // EmailJS Configuration
  static const String _serviceId = 'service_lg9tf22';
  static const String _userId = '0ZWNajCk0zcA8mXhu';
  
  // Template IDs
  static const String _bookingConfirmationTemplateId = 'template_fa05nmm';
  static const String _appointmentConfirmedTemplateId = 'template_a49n84w';
  static const String _bookingReminderTemplateId = 'template_2wi1x28';
  static const String _practitionerRegistrationTemplateId = 'template_vn12cfj'; // Admin notification - Practitioner Applied
  static const String _practitionerApprovalTemplateId = 'template_qnmopr1'; // Practitioner approval notification - Application Approved
  
  // Admin email for notifications
  static const String _adminEmail = 'info@barefootbytes.com'; // TODO: Update with actual superadmin email

  /// Send booking confirmation email
  static Future<bool> sendBookingConfirmation({
    required Appointment appointment,
    required String patientEmail,
    required String confirmationLink,
  }) async {
    try {
      debugPrint('📧 Sending booking confirmation email to $patientEmail');
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _bookingConfirmationTemplateId,
          'user_id': _userId,
          'template_params': {
            'patient_name': appointment.patientName,
            'patient_email': patientEmail,
            'appointment_date': _formatDate(appointment.startTime),
            'appointment_time': _formatTime(appointment.startTime),
            'practitioner_name': appointment.practitionerName ?? 'To be assigned',
            'location': appointment.location ?? 'Main Clinic',
            'appointment_type': appointment.type.displayName,
            'confirmation_link': confirmationLink,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Booking confirmation email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send booking confirmation email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending booking confirmation email: $error');
      return false;
    }
  }

  /// Send appointment confirmed email
  static Future<bool> sendAppointmentConfirmed({
    required Appointment appointment,
    required String patientEmail,
  }) async {
    try {
      debugPrint('📧 Sending appointment confirmed email to $patientEmail');
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _appointmentConfirmedTemplateId,
          'user_id': _userId,
          'template_params': {
            'patient_name': appointment.patientName,
            'patient_email': patientEmail,
            'appointment_date': _formatDate(appointment.startTime),
            'appointment_time': _formatTime(appointment.startTime),
            'practitioner_name': appointment.practitionerName ?? 'To be assigned',
            'location': appointment.location ?? 'Main Clinic',
            'appointment_type': appointment.type.displayName,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Appointment confirmed email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send appointment confirmed email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending appointment confirmed email: $error');
      return false;
    }
  }

  /// Send appointment reminder email
  static Future<bool> sendAppointmentReminder({
    required Appointment appointment,
    required String patientEmail,
  }) async {
    try {
      debugPrint('📧 Sending appointment reminder email to $patientEmail');
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _bookingReminderTemplateId,
          'user_id': _userId,
          'template_params': {
            'patient_name': appointment.patientName,
            'patient_email': patientEmail,
            'appointment_date': _formatDate(appointment.startTime),
            'appointment_time': _formatTime(appointment.startTime),
            'practitioner_name': appointment.practitionerName ?? 'To be assigned',
            'location': appointment.location ?? 'Main Clinic',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Appointment reminder email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send appointment reminder email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending appointment reminder email: $error');
      return false;
    }
  }

  /// Format date for email (e.g., "Wednesday, November 5, 2025")
  static String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  /// Format time for email (e.g., "10:00 AM")
  static String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Generate confirmation link
  /// This would point to your web app or a Cloud Function endpoint
  static String generateConfirmationLink(String appointmentId) {
    // For now, using the Cloud Function we created earlier
    return 'https://us-central1-medx-ai.cloudfunctions.net/confirmAppointmentViaEmail?id=$appointmentId';
  }

  /// Send practitioner registration notification to admin
  static Future<bool> sendPractitionerRegistrationNotification({
    required String practitionerName,
    required String practitionerEmail,
    required String specialization,
    required String licenseNumber,
    required String country,
    required String registrationDate,
  }) async {
    try {
      debugPrint('📧 Sending practitioner registration notification to admin');
      debugPrint('📧 Admin email: $_adminEmail');
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _practitionerRegistrationTemplateId,
          'user_id': _userId,
          'template_params': {
            'to_email': _adminEmail, // EmailJS standard recipient field
            'to_name': 'MedWave Admin',
            'admin_email': _adminEmail,
            'practitioner_name': practitionerName,
            'practitioner_email': practitionerEmail,
            'specialization': specialization,
            'license_number': licenseNumber,
            'country': country,
            'registration_date': registrationDate,
            'admin_dashboard_link': 'http://localhost:52961/#/admin/approvals', // Local dev URL
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Practitioner registration notification sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send practitioner registration notification: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending practitioner registration notification: $error');
      return false;
    }
  }

  /// Send practitioner approval email
  static Future<bool> sendPractitionerApprovalEmail({
    required String practitionerName,
    required String practitionerEmail,
    required String approvalDate,
  }) async {
    try {
      debugPrint('📧 Sending practitioner approval email to $practitionerEmail');
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _practitionerApprovalTemplateId,
          'user_id': _userId,
          'template_params': {
            'to_email': practitionerEmail, // EmailJS standard recipient field
            'to_name': practitionerName,
            'practitioner_name': practitionerName,
            'practitioner_email': practitionerEmail,
            'approval_date': approvalDate,
            'login_link': 'http://localhost:52961/#/login', // Local dev URL
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Practitioner approval email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send practitioner approval email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending practitioner approval email: $error');
      return false;
    }
  }
}

