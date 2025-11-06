import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for managing Paystack subaccounts
/// Handles creation, verification, and management of practitioner bank accounts
class PaystackSubaccountService {
  final String _secretKey;
  static const String _baseUrl = 'https://api.paystack.co';

  PaystackSubaccountService(this._secretKey);

  /// Get authorization headers for Paystack API
  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      };

  /// Create a subaccount for a practitioner
  /// 
  /// This allows the practitioner to receive payments directly to their bank account
  /// 
  /// Parameters:
  /// - [businessName]: Practitioner's full name or practice name
  /// - [bankCode]: Paystack bank code (e.g., "011" for FNB)
  /// - [accountNumber]: Bank account number
  /// - [email]: Practitioner's email
  /// - [phone]: Practitioner's phone number
  /// - [percentageCharge]: Platform commission percentage (default 5%)
  /// 
  /// Returns: [SubaccountResponse] with subaccount details
  Future<SubaccountResponse> createSubaccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required String email,
    required String phone,
    double percentageCharge = 5.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/subaccount'),
        headers: _headers,
        body: jsonEncode({
          'business_name': businessName,
          'settlement_bank': bankCode,
          'account_number': accountNumber,
          'percentage_charge': percentageCharge,
          'primary_contact_email': email,
          'primary_contact_name': businessName,
          'primary_contact_phone': phone,
          'description': 'MedWave Practitioner - $businessName',
        }),
      );

      debugPrint('Paystack Create Subaccount Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return SubaccountResponse.fromJson(data['data']);
        } else {
          throw PaystackException(data['message'] ?? 'Failed to create subaccount');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw PaystackException(errorData['message'] ?? 'Failed to create subaccount');
      }
    } catch (e) {
      debugPrint('Error creating subaccount: $e');
      rethrow;
    }
  }

  /// Verify bank account details before creating subaccount
  /// 
  /// This ensures the account number and bank code are valid
  /// and returns the account holder's name for confirmation
  /// 
  /// Parameters:
  /// - [accountNumber]: Bank account number to verify
  /// - [bankCode]: Paystack bank code
  /// 
  /// Returns: [BankAccountVerification] with account holder name
  Future<BankAccountVerification> verifyBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/bank/resolve?account_number=$accountNumber&bank_code=$bankCode',
        ),
        headers: _headers,
      );

      debugPrint('Paystack Verify Account Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return BankAccountVerification.fromJson(data['data']);
        } else {
          throw PaystackException(data['message'] ?? 'Failed to verify account');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw PaystackException(errorData['message'] ?? 'Failed to verify account');
      }
    } catch (e) {
      debugPrint('Error verifying bank account: $e');
      rethrow;
    }
  }

  /// Get list of supported banks for a country
  /// 
  /// Parameters:
  /// - [country]: Country code (default: 'south-africa')
  /// 
  /// Returns: List of [Bank] objects
  Future<List<Bank>> getBanks({String country = 'south-africa'}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/bank?country=$country'),
        headers: _headers,
      );

      debugPrint('Paystack Get Banks Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final banks = (data['data'] as List)
              .map((bank) => Bank.fromJson(bank))
              .toList();
          
          // Sort banks alphabetically
          banks.sort((a, b) => a.name.compareTo(b.name));
          
          return banks;
        } else {
          throw PaystackException(data['message'] ?? 'Failed to get banks');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw PaystackException(errorData['message'] ?? 'Failed to get banks');
      }
    } catch (e) {
      debugPrint('Error getting banks: $e');
      rethrow;
    }
  }

  /// Update an existing subaccount
  /// 
  /// Parameters:
  /// - [subaccountCode]: The subaccount code to update
  /// - [businessName]: New business name (optional)
  /// - [bankCode]: New bank code (optional)
  /// - [accountNumber]: New account number (optional)
  /// - [percentageCharge]: New commission percentage (optional)
  /// 
  /// Returns: true if successful
  Future<bool> updateSubaccount({
    required String subaccountCode,
    String? businessName,
    String? bankCode,
    String? accountNumber,
    double? percentageCharge,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (businessName != null) body['business_name'] = businessName;
      if (bankCode != null) body['settlement_bank'] = bankCode;
      if (accountNumber != null) body['account_number'] = accountNumber;
      if (percentageCharge != null) body['percentage_charge'] = percentageCharge;

      final response = await http.put(
        Uri.parse('$_baseUrl/subaccount/$subaccountCode'),
        headers: _headers,
        body: jsonEncode(body),
      );

      debugPrint('Paystack Update Subaccount Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      } else {
        final errorData = jsonDecode(response.body);
        throw PaystackException(errorData['message'] ?? 'Failed to update subaccount');
      }
    } catch (e) {
      debugPrint('Error updating subaccount: $e');
      return false;
    }
  }

  /// Get subaccount details
  /// 
  /// Parameters:
  /// - [subaccountCode]: The subaccount code to fetch
  /// 
  /// Returns: [SubaccountResponse] with subaccount details
  Future<SubaccountResponse?> getSubaccount(String subaccountCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/subaccount/$subaccountCode'),
        headers: _headers,
      );

      debugPrint('Paystack Get Subaccount Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return SubaccountResponse.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting subaccount: $e');
      return null;
    }
  }

  /// List all subaccounts
  /// 
  /// Parameters:
  /// - [page]: Page number (default: 1)
  /// - [perPage]: Items per page (default: 50)
  /// 
  /// Returns: List of [SubaccountResponse] objects
  Future<List<SubaccountResponse>> listSubaccounts({
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/subaccount?page=$page&perPage=$perPage'),
        headers: _headers,
      );

      debugPrint('Paystack List Subaccounts Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return (data['data'] as List)
              .map((subaccount) => SubaccountResponse.fromJson(subaccount))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error listing subaccounts: $e');
      return [];
    }
  }
}

