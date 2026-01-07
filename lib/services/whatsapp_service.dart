import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// WhatsApp Cloud API Service for sending notifications via Meta's Graph API
///
/// Uses WhatsApp Business Cloud API to send template messages directly from Flutter app.
/// Template messages must be pre-approved in Facebook Business Manager before use.
///
/// Setup Requirements:
/// 1. Create a Meta Developer account and app at https://developers.facebook.com/
/// 2. Add WhatsApp product to your app
/// 3. Set up a WhatsApp Business Account
/// 4. Get your Phone Number ID and Access Token from WhatsApp > API Setup
/// 5. Create and submit message templates for approval in Business Manager
class WhatsAppService {
  // ============================================================
  // WhatsApp Cloud API Configuration
  // ============================================================
  
  // TODO: Replace with your actual WhatsApp Cloud API credentials
  // Get these from: https://developers.facebook.com/ > Your App > WhatsApp > API Setup
  static const String _accessToken = 'YOUR_WHATSAPP_ACCESS_TOKEN';
  static const String _phoneNumberId = 'YOUR_PHONE_NUMBER_ID';
  static const String _apiVersion = 'v18.0';
  
  // Base URL for Meta Graph API
  static const String _baseUrl = 'https://graph.facebook.com';
  
  // ============================================================
  // Message Template IDs
  // ============================================================
  // These template names must match exactly what you create in Facebook Business Manager
  // Templates must be approved before they can be used
  
  /// Template for installation booking reminder
  /// Message: "Hi {{1}}, we've sent you an email with a link to schedule your 
  /// installation date. Please check your inbox and select your preferred dates. - MedWave Team"
  static const String _installationBookingTemplateId = 'installation_booking_reminder';
  
  /// Template for out for delivery notification (future use)
  static const String _outForDeliveryTemplateId = 'out_for_delivery';
  
  /// Template for deposit confirmation reminder (future use)
  static const String _depositReminderTemplateId = 'deposit_reminder';

  // ============================================================
  // Phone Number Formatting
  // ============================================================
  
  /// Format phone number for WhatsApp API
  /// WhatsApp requires numbers in international format without the + sign
  /// Examples:
  ///   "+27 82 123 4567" -> "27821234567"
  ///   "082 123 4567" -> "27821234567" (assumes South Africa)
  ///   "27821234567" -> "27821234567"
  static String formatPhoneNumber(String phone, {String defaultCountryCode = '27'}) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 0, replace with country code (South Africa default)
    if (cleaned.startsWith('0')) {
      cleaned = defaultCountryCode + cleaned.substring(1);
    }
    
    // If too short, it might be missing country code
    if (cleaned.length < 10) {
      debugPrint('⚠️ WhatsApp: Phone number may be invalid: $phone -> $cleaned');
    }
    
