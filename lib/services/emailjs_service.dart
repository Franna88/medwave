import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../models/streams/appointment.dart' as sales_models;
import '../models/streams/order.dart' as order_models;

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
  static const String _depositMarketingTemplateId = 'template_jykxsg3';
  static const String _contractLinkTemplateId = 'template_bdg4s33';
  // Installation booking template - dedicated template for installation date selection
  static const String _installationBookingTemplateId = 'template_fvu7nw2';
  // Out for delivery template - notifies customer with tracking and installer info
  static const String _outForDeliveryTemplateId = 'template_bvaj5t6';

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

  /// Send contract link email right after generation (Opt In flow)
  static Future<bool> sendContractLinkEmail({
    required sales_models.SalesAppointment appointment,
    required String contractUrl,
    String? websiteUrl,
  }) async {
    try {
      final resolvedWebsiteUrl = _resolveBaseOrigin(
        fallback: 'https://app.medwave.com',
      );
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      debugPrint(
        '📧 Sending contract link email to ${appointment.email} (template $_contractLinkTemplateId)',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _contractLinkTemplateId,
          'user_id': _userId,
          'template_params': {
            // EmailJS template uses "email" as the recipient field; include both
            // standard keys to avoid "recipient address is empty" errors.
            'email': appointment.email,
            'to_email': appointment.email,
            'to_name': appointment.customerName,
            'username': appointment.customerName,
            'contract_link': contractUrl,
            'website_link': websiteUrl ?? resolvedWebsiteUrl,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Contract link email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send contract link email (${response.statusCode}): ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending contract link email: $error');
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

  /// Friendly follow-up #1 (same template) asking for deposit confirmation
  static Future<bool> sendCustomerDepositFollowUp1({
    required sales_models.SalesAppointment appointment,
    required String yesUrl,
    required String noUrl,
  }) {
    return _sendDepositEmail(
      templateId: _depositCustomerTemplateId,
      toEmail: appointment.email,
      toName: appointment.customerName,
      templateParams: _buildDepositParams(
        appointment: appointment,
        yesUrl: yesUrl,
        noUrl: noUrl,
        description:
            'Friendly reminder: were you able to make the deposit to reserve your order?',
        yesLabel: 'Yes, deposit is paid',
        noLabel: 'Not yet, please assist',
      ),
    );
  }

  /// Friendly follow-up #2: shipped & locked notification + deposit check
  static Future<bool> sendCustomerDepositFollowUp2({
    required sales_models.SalesAppointment appointment,
    required String yesUrl,
    required String noUrl,
  }) {
    return _sendDepositEmail(
      templateId: _depositCustomerTemplateId,
      toEmail: appointment.email,
      toName: appointment.customerName,
      templateParams: _buildDepositParams(
        appointment: appointment,
        yesUrl: yesUrl,
        noUrl: noUrl,
        description:
            'Good news—your items are prepped and locked at our warehouse. Please confirm the deposit so we can ship.',
        yesLabel: 'Deposit is paid',
        noLabel: 'Not yet, I need help',
      ),
    );
  }

  /// Friendly follow-up #3: price increase warning + deposit check
  static Future<bool> sendCustomerDepositFollowUp3({
    required sales_models.SalesAppointment appointment,
    required String yesUrl,
    required String noUrl,
  }) {
    return _sendDepositEmail(
      templateId: _depositCustomerTemplateId,
      toEmail: appointment.email,
      toName: appointment.customerName,
      templateParams: _buildDepositParams(
        appointment: appointment,
        yesUrl: yesUrl,
        noUrl: noUrl,
        description:
            'Heads up: prices will increase soon. Confirm your deposit now to lock in your current quote.',
        yesLabel: 'Lock price with deposit',
        noLabel: 'Not yet, please hold',
      ),
    );
  }

  static Future<bool> sendMarketingDepositNotification({
    required sales_models.SalesAppointment appointment,
    String? marketingEmail,
    String? description,
    String? yesLabel,
    String? noLabel,
    String? yesUrl,
    String? noUrl,
  }) async {
    final resolvedEmail = marketingEmail ?? 'info@barefootbytes.com';
    final resolvedYesUrl = yesUrl ?? _defaultSalesBoardLink();
    final resolvedNoUrl = noUrl ?? _defaultSalesBoardLink();

    final resolvedDescription =
        description ??
        'Customer ${appointment.customerName} confirmed a deposit. Please verify.';

    return _sendDepositEmail(
      templateId: _depositMarketingTemplateId,
      toEmail: resolvedEmail,
      toName: 'Marketing Team',
      templateParams:
          _buildDepositParams(
              appointment: appointment,
              yesUrl: resolvedYesUrl,
              noUrl: resolvedNoUrl,
              description: resolvedDescription,
              yesLabel: yesLabel ?? 'Open sales board',
              noLabel: noLabel ?? 'View appointment',
            )
            ..['customer_email'] = resolvedEmail
            ..['customer_name'] = 'Finance Team',
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

  static String _resolveBaseOrigin({required String fallback}) {
    final runtimeOrigin = Uri.base.origin;
    return runtimeOrigin.isNotEmpty ? runtimeOrigin : fallback;
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

  /// Send installation booking email to customer
  /// Customer clicks the link to select 3 preferred installation dates
  static Future<bool> sendInstallationBookingEmail({
    required order_models.Order order,
    required String bookingUrl,
  }) async {
    // Use the same pattern as deposit emails for consistency
    return _sendDepositEmail(
      templateId: _installationBookingTemplateId,
      toEmail: order.email,
      toName: order.customerName,
      templateParams: {
        'customer_name': order.customerName,
        'customer_email': order.email,
        'customer_phone': order.phone,
        'appointment_id': order.id,
        'deposit_amount': 'N/A',
        'description':
            'Congratulations! Your order has been received. Please select your preferred installation dates by clicking the button below.',
        'yes_label': 'Select Installation Dates',
        'no_label': '',
        'yes_url': bookingUrl,
        'no_url': bookingUrl,
      },
    );
  }

  /// Send out for delivery email to customer
  /// Notifies customer that parcel is on the way with tracking number and installer details
  static Future<bool> sendOutForDeliveryEmail({
    required order_models.Order order,
  }) async {
    try {
      debugPrint(
        '📧 Sending out for delivery email to ${order.email}',
      );

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _outForDeliveryTemplateId,
          'user_id': _userId,
          'template_params': {
            'to_email': order.email,
            'to_name': order.customerName,
            'email': order.email, // Some templates use 'email' as recipient
            'customer_name': order.customerName,
            'tracking_number': order.trackingNumber ?? 'Not available',
            'installer_name': order.assignedInstallerName ?? 'To be assigned',
            'installer_phone': order.assignedInstallerPhone ?? 'Not available',
            'installer_email': order.assignedInstallerEmail ?? 'Not available',
            'description':
                'Great news! Your parcel is on the way. Below are your tracking details and installer information.',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Out for delivery email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send out for delivery email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending out for delivery email: $error');
      return false;
    }
  }
}
