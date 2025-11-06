import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/payment.dart';

/// Service for handling Paystack payment integration
class PaystackService {
  static const String _baseUrl = 'https://api.paystack.co';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Generate a unique payment reference
  /// Format: MEDWAVE_{timestamp}_{patientId}
  String generatePaymentReference(String patientId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'MEDWAVE_${timestamp}_${patientId.substring(0, 8)}';
  }

  /// Initialize a payment transaction with Paystack
  /// Returns a Payment object with authorization URL for QR code
  /// 
  /// If [subaccountCode] is provided, payment will be split to practitioner's account
  /// [platformCommissionPercentage] determines the platform's commission (default 5%)
  Future<Payment> initializePayment({
    required String patientId,
    required String patientName,
    required String practitionerId,
    required double amount,
    required String email,
    required String secretKey,
    String? appointmentId,
    String? sessionId,
    String currency = 'ZAR',
    Map<String, dynamic>? metadata,
    String? subaccountCode, // Practitioner's subaccount for split payment
    double platformCommissionPercentage = 5.0, // Platform commission %
  }) async {
    try {
      // Generate payment reference
      final reference = generatePaymentReference(patientId);
      
      // Convert amount to kobo/cents (Paystack uses smallest currency unit)
      final amountInCents = (amount * 100).toInt();
      
      // Calculate split amounts
      final platformCommission = (amount * platformCommissionPercentage) / 100;
      final practitionerAmount = amount - platformCommission;
      final transactionCharge = (platformCommission * 100).toInt(); // In kobo/cents

      // Prepare request body
      final body = {
        'email': email,
        'amount': amountInCents.toString(),
        'reference': reference,
        'currency': currency,
        'metadata': {
          'patient_id': patientId,
          'patient_name': patientName,
          'practitioner_id': practitionerId,
          'appointment_id': appointmentId,
          'session_id': sessionId,
          'platform_commission': platformCommission,
          'practitioner_amount': practitionerAmount,
          ...?metadata,
        },
      };
      
      // Add subaccount split if provided
      if (subaccountCode != null && subaccountCode.isNotEmpty) {
        body['subaccount'] = subaccountCode;
        body['transaction_charge'] = transactionCharge; // Platform commission in kobo
        body['bearer'] = 'subaccount'; // Subaccount pays transaction fees
      }

      // Make API request to Paystack
      final response = await http.post(
        Uri.parse('$_baseUrl/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          final responseData = data['data'];
          
          // Create payment object
          final payment = Payment(
            id: _uuid.v4(),
            sessionId: sessionId,
            appointmentId: appointmentId,
            patientId: patientId,
            patientName: patientName,
            practitionerId: practitionerId,
            amount: amount,
            currency: currency,
            status: PaymentStatus.pending,
            paymentMethod: PaymentMethod.qrCode,
            paymentReference: reference,
            paystackReference: responseData['reference'],
            paystackAccessCode: responseData['access_code'],
            authorizationUrl: responseData['authorization_url'],
            subaccountCode: subaccountCode,
            platformCommission: platformCommission,
            practitionerAmount: practitionerAmount,
            settlementStatus: subaccountCode != null ? 'pending' : null,
            createdAt: DateTime.now(),
            metadata: metadata,
          );

          // Save to Firestore
          await _firestore
              .collection('payments')
              .doc(payment.id)
              .set(payment.toFirestore());

          return payment;
        } else {
          throw Exception('Paystack initialization failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to initialize payment: $e');
    }
  }

  /// Verify a payment transaction with Paystack
  Future<Payment> verifyPayment({
    required String paymentId,
    required String reference,
    required String secretKey,
  }) async {
    try {
      // Get payment from Firestore
      final paymentDoc = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final payment = Payment.fromFirestore(paymentDoc);

      // Verify with Paystack API
      final response = await http.get(
        Uri.parse('$_baseUrl/transaction/verify/$reference'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          final responseData = data['data'];
          final status = responseData['status'];

          PaymentStatus paymentStatus;
          if (status == 'success') {
            paymentStatus = PaymentStatus.completed;
          } else if (status == 'failed') {
            paymentStatus = PaymentStatus.failed;
          } else {
            paymentStatus = PaymentStatus.pending;
          }

          // Update payment with settlement status
          String? settlementStatus;
          if (paymentStatus == PaymentStatus.completed && payment.subaccountCode != null) {
            settlementStatus = 'settled'; // Paystack handles settlement automatically
          }
          
          final updatedPayment = payment.copyWith(
            status: paymentStatus,
            completedAt: paymentStatus == PaymentStatus.completed 
                ? DateTime.now() 
                : null,
            lastUpdated: DateTime.now(),
            paystackReference: responseData['reference'],
            settlementStatus: settlementStatus ?? payment.settlementStatus,
            settlementDate: settlementStatus == 'settled' ? DateTime.now() : null,
          );

          // Save to Firestore
          await _firestore
              .collection('payments')
              .doc(paymentId)
              .update(updatedPayment.toFirestore());

          return updatedPayment;
        } else {
          throw Exception('Verification failed: ${data['message']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }

  /// Get payment by ID from Firestore
  Future<Payment?> getPayment(String paymentId) async {
    try {
      final doc = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get();

      if (doc.exists) {
        return Payment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get payment: $e');
    }
  }

  /// Get payment by appointment ID
  Future<Payment?> getPaymentByAppointment(String appointmentId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Payment.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get payment by appointment: $e');
    }
  }

  /// Get payment by session ID
  Future<Payment?> getPaymentBySession(String sessionId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('sessionId', isEqualTo: sessionId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Payment.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get payment by session: $e');
    }
  }

  /// Get all payments for a practitioner
  Future<List<Payment>> getPractitionerPayments(String practitionerId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('practitionerId', isEqualTo: practitionerId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Payment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get practitioner payments: $e');
    }
  }

  /// Get all payments for a patient
  Future<List<Payment>> getPatientPayments(String patientId) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Payment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get patient payments: $e');
    }
  }

  /// Mark payment as completed manually (cash payment)
  Future<Payment> markPaymentAsCompleted({
    required String paymentId,
    String? notes,
  }) async {
    try {
      final paymentDoc = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final payment = Payment.fromFirestore(paymentDoc);

      final updatedPayment = payment.copyWith(
        status: PaymentStatus.completed,
        completedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        paymentMethod: PaymentMethod.cash,
        notes: notes,
      );

      await _firestore
          .collection('payments')
          .doc(paymentId)
          .update(updatedPayment.toFirestore());

      return updatedPayment;
    } catch (e) {
      throw Exception('Failed to mark payment as completed: $e');
    }
  }

  /// Cancel a payment
  Future<Payment> cancelPayment({
    required String paymentId,
    String? reason,
  }) async {
    try {
      final paymentDoc = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final payment = Payment.fromFirestore(paymentDoc);

      final updatedPayment = payment.copyWith(
        status: PaymentStatus.cancelled,
        lastUpdated: DateTime.now(),
        notes: reason,
      );

      await _firestore
          .collection('payments')
          .doc(paymentId)
          .update(updatedPayment.toFirestore());

      return updatedPayment;
    } catch (e) {
      throw Exception('Failed to cancel payment: $e');
    }
  }

  /// Generate QR code data (authorization URL)
  String generateQRData(Payment payment) {
    if (payment.authorizationUrl == null) {
      throw Exception('Payment does not have authorization URL');
    }
    return payment.authorizationUrl!;
  }

  /// Stream payment updates
  Stream<Payment> streamPayment(String paymentId) {
    return _firestore
        .collection('payments')
        .doc(paymentId)
        .snapshots()
        .map((doc) => Payment.fromFirestore(doc));
  }
}