    return cleaned;
  }

  // ============================================================
  // Core API Method
  // ============================================================
  
  /// Send a template message via WhatsApp Cloud API
  /// 
  /// [to] - Recipient phone number (will be formatted)
  /// [templateName] - Name of the approved template in Business Manager
  /// [languageCode] - Template language code (default: en_US)
  /// [components] - Template components (header, body, buttons with parameters)
  static Future<WhatsAppResult> _sendTemplateMessage({
    required String to,
    required String templateName,
    String languageCode = 'en_US',
    List<Map<String, dynamic>>? components,
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(to);
      
      debugPrint('📱 WhatsApp: Sending template "$templateName" to $formattedPhone');
      
      final url = Uri.parse('$_baseUrl/$_apiVersion/$_phoneNumberId/messages');
      
      final body = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': formattedPhone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {
            'code': languageCode,
          },
          if (components != null && components.isNotEmpty)
            'components': components,
        },
      };
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final messageId = responseData['messages']?[0]?['id'] ?? 'unknown';
        
        debugPrint('✅ WhatsApp: Message sent successfully (ID: $messageId)');
        
        return WhatsAppResult(
          success: true,
          messageId: messageId,
          message: 'Message sent successfully',
        );
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        final errorCode = errorBody['error']?['code']?.toString() ?? 'unknown';
        
        debugPrint('❌ WhatsApp: Failed to send message');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Error Code: $errorCode');
        debugPrint('   Error: $errorMessage');
        
        return WhatsAppResult(
          success: false,
          message: 'Failed to send: $errorMessage (Code: $errorCode)',
        );
      }
    } catch (e) {
      debugPrint('❌ WhatsApp: Exception sending message: $e');
      
      return WhatsAppResult(
        success: false,
        message: 'Exception: $e',
      );
    }
  }

  // ============================================================
  // Public Methods - Installation Booking
  // ============================================================
  
  /// Send installation booking reminder via WhatsApp
  /// 
  /// Notifies the customer that they have received an email to schedule
  /// their installation date.
  /// 
  /// Template message example:
  /// "Hi {customerName}, we've sent you an email with a link to schedule your 
  /// installation date. Please check your inbox and select your preferred dates. - MedWave Team"
  static Future<WhatsAppResult> sendInstallationBookingReminder({
    required String customerPhone,
    required String customerName,
  }) async {
    // Build template components with the customer name parameter
    final components = [
      {
        'type': 'body',
        'parameters': [
          {
            'type': 'text',
            'text': customerName,
          },
        ],
      },
    ];
    
    return _sendTemplateMessage(
      to: customerPhone,
      templateName: _installationBookingTemplateId,
      components: components,
    );
  }

  // ============================================================
  // Public Methods - Out for Delivery (Future Use)
  // ============================================================
  
  /// Send out for delivery notification via WhatsApp
  /// 
  /// Notifies the customer that their order is on the way with tracking info.
  static Future<WhatsAppResult> sendOutForDeliveryNotification({
    required String customerPhone,
    required String customerName,
    required String trackingNumber,
    String? installerName,
    String? installerPhone,
  }) async {
    final components = [
      {
        'type': 'body',
        'parameters': [
          {'type': 'text', 'text': customerName},
          {'type': 'text', 'text': trackingNumber},
          {'type': 'text', 'text': installerName ?? 'Your installer'},
          {'type': 'text', 'text': installerPhone ?? 'Contact support'},
        ],
      },
    ];
    
    return _sendTemplateMessage(
      to: customerPhone,
      templateName: _outForDeliveryTemplateId,
      components: components,
    );
  }

  // ============================================================
  // Public Methods - Deposit Reminder (Future Use)
  // ============================================================
  
  /// Send deposit reminder via WhatsApp
  /// 
  /// Reminds the customer to confirm their deposit payment.
  static Future<WhatsAppResult> sendDepositReminder({
    required String customerPhone,
    required String customerName,
    String? depositAmount,
  }) async {
    final components = [
      {
        'type': 'body',
        'parameters': [
          {'type': 'text', 'text': customerName},
          if (depositAmount != null) {'type': 'text', 'text': depositAmount},
        ],
      },
    ];
    
    return _sendTemplateMessage(
      to: customerPhone,
      templateName: _depositReminderTemplateId,
      components: components,
    );
  }

  // ============================================================
  // Utility Methods
  // ============================================================
  
  /// Check if WhatsApp service is configured
  /// Returns false if using placeholder credentials
  static bool isConfigured() {
    return _accessToken != 'YOUR_WHATSAPP_ACCESS_TOKEN' &&
           _phoneNumberId != 'YOUR_PHONE_NUMBER_ID';
  }
  
  /// Validate phone number format
  /// Returns true if the phone number appears valid for WhatsApp
  static bool isValidPhoneNumber(String phone) {
    final formatted = formatPhoneNumber(phone);
    // WhatsApp numbers should be at least 10 digits (including country code)
    return formatted.length >= 10 && formatted.length <= 15;
  }
}

/// Result of a WhatsApp API operation
class WhatsAppResult {
  final bool success;
  final String? messageId;
  final String message;
  
  const WhatsAppResult({
    required this.success,
    this.messageId,
    required this.message,
  });
  
  @override
  String toString() => 'WhatsAppResult(success: $success, messageId: $messageId, message: $message)';
}