/// Response from Paystack subaccount creation/retrieval
class SubaccountResponse {
  final String subaccountCode;
  final String businessName;
  final String settlementBank;
  final String accountNumber;
  final double percentageCharge;
  final bool isVerified;
  final String settlementSchedule;
  final bool active;
  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubaccountResponse({
    required this.subaccountCode,
    required this.businessName,
    required this.settlementBank,
    required this.accountNumber,
    required this.percentageCharge,
    required this.isVerified,
    required this.settlementSchedule,
    required this.active,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubaccountResponse.fromJson(Map<String, dynamic> json) {
    return SubaccountResponse(
      subaccountCode: json['subaccount_code'] ?? '',
      businessName: json['business_name'] ?? '',
      settlementBank: json['settlement_bank'] ?? '',
      accountNumber: json['account_number'] ?? '',
      percentageCharge: (json['percentage_charge'] ?? 0).toDouble(),
      isVerified: json['is_verified'] ?? false,
      settlementSchedule: json['settlement_schedule'] ?? 'auto',
      active: json['active'] ?? true,
      id: json['id'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subaccount_code': subaccountCode,
      'business_name': businessName,
      'settlement_bank': settlementBank,
      'account_number': accountNumber,
      'percentage_charge': percentageCharge,
      'is_verified': isVerified,
      'settlement_schedule': settlementSchedule,
      'active': active,
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Bank account verification response
class BankAccountVerification {
  final String accountNumber;
  final String accountName;
  final String bankCode;

  BankAccountVerification({
    required this.accountNumber,
    required this.accountName,
    required this.bankCode,
  });

  factory BankAccountVerification.fromJson(Map<String, dynamic> json) {
    return BankAccountVerification(
      accountNumber: json['account_number'] ?? '',
      accountName: json['account_name'] ?? '',
      bankCode: json['bank_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'account_name': accountName,
      'bank_id': bankCode,
    };
  }
}

/// Bank information
class Bank {
  final String name;
  final String code;
  final String country;
  final String? slug;
  final String? currency;
  final String? type;

  Bank({
    required this.name,
    required this.code,
    required this.country,
    this.slug,
    this.currency,
    this.type,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      country: json['country'] ?? 'South Africa',
      slug: json['slug'],
      currency: json['currency'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'country': country,
      'slug': slug,
      'currency': currency,
      'type': type,
    };
  }

  @override
  String toString() => name;
}

/// Custom exception for Paystack errors
class PaystackException implements Exception {
  final String message;

  PaystackException(this.message);

  @override
  String toString() => 'PaystackException: $message';
}

