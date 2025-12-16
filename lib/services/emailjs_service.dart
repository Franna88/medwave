import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../models/streams/appointment.dart' as sales_models;

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
  static const String _practitionerRegistrationTemplateId =
      'template_vn12cfj'; // Admin notification - Practitioner Applied
  static const String _practitionerApprovalTemplateId =
      'template_qnmopr1'; // Practitioner approval notification - Application Approved
  static const String _depositCustomerTemplateId = 'template_6vqr5ib';
  static const String _depositMarketingTemplateId = 'template_6vqr5ib';

  // Admin email for notifications
  static const String _adminEmail =
      'info@barefootbytes.com'; // TODO: Update with actual superadmin email

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
            'practitioner_name':
                appointment.practitionerName ?? 'To be assigned',
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
        debugPrint(
          '❌ Failed to send booking confirmation email: ${response.body}',
        );
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
            'practitioner_name':
                appointment.practitionerName ?? 'To be assigned',
            'location': appointment.location ?? 'Main Clinic',
            'appointment_type': appointment.type.displayName,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Appointment confirmed email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send appointment confirmed email: ${response.body}',
        );
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
            'practitioner_name':
                appointment.practitionerName ?? 'To be assigned',
            'location': appointment.location ?? 'Main Clinic',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Appointment reminder email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send appointment reminder email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending appointment reminder email: $error');
      return false;
    }
  }

  /// Send customer-facing deposit request (Yes/No) with customizable text
  static Future<bool> sendCustomerDepositRequest({
    required sales_models.SalesAppointment appointment,
    required String yesUrl,
    required String noUrl,
    String? description,
    String? yesLabel,
    String? noLabel,
  }) async {
    final amountText = appointment.depositAmount != null
        ? appointment.depositAmount!.toStringAsFixed(2)
        : 'N/A';
    final resolvedDescription =
        description ??
        'Have you made the deposit${amountText != 'N/A' ? ' of $amountText' : ''}?';

    return _sendDepositEmail(
      templateId: _depositCustomerTemplateId,
      toEmail: appointment.email,
      toName: appointment.customerName,
      templateParams: _buildDepositParams(
        appointment: appointment,
        yesUrl: yesUrl,
        noUrl: noUrl,
        description: resolvedDescription,
        yesLabel: yesLabel ?? 'Yes, I made the deposit',
        noLabel: noLabel ?? 'No, not yet',
      ),
    );
  }

  /// Send marketing notification when customer confirms deposit
  static Future<bool> sendMarketingDepositNotification({
    required sales_models.SalesAppointment appointment,
    String? marketingEmail,
    String? description,
    String? yesLabel,
    String? noLabel,
    String? yesUrl,
    String? noUrl,
  }) async {
    final resolvedEmail = marketingEmail ?? 'tertiusva@gmail.com';
    final resolvedYesUrl = yesUrl ?? _defaultSalesBoardLink();
    final resolvedNoUrl = noUrl ?? _defaultSalesBoardLink();

    final resolvedDescription =
        description ??
        'Customer ${appointment.customerName} confirmed a deposit. Please verify.';

    return _sendDepositEmail(
      templateId: _depositMarketingTemplateId,
      toEmail: resolvedEmail,
      toName: 'Marketing Team',
      templateParams: _buildDepositParams(
        appointment: appointment,
        yesUrl: resolvedYesUrl,
        noUrl: resolvedNoUrl,
        description: resolvedDescription,
        yesLabel: yesLabel ?? 'Open sales board',
        noLabel: noLabel ?? 'View appointment',
      ),
    );
  }

  /// Format date for email (e.g., "Wednesday, November 5, 2025")
  static String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  /// Format time for email (e.g., "10:00 AM")
  static String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  static Map<String, dynamic> _buildDepositParams({
    required sales_models.SalesAppointment appointment,
    required String yesUrl,
    required String noUrl,
    required String description,
    required String yesLabel,
    required String noLabel,
  }) {
    return {
      'customer_name': appointment.customerName,
      'customer_email': appointment.email,
      'customer_phone': appointment.phone,
      'appointment_id': appointment.id,
      'deposit_amount': appointment.depositAmount != null
          ? appointment.depositAmount!.toStringAsFixed(2)
          : 'N/A',
      'description': description,
      'yes_label': yesLabel,
      'no_label': noLabel,
      'yes_url': yesUrl,
      'no_url': noUrl,
    };
  }

  static Future<bool> _sendDepositEmail({
    required String templateId,
    required String toEmail,
    required String toName,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      debugPrint('📧 Sending deposit email via $templateId to $toEmail');

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': templateId,
          'user_id': _userId,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            ...templateParams,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Deposit email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send deposit email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending deposit email: $error');
      return false;
    }
  }

  static String _defaultSalesBoardLink() {
    final origin = Uri.base.origin.isNotEmpty
        ? Uri.base.origin
        : 'https://app.medwave.com';
    return Uri.parse(
      origin,
    ).replace(path: '/admin/streams/sales', queryParameters: {}).toString();
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
            'admin_dashboard_link':
                'http://localhost:52961/#/admin/approvals', // Local dev URL
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Practitioner registration notification sent successfully',
        );
        return true;
      } else {
        debugPrint(
          '❌ Failed to send practitioner registration notification: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint(
        '❌ Error sending practitioner registration notification: $error',
      );
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
      debugPrint(
        '📧 Sending practitioner approval email to $practitionerEmail',
      );

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
        debugPrint(
          '❌ Failed to send practitioner approval email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending practitioner approval email: $error');
      return false;
    }
  }
}
