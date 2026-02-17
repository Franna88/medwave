import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // static const String _serviceId = 'service_lg9tf22';
  static const String _serviceId = 'service_itl4rns';
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
  static const String _paymentCustomerTemplateId = 'template_10g88s2';
  static const String _contractLinkTemplateId = 'template_bdg4s33';
  // Installation booking template - dedicated template for installation date selection
  static const String _installationBookingTemplateId = 'template_fvu7nw2';
  // Out for delivery template - notifies customer with tracking and installer info
  static const String _outForDeliveryTemplateId = 'template_bvaj5t6';
  // Priority order template - notifies admin when full payment order is created
  static const String _priorityOrderTemplateId = 'template_4iqsrt3';
  // Invoice template - sends invoice to customer with download link
  static const String _invoiceTemplateId = 'template_g8i6vvl';
  // Thank you email template - sent to customer after finance confirms payment
  static const String _thankYouPaymentTemplateId = 'template_zih8yg9';
  // Internal lead notification template - sent to finance and sales team when contract is generated
  static const String _internalLeadNotificationTemplateId = 'template_xonvsxf';
  // Installation signoff template - sent to customer to sign acknowledgment of receipt
  static const String _installationSignoffTemplateId = 'template_vc3mf08';
  // Contract sent notification - sent only to BCC list when contract link email is sent to client
  static const String _contractSentNotificationTemplateId = 'template_y067fcc';
  // Contract signed notification - sent only to BCC list when client signs the contract
  static const String _contractSignedNotificationTemplateId =
      'template_vbo4xef';
  // Deposit confirmed notification - sent only to BCC list when ticket reaches deposit_made
  static const String _contractDepositConfirmedNotificationTemplateId =
      'template_2ngaebm';
  // Deposit confirmed welcome email - sent to customer when deposit is confirmed (finance/sales)
  static const String _depositConfirmedWelcomeTemplateId = 'template_kxndxus';
  // Lead transitioned to operations - sent to operations team when appointment is converted to order (recipient hardcoded in EmailJS template)
  static const String _leadTransitionedToOperationsTemplateId =
      'template_6bij9vg';

  // Admin email for notifications
  static const String _adminEmail =
      'info@barefootbytes.com'; // TODO: Update with actual superadmin email

  // BCC list: Previously used for Contract Sent, Contract Signed, and Deposit Confirmed notifications.
  // BCC recipients are now configured directly in the EmailJS template, so this constant is no longer used.
  // Kept for reference - these were the emails previously used:
  // static const String _bccEmailList =
  //     'info@barefootbytes.com; elmienphysio@medwavegroup.com; andries@medwavegroup.com; davide@medwavegroup.com; francois@medwavegroup.com';
  // static const String _bccEmailList =
  //     'tertiusvawork@gmail.com; tertiusva@gmail.com';

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

  /// Result of sending contract link email. [errorMessage] is a short user-facing reason when [success] is false (max ~80 chars).
  static const int _maxErrorMessageLength = 80;

  static String _shortSendError(int statusCode, String body) {
    final short = body.length > 120 ? '${body.substring(0, 120)}…' : body;
    if (statusCode == 400) return 'Invalid or missing email';
    if (statusCode == 413) return 'Payload too large';
    if (statusCode >= 500) return 'Server error';
    if (short.toLowerCase().contains('variable') &&
        short.toLowerCase().contains('limit'))
      return 'Variables size limit exceeded';
    if (short.toLowerCase().contains('email'))
      return short.length > _maxErrorMessageLength
          ? short.substring(0, _maxErrorMessageLength)
          : short;
    return short.length > _maxErrorMessageLength
        ? short.substring(0, _maxErrorMessageLength)
        : short;
  }

  /// Send contract link email right after generation (Opt In flow).
  /// Returns (success: true, errorMessage: null) on success, or (success: false, errorMessage: short reason) on failure.
  static Future<({bool success, String? errorMessage})> sendContractLinkEmail({
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
        return (success: true, errorMessage: null);
      } else {
        final reason = _shortSendError(response.statusCode, response.body);
        debugPrint(
          '❌ Failed to send contract link email (${response.statusCode}): ${response.body}',
        );
        return (success: false, errorMessage: reason);
      }
    } catch (error) {
      debugPrint('❌ Error sending contract link email: $error');
      final msg = error.toString();
      final reason = msg.length > _maxErrorMessageLength
          ? msg.substring(0, _maxErrorMessageLength)
          : msg;
      return (success: false, errorMessage: reason);
    }
  }

  /// Send "Contract Sent" notification to the BCC list (no customer recipient).
  /// Call after successfully sending the contract link email to the client.
  /// EmailJS template: BCC recipients are configured directly in the template. No recipient variables needed.
  /// If [contractDownloadUrl] is provided, it is sent as {{contract_download_url}} (link to PDF; avoids EmailJS 50KB variable limit).
  static Future<bool> sendContractSentNotificationToBcc({
    required String contractId,
    required String customerName,
    required DateTime contractSentDate,
    String? contractDownloadUrl,
  }) async {
    try {
      debugPrint(
        '📧 Sending contract sent notification (template $_contractSentNotificationTemplateId)',
      );

      const int emailJsMaxVariablesBytes = 50 * 1024; // 50KB
      const int safeLimitBytes = 45 * 1024; // leave margin

      final templateParams = <String, dynamic>{
        'customer_name': customerName,
        'contract_id': contractId,
        'contract_sent_date': DateFormat(
          'MMMM dd, yyyy',
        ).format(contractSentDate),
      };
      if (contractDownloadUrl != null && contractDownloadUrl.isNotEmpty) {
        templateParams['contract_download_url'] = contractDownloadUrl;
      }

      // Ensure we never exceed EmailJS 50KB variables limit (omit optional URL if needed)
      final paramsJson = json.encode(templateParams);
      final paramsBytes = paramsJson.length;
      if (paramsBytes > safeLimitBytes) {
        if (templateParams.containsKey('contract_download_url')) {
          templateParams.remove('contract_download_url');
          final retryJson = json.encode(templateParams);
          if (retryJson.length > emailJsMaxVariablesBytes) {
            debugPrint(
              '⚠️ Contract sent BCC: template_params still too large (${retryJson.length} bytes) after removing URL. Check other fields.',
            );
          } else {
            debugPrint(
              '⚠️ Contract sent BCC: params were ${paramsBytes} bytes; sending without contract_download_url to stay under 50KB.',
            );
          }
        }
      }
      final body = {
        'service_id': _serviceId,
        'template_id': _contractSentNotificationTemplateId,
        'user_id': _userId,
        'template_params': templateParams,
      };
      debugPrint(
        '📧 Contract sent BCC request size: ${(json.encode(body).length / 1024).toStringAsFixed(1)} KB',
      );

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Contract sent notification (BCC) sent successfully',
        );
        return true;
      } else {
        debugPrint(
          '❌ Contract sent notification failed: ${response.statusCode} body=${response.body}',
        );
        return false;
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Error sending contract sent notification: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  /// Send "Contract Signed" notification to the BCC list (no customer recipient).
  /// Call after the client signs the contract.
  /// EmailJS template: BCC recipients are configured directly in the template. No recipient variables needed.
  static Future<bool> sendContractSignedNotificationToBcc({
    required String contractId,
    required String customerName,
    required DateTime contractSignedDate,
  }) async {
    try {
      debugPrint(
        '📧 Sending contract signed notification (template $_contractSignedNotificationTemplateId)',
      );

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _contractSignedNotificationTemplateId,
          'user_id': _userId,
          'template_params': {
            'customer_name': customerName,
            'contract_id': contractId,
            'contract_signed_date': DateFormat(
              'MMMM dd, yyyy',
            ).format(contractSignedDate),
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Contract signed notification (BCC) sent successfully',
        );
        return true;
      } else {
        debugPrint(
          '❌ Contract signed notification failed: ${response.statusCode} body=${response.body}',
        );
        return false;
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Error sending contract signed notification: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  /// Send "Deposit Confirmed" notification to the BCC list when ticket reaches deposit_made.
  /// EmailJS template: BCC recipients are configured directly in the template. No recipient variables needed.
  static Future<bool> sendDepositConfirmedNotificationToBcc({
    required String contractId,
    required String customerName,
    required DateTime depositConfirmedDate,
  }) async {
    try {
      debugPrint(
        '📧 Sending deposit confirmed notification (template $_contractDepositConfirmedNotificationTemplateId)',
      );

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _contractDepositConfirmedNotificationTemplateId,
          'user_id': _userId,
          'template_params': {
            'customer_name': customerName,
            'contract_id': contractId,
            'deposit_confirmed_date': DateFormat(
              'MMMM dd, yyyy',
            ).format(depositConfirmedDate),
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Deposit confirmed notification (BCC) sent successfully',
        );
        return true;
      } else {
        debugPrint(
          '❌ Deposit confirmed notification failed: ${response.statusCode} body=${response.body}',
        );
        return false;
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Error sending deposit confirmed notification: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  /// Send deposit-confirmed welcome email to the customer (template_kxndxus).
  /// Called when deposit is confirmed via finance approval or sales upload/verification.
  static Future<bool> sendDepositConfirmedWelcomeToCustomer({
    required String toEmail,
    required String clientName,
  }) async {
    try {
      debugPrint(
        '📧 Sending deposit confirmed welcome email to $toEmail (template $_depositConfirmedWelcomeTemplateId)',
      );
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _depositConfirmedWelcomeTemplateId,
          'user_id': _userId,
          'template_params': {
            'client_name': clientName,
            'email': toEmail,
            'to_email': toEmail,
            'to_name': clientName,
          },
        }),
      );
      if (response.statusCode == 200) {
        debugPrint(
          '✅ Deposit confirmed welcome email sent successfully to $toEmail',
        );
        return true;
      } else {
        debugPrint(
          '❌ Deposit confirmed welcome email failed: ${response.statusCode} body=${response.body} to=$toEmail',
        );
        return false;
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Error sending deposit confirmed welcome email: $error');
      debugPrint('$stackTrace');
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
    String? contractViewUrl,
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
        contractViewUrl: contractViewUrl,
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
    final resolvedEmail = marketingEmail ?? 'tertiusva@gmail';
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
    String? contractViewUrl,
  }) {
    // Calculate deposit amount: use stored depositAmount, or calculate 10% of total if not set
    double calculatedAmount = 0;
    if (appointment.depositAmount != null) {
      calculatedAmount = appointment.depositAmount!;
    } else if (appointment.optInProducts.isNotEmpty) {
      // Calculate 10% deposit from optInProducts total (multiply price by quantity)
      final total = appointment.optInProducts.fold<double>(
        0,
        (sum, p) => sum + (p.price * p.quantity),
      );
      calculatedAmount = total * 0.10; // 10% deposit
    }

    return {
      'customer_name': appointment.customerName,
      'customer_email': appointment.email,
      'customer_phone': appointment.phone,
      'appointment_id': appointment.id,
      // Template likely already includes "R" prefix, so just send the number
      'deposit_amount': calculatedAmount > 0
          ? calculatedAmount.toStringAsFixed(2)
          : 'N/A',
      'description': description,
      'yes_label': yesLabel,
      'no_label': noLabel,
      'yes_url': yesUrl,
      'no_url': noUrl,
      if (contractViewUrl != null && contractViewUrl.isNotEmpty)
        'contract_view_url': contractViewUrl,
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
            ...templateParams,
            // EmailJS template uses "email" and potentially "customer_email" as recipient fields.
            // Include both standard keys to avoid "recipient address is empty" errors.
            // Set these AFTER templateParams to ensure recipient is always correct.
            'email': toEmail,
            'to_email': toEmail,
            'to_name': toName,
            // If templateParams contains customer_email (for finance notifications),
            // ensure it's set to the finance email (toEmail) to override any customer email value.
            // The cascade operator in sendFinancePaymentNotification should handle this,
            // but we set it here as a final override to be safe.
            if (templateParams.containsKey('customer_email'))
              'customer_email': toEmail,
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

  /// Send customer-facing payment request (Yes/No) for remaining balance
  static Future<bool> sendCustomerPaymentRequest({
    required order_models.Order order,
    required String yesUrl,
    required String noUrl,
    required double remainingPaymentAmount,
    String? description,
    String? yesLabel,
    String? noLabel,
  }) async {
    final amountText = remainingPaymentAmount > 0
        ? remainingPaymentAmount.toStringAsFixed(2)
        : 'N/A';
    final resolvedDescription =
        description ??
        'Have you paid the remaining balance${amountText != 'N/A' ? ' of R $amountText' : ''}?';

    return _sendPaymentEmail(
      templateId: _paymentCustomerTemplateId,
      toEmail: order.email,
      toName: order.customerName,
      templateParams: _buildPaymentParams(
        order: order,
        yesUrl: yesUrl,
        noUrl: noUrl,
        remainingPaymentAmount: remainingPaymentAmount,
        description: resolvedDescription,
        yesLabel: yesLabel ?? 'Yes, I made the payment',
        noLabel: noLabel ?? 'No, not yet',
      ),
    );
  }

  /// Send finance department notification when customer confirms payment
  static Future<bool> sendFinancePaymentNotification({
    required order_models.Order order,
    String? financeEmail,
    String? description,
    String? yesLabel,
    String? noLabel,
    String? yesUrl,
    String? noUrl,
  }) async {
    // Reuse the same email as marketing team (finance department)
    // final resolvedEmail = financeEmail ?? 'tertiusva@gmail.com';
    final resolvedEmail = financeEmail ?? 'rachel@medwavegroup.com';
    final resolvedYesUrl = yesUrl ?? _defaultOperationsBoardLink();
    final resolvedNoUrl = noUrl ?? _defaultOperationsBoardLink();

    final resolvedDescription =
        description ??
        'Customer ${order.customerName} confirmed payment. Please verify.';

    // Calculate total invoice from order items (with quantities)
    final totalInvoice = order.items.fold<double>(
      0,
      (sum, item) => sum + ((item.price ?? 0) * item.quantity),
    );

    // Calculate deposit amount from appointment optInProducts (with quantities)
    // This ensures the deposit matches what was calculated in the contract/invoice
    double depositAmount = 0;
    try {
      if (order.appointmentId.isNotEmpty) {
        final firestore = FirebaseFirestore.instance;
        final appointmentDoc = await firestore
            .collection('appointments')
            .doc(order.appointmentId)
            .get();

        if (appointmentDoc.exists) {
          final appointmentData = appointmentDoc.data();
          if (appointmentData != null) {
            // Get stored deposit amount first
            final storedDeposit = appointmentData['depositAmount'];
            if (storedDeposit != null) {
              depositAmount = (storedDeposit as num).toDouble();
            } else {
              // Calculate 10% of total from optInProducts if deposit not stored
              final optInProducts =
                  appointmentData['optInProducts'] as List<dynamic>?;
              if (optInProducts != null && optInProducts.isNotEmpty) {
                double total = 0;
                for (final product in optInProducts) {
                  if (product is Map<String, dynamic>) {
                    final price = product['price'];
                    final quantity =
                        product['quantity'] ?? 1; // Default to 1 if not set
                    if (price != null) {
                      total += (price as num).toDouble() * quantity;
                    }
                  }
                }
                depositAmount = total * 0.10; // 10% deposit
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching appointment for deposit amount: $e');
      }
      // Fallback: calculate from order items if appointment fetch fails
      depositAmount = totalInvoice * 0.10; // 10% deposit as fallback
    }

    // Calculate remaining balance (what customer needs to pay for final payment)
    // Cap deposit at total to prevent negative amounts
    final cappedDepositAmount = depositAmount > totalInvoice
        ? totalInvoice
        : depositAmount;
    final remainingBalance = max(0.0, totalInvoice - cappedDepositAmount);

    // Build template params - the template uses customer_email as the recipient field,
    // so we must set it to the finance email address, not the customer's email
    final templateParams = {
      'customer_name': order.customerName,
      'customer_email':
          resolvedEmail, // Set to finance email (template uses this as recipient)
      'customer_phone': order.phone,
      'appointment_id':
          order.id, // Use order.id as appointment_id for template compatibility
      'deposit_amount': remainingBalance > 0
          ? remainingBalance.toStringAsFixed(2)
          : 'N/A',
      'description': resolvedDescription,
      'yes_label': yesLabel ?? 'Open operations board',
      'no_label': noLabel ?? 'View order',
      'yes_url': resolvedYesUrl,
      'no_url': resolvedNoUrl,
    };

    return _sendDepositEmail(
      templateId: _depositMarketingTemplateId,
      toEmail: resolvedEmail,
      toName: 'Finance Team',
      templateParams: templateParams,
    );
  }

  static Map<String, dynamic> _buildPaymentParams({
    required order_models.Order order,
    required String yesUrl,
    required String noUrl,
    required double remainingPaymentAmount,
    required String description,
    required String yesLabel,
    required String noLabel,
  }) {
    // Calculate total invoice from order items
    final totalInvoice = order.items.fold<double>(
      0,
      (sum, item) => sum + ((item.price ?? 0) * item.quantity),
    );

    return {
      'customer_name': order.customerName,
      'customer_email': order.email,
      'customer_phone': order.phone,
      'order_id': order.id,
      'remaining_payment_amount': remainingPaymentAmount > 0
          ? 'R ${remainingPaymentAmount.toStringAsFixed(2)}'
          : 'N/A',
      'total_invoice_amount': totalInvoice > 0
          ? 'R ${totalInvoice.toStringAsFixed(2)}'
          : 'N/A',
      'description': description,
      'yes_label': yesLabel,
      'no_label': noLabel,
      'yes_url': yesUrl,
      'no_url': noUrl,
    };
  }

  static Future<bool> _sendPaymentEmail({
    required String templateId,
    required String toEmail,
    required String toName,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      debugPrint('📧 Sending payment email via $templateId to $toEmail');

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
        debugPrint('✅ Payment email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send payment email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending payment email: $error');
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

  static String _defaultOperationsBoardLink() {
    final origin = Uri.base.origin.isNotEmpty
        ? Uri.base.origin
        : 'https://app.medwave.com';
    return Uri.parse(origin)
        .replace(path: '/admin/streams/operations', queryParameters: {})
        .toString();
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
      debugPrint('📧 Sending out for delivery email to ${order.email}');

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _outForDeliveryTemplateId,
          'user_id': _userId,
          'template_params': {
            'customer_email':
                order.email, // Template uses {{customer_email}} for recipient
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
        debugPrint('❌ Failed to send out for delivery email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending out for delivery email: $error');
      return false;
    }
  }

  /// Send installation signoff email to customer
  /// Customer clicks the link to sign acknowledgment of receipt
  static Future<bool> sendInstallationSignoffEmail({
    required order_models.Order order,
    required String acknowledgementLink,
  }) async {
    try {
      // Validate email address
      if (order.email.isEmpty) {
        debugPrint(
          '❌ Cannot send installation signoff email: order email is empty',
        );
        return false;
      }

      debugPrint('📧 Sending installation signoff email to ${order.email}');

      // Build full URL if needed
      String fullUrl = acknowledgementLink;
      if (!acknowledgementLink.startsWith('http')) {
        // If relative path, make it full URL
        if (kIsWeb) {
          final baseUrl = Uri.base.origin;
          fullUrl = '$baseUrl$acknowledgementLink';
        } else {
          // For mobile, use configurable base URL
          fullUrl = 'https://yourdomain.com$acknowledgementLink';
        }
      }

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _installationSignoffTemplateId,
          'user_id': _userId,
          'template_params': {
            // EmailJS template recipient fields - include multiple to ensure compatibility
            'email': order.email,
            'customer_email': order.email,
            'to_email': order.email,
            'username': order.customerName,
            'acknowledgement_link': fullUrl,
            'website_link': 'https://www.medwavegroup.com', // Or from config
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Installation signoff email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send installation signoff email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending installation signoff email: $error');
      return false;
    }
  }

  /// Send priority order notification to admin when a full payment order is created
  /// This notifies the admin that a priority order needs installation scheduling
  static Future<bool> sendPriorityOrderNotification({
    required order_models.Order order,
    String? adminEmail,
  }) async {
    try {
      final resolvedAdminEmail = adminEmail ?? _adminEmail;
      debugPrint(
        '📧 Sending priority order notification to $resolvedAdminEmail',
      );

      // Build products list string
      final productsList = order.items
          .map((item) => '• ${item.name} (Qty: ${item.quantity})')
          .join('\n');

      // Calculate total amount
      final totalAmount = order.items.fold<double>(
        0,
        (sum, item) => sum + (item.price ?? 0) * item.quantity,
      );

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _priorityOrderTemplateId,
          'user_id': _userId,
          'template_params': {
            'admin_email': resolvedAdminEmail,
            'customer_name': order.customerName,
            'customer_email': order.email,
            'customer_phone': order.phone,
            'order_id': order.id,
            'products_list': productsList,
            'total_amount': 'R ${totalAmount.toStringAsFixed(2)}',
            'order_date': order.orderDate != null
                ? DateFormat('EEEE, MMMM d, yyyy').format(order.orderDate!)
                : 'N/A',
            'description':
                'A PRIORITY ORDER has been placed. This customer paid in full and should receive installation priority.',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Priority order notification email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send priority order notification email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending priority order notification email: $error');
      return false;
    }
  }

  /// Send invoice email to customer with invoice link and PDF
  static Future<bool> sendInvoiceEmail({
    required order_models.Order order,
    required String invoiceLink,
    String? websiteLink,
    String? invoicePdfUrl,
    double? invoiceAmount,
  }) async {
    try {
      debugPrint('📧 Sending invoice email to ${order.email}');

      // Calculate invoice amount if not provided
      final calculatedInvoiceAmount =
          invoiceAmount ??
          order.items.fold<double>(
            0,
            (sum, item) => sum + ((item.price ?? 0) * item.quantity),
          );

      final resolvedWebsiteLink =
          websiteLink ??
          _resolveBaseOrigin(fallback: 'https://app.medwave.com');

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _invoiceTemplateId,
          'user_id': _userId,
          'template_params': {
            // EmailJS template uses "email" as the recipient field; include both
            // standard keys to avoid "recipient address is empty" errors.
            'email': order.email,
            'to_email': order.email,
            'to_name': order.customerName,
            'username': order.customerName,
            'invoice_number': order.invoiceNumber ?? 'N/A',
            'invoice_amount':
                'R ${max(0.0, calculatedInvoiceAmount).toStringAsFixed(2)}',
            'invoice_link': invoiceLink,
            'invoice_pdf_url': invoicePdfUrl ?? '',
            'website_link': resolvedWebsiteLink,
            // Waybill photo from warehouse app (empty if not set) – template can show when present
            'waybill_photo_url': order.waybillPhotoUrl ?? '',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Invoice email sent successfully');
        if (invoicePdfUrl != null) {
          debugPrint('   PDF URL included: $invoicePdfUrl');
        }
        return true;
      } else {
        debugPrint('❌ Failed to send invoice email: ${response.body}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending invoice email: $error');
      return false;
    }
  }

  /// Send thank you email to customer after finance confirms payment
  static Future<bool> sendThankYouPaymentEmail({
    required order_models.Order order,
    String? supportUrl,
  }) async {
    try {
      // Validate email address
      if (order.email.isEmpty) {
        debugPrint('❌ Cannot send thank you email: order email is empty');
        return false;
      }

      debugPrint('📧 Sending thank you payment email to ${order.email}');
      debugPrint('📧 Order ID: ${order.id}, Customer: ${order.customerName}');

      // Calculate total invoice from order items
      final totalInvoice = order.items.fold<double>(
        0,
        (sum, item) => sum + ((item.price ?? 0) * item.quantity),
      );

      final resolvedSupportUrl =
          supportUrl ?? _resolveBaseOrigin(fallback: 'https://app.medwave.com');

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _thankYouPaymentTemplateId,
          'user_id': _userId,
          'template_params': {
            // EmailJS template recipient fields - include multiple to ensure compatibility
            // The template configuration in EmailJS dashboard determines which field is used
            'email': order.email,
            'to_email': order.email,
            'to_name': order.customerName,
            'reply_to': order.email,
            'from_email': order.email,
            'user_email': order.email,
            'customer_email': order.email,
            // Template content variables
            'username': order.customerName,
            'customer_name': order.customerName,
            'order_id': order.id,
            'total_invoice_amount': totalInvoice > 0
                ? 'R ${totalInvoice.toStringAsFixed(2)}'
                : 'N/A',
            'support_url': resolvedSupportUrl,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Thank you payment email sent successfully');
        return true;
      } else {
        debugPrint(
          '❌ Failed to send thank you payment email: ${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error sending thank you payment email: $error');
      return false;
    }
  }

  /// Format lead and customer details as HTML detail rows
  static String _formatLeadCustomerDetails(
    sales_models.SalesAppointment appointment,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      '<div class="detail-row"><strong>Lead ID:</strong> ${appointment.leadId}</div>',
    );
    buffer.writeln(
      '<div class="detail-row"><strong>Customer Name:</strong> ${appointment.customerName}</div>',
    );
    buffer.writeln(
      '<div class="detail-row"><strong>Email:</strong> ${appointment.email}</div>',
    );
    buffer.writeln(
      '<div class="detail-row"><strong>Phone:</strong> ${appointment.phone}</div>',
    );
    return buffer.toString();
  }

  /// Format date and contact details as HTML detail rows
  static String _formatDateContactDetails(
    sales_models.SalesAppointment appointment,
  ) {
    final buffer = StringBuffer();
    if (appointment.appointmentDate != null) {
      final dateStr = DateFormat(
        'yyyy-MM-dd',
      ).format(appointment.appointmentDate!);
      buffer.writeln(
        '<div class="detail-row"><strong>Appointment Date:</strong> $dateStr</div>',
      );
    }
    if (appointment.appointmentTime != null &&
        appointment.appointmentTime!.isNotEmpty) {
      buffer.writeln(
        '<div class="detail-row"><strong>Appointment Time:</strong> ${appointment.appointmentTime}</div>',
      );
    }
    buffer.writeln(
      '<div class="detail-row"><strong>Customer Email:</strong> ${appointment.email}</div>',
    );
    buffer.writeln(
      '<div class="detail-row"><strong>Customer Phone:</strong> ${appointment.phone}</div>',
    );
    return buffer.toString();
  }

  /// Format selected items as HTML formatted list
  static String _formatSelectedItems(
    sales_models.SalesAppointment appointment,
  ) {
    if (appointment.optInProducts.isEmpty) {
      return '<div class="detail-row">No items selected</div>';
    }
    final buffer = StringBuffer();
    for (final product in appointment.optInProducts) {
      buffer.writeln(
        '<div class="detail-row"><strong>${product.name}:</strong> R ${product.price.toStringAsFixed(2)}</div>',
      );
    }
    return buffer.toString();
  }

  /// Format opt-in questions and answers as HTML key-value pairs
  static String _formatOptInQuestions(
    sales_models.SalesAppointment appointment,
  ) {
    if (appointment.optInQuestions == null ||
        appointment.optInQuestions!.isEmpty) {
      return '<div class="detail-row">No opt-in questions answered</div>';
    }
    final buffer = StringBuffer();
    appointment.optInQuestions!.forEach((key, value) {
      buffer.writeln(
        '<div class="detail-row"><strong>$key:</strong> $value</div>',
      );
    });
    return buffer.toString();
  }

  /// Send internal lead notification email to finance and sales team
  /// This email is sent when a contract is generated in the sales stream
  static Future<bool> sendInternalLeadNotification({
    required sales_models.SalesAppointment appointment,
  }) async {
    try {
      // Format all template placeholders
      final leadCustomerDetails = _formatLeadCustomerDetails(appointment);
      final dateContactDetails = _formatDateContactDetails(appointment);
      final salesAgent =
          appointment.assignedToName ??
          appointment.createdByName ??
          'Not assigned';
      final selectedItems = _formatSelectedItems(appointment);
      final optInQuestions = _formatOptInQuestions(appointment);

      // Hardcoded recipient emails
      const recipients = ['francois@medwavegroup.com', 'info@medwavegroup.com'];

      // Send to both recipients (EmailJS supports single recipient per call)
      bool atLeastOneSuccess = false;
      for (final recipient in recipients) {
        try {
          final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'service_id': _serviceId,
              'template_id': _internalLeadNotificationTemplateId,
              'user_id': _userId,
              'template_params': {
                'email': recipient,
                'to_email': recipient,
                'admin_email':
                    recipient, // Template uses {{admin_email}} as recipient field
                'lead_customer_details': leadCustomerDetails,
                'date_contact_details': dateContactDetails,
                'sales_agent': salesAgent,
                'selected_items': selectedItems,
                'opt_in_questions': optInQuestions,
              },
            }),
          );

          if (response.statusCode == 200) {
            debugPrint('✅ Internal lead notification sent to $recipient');
            atLeastOneSuccess = true;
          } else {
            debugPrint(
              '❌ Failed to send internal lead notification to $recipient: ${response.body}',
            );
          }
        } catch (error) {
          debugPrint(
            '❌ Error sending internal lead notification to $recipient: $error',
          );
        }
      }

      return atLeastOneSuccess;
    } catch (error) {
      debugPrint('❌ Error in sendInternalLeadNotification: $error');
      return false;
    }
  }

  /// Send lead transitioned to operations notification to the operations team.
  /// This email is sent when an appointment is moved to Send to Operations (converted to order).
  /// Recipient is hardcoded in the EmailJS template (template_6bij9vg) send-to-mail config.
  static Future<bool> sendLeadTransitionedToOperationsNotification({
    required sales_models.SalesAppointment appointment,
  }) async {
    try {
      final leadCustomerDetails = _formatLeadCustomerDetails(appointment);
      final dateContactDetails = _formatDateContactDetails(appointment);
      final salesAgent =
          appointment.assignedToName ??
          appointment.createdByName ??
          'Not assigned';
      final selectedItems = _formatSelectedItems(appointment);
      final optInQuestions = _formatOptInQuestions(appointment);

      debugPrint(
        '📧 Sending lead transitioned to operations notification (template $_leadTransitionedToOperationsTemplateId)',
      );
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _leadTransitionedToOperationsTemplateId,
          'user_id': _userId,
          'template_params': {
            'lead_customer_details': leadCustomerDetails,
            'date_contact_details': dateContactDetails,
            'sales_agent': salesAgent,
            'selected_items': selectedItems,
            'opt_in_questions': optInQuestions,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(
          '✅ Lead transitioned to operations notification sent successfully',
        );
        return true;
      } else {
        debugPrint(
          '❌ Lead transitioned to operations notification failed: ${response.statusCode} body=${response.body}',
        );
        return false;
      }
    } catch (error) {
      debugPrint(
        '❌ Error in sendLeadTransitionedToOperationsNotification: $error',
      );
      return false;
    }
  }
}
