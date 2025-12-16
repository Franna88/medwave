import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../models/contracts/contract.dart';
import '../../models/streams/appointment.dart';
import 'contract_content_service.dart';
import 'sales_appointment_service.dart';

/// Service for managing contracts in Firebase
class ContractService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ContractContentService _contractContentService =
      ContractContentService();
  final SalesAppointmentService _appointmentService = SalesAppointmentService();

  static const String _collectionPath = 'contracts';
  static const String _secretKey =
      'medwave_contract_secret_2024'; // In production, use env variable

  /// Generate a secure HMAC-SHA256 access token
  String generateAccessToken(String contractId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$contractId:$timestamp';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(data));
    return '${digest.toString()}:$timestamp';
  }

  /// Validate an access token
  bool validateToken(String contractId, String token) {
    try {
      final parts = token.split(':');
      if (parts.length != 2) return false;

      final expectedHash = parts[0];
      final timestamp = parts[1];
      final data = '$contractId:$timestamp';

      final hmac = Hmac(sha256, utf8.encode(_secretKey));
      final digest = hmac.convert(utf8.encode(data));

      return digest.toString() == expectedHash;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error validating token: $e');
      }
      return false;
    }
  }

  /// Create a contract from an appointment
  Future<Contract> createContract({
    required SalesAppointment appointment,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      // Get current contract content
      final contractContent = await _contractContentService
          .getContractContent();

      if (!contractContent.hasContent) {
        throw Exception(
          'Contract content is not configured. Please add contract content in settings.',
        );
      }

      // Calculate totals
      double subtotal = 0;
      for (final product in appointment.optInProducts) {
        subtotal += product.price;
      }

      final depositAmount = subtotal * 0.40; // 40% deposit
      final remainingBalance = subtotal * 0.60; // 60% balance

      // Create contract document reference
      final docRef = _firestore.collection(_collectionPath).doc();

      // Generate access token
      final accessToken = generateAccessToken(docRef.id);

      // Create contract object
      final contract = Contract(
        id: docRef.id,
        accessToken: accessToken,
        status: ContractStatus.pending,
        appointmentId: appointment.id,
        leadId: appointment.leadId,
        customerName: appointment.customerName,
        email: appointment.email,
        phone: appointment.phone,
        contractContentVersion: contractContent.version,
        contractContentData: {
          'content': contractContent.content,
          'plainText': contractContent.plainText,
        },
        products: appointment.optInProducts
            .map((p) => ContractProduct(id: p.id, name: p.name, price: p.price))
            .toList(),
        subtotal: subtotal,
        depositAmount: depositAmount,
        remainingBalance: remainingBalance,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
      );

      // Save to Firestore
      await docRef.set(contract.toMap());

      if (kDebugMode) {
        print('✅ ContractService: Contract created: ${contract.id}');
      }

      return contract;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error creating contract: $e');
      }
      rethrow;
    }
  }

  /// Get contract by ID and validate token
  Future<Contract?> getContractByIdAndToken(
    String contractId,
    String? token,
  ) async {
    try {
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('❌ ContractService: Token is required');
        }
        return null;
      }

      // Validate token
      if (!validateToken(contractId, token)) {
        if (kDebugMode) {
          print('❌ ContractService: Invalid token for contract $contractId');
        }
        return null;
      }

      final doc = await _firestore
          .collection(_collectionPath)
          .doc(contractId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('❌ ContractService: Contract not found: $contractId');
        }
        return null;
      }

      return Contract.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error getting contract: $e');
      }
      return null;
    }
  }

  /// Mark contract as viewed (first time opened)
  Future<void> markAsViewed(String contractId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(contractId)
          .get();

      if (doc.exists) {
        final contract = Contract.fromFirestore(doc);
        // Only mark as viewed if it's still pending
        if (contract.status == ContractStatus.pending &&
            contract.viewedAt == null) {
          await _firestore.collection(_collectionPath).doc(contractId).update({
            'status': ContractStatus.viewed.name,
            'viewedAt': Timestamp.fromDate(DateTime.now()),
          });

          if (kDebugMode) {
            print('✅ ContractService: Contract marked as viewed: $contractId');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error marking contract as viewed: $e');
      }
    }
  }

  /// Sign a contract
  Future<void> signContract({
    required String contractId,
    required String digitalSignature,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Generate unique digital signature token
      const uuid = Uuid();
      final digitalSignatureToken = 'DST-${uuid.v4()}';

      // Improve IP address placeholder
      final finalIpAddress =
          ipAddress ??
          'IP-capture-pending-${DateTime.now().millisecondsSinceEpoch}';

      // Sign contract first (this must succeed)
      await _firestore.collection(_collectionPath).doc(contractId).update({
        'status': ContractStatus.signed.name,
        'hasSigned': true,
        'digitalSignature': digitalSignature,
        'digitalSignatureToken': digitalSignatureToken,
        'signedAt': Timestamp.fromDate(DateTime.now()),
        'ipAddress': finalIpAddress,
        'userAgent': userAgent,
      });

      if (kDebugMode) {
        print('✅ ContractService: Contract signed: $contractId');
      }

      // Attempt stage movement (non-blocking if it fails)
      try {
        final doc = await _firestore
            .collection(_collectionPath)
            .doc(contractId)
            .get();
        if (doc.exists) {
          final contract = Contract.fromFirestore(doc);
          // Move appointment to Deposit Requested stage with context
          await _appointmentService.moveToDepositRequested(
            contract.appointmentId,
            customerName: contract.customerName,
            contractId: contractId,
          );
          if (kDebugMode) {
            print('✅ ContractService: Appointment moved to Deposit Requested');
          }
        }
      } catch (stageError) {
        // Log but don't throw - contract is still signed successfully
        if (kDebugMode) {
          print('⚠️ Contract signed but stage movement failed: $stageError');
          print(
            '   Admin will need to manually move appointment or it will be handled by rules',
          );
        }
      }
    } catch (e) {
      // Only rethrow if contract signing itself failed
      if (kDebugMode) {
        print('❌ ContractService: Error signing contract: $e');
      }
      rethrow;
    }
  }

  /// Void a contract
  Future<void> voidContract({
    required String contractId,
    required String voidedBy,
    String? voidReason,
  }) async {
    try {
      await _firestore.collection(_collectionPath).doc(contractId).update({
        'status': ContractStatus.voided.name,
        'voidedBy': voidedBy,
        'voidedAt': Timestamp.fromDate(DateTime.now()),
        'voidReason': voidReason,
      });

      if (kDebugMode) {
        print('✅ ContractService: Contract voided: $contractId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error voiding contract: $e');
      }
      rethrow;
    }
  }

  /// Update contract status
  Future<void> updateContractStatus(
    String contractId,
    ContractStatus status,
  ) async {
    try {
      await _firestore.collection(_collectionPath).doc(contractId).update({
        'status': status.name,
      });

      if (kDebugMode) {
        print(
          '✅ ContractService: Contract status updated: $contractId -> ${status.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error updating contract status: $e');
      }
      rethrow;
    }
  }

  /// Get contracts by appointment ID
  Future<List<Contract>> getContractsByAppointmentId(
    String appointmentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      final contracts =
          snapshot.docs.map((doc) => Contract.fromFirestore(doc)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return contracts;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error getting contracts: $e');
      }
      return [];
    }
  }

  /// Get all contracts (for SuperAdmin dashboard)
  Future<List<Contract>> getAllContracts() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Contract.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error getting all contracts: $e');
      }
      return [];
    }
  }

  /// Stream all contracts
  Stream<List<Contract>> watchAllContracts() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Contract.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream contracts by appointment ID
  Stream<List<Contract>> watchContractsByAppointmentId(String appointmentId) {
    return _firestore
        .collection(_collectionPath)
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Contract.fromFirestore(doc))
              .toList();
        });
  }

  /// Get contract by ID (admin access, no token validation)
  Future<Contract?> getContractById(String contractId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(contractId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Contract.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error getting contract by ID: $e');
      }
      return null;
    }
  }

  /// Generate contract link (relative path)
  String generateContractLink(Contract contract) {
    return '/contract/${contract.id}?token=${contract.accessToken}';
  }

  /// Get full contract URL (for copying)
  String getFullContractUrl(Contract contract) {
    if (kIsWeb) {
      // On web, get the current domain dynamically
      final baseUrl = Uri.base.origin;
      return '$baseUrl/contract/${contract.id}?token=${contract.accessToken}';
    }
    // For mobile, use a configurable base URL
    // TODO: Store this in environment config
    return 'https://yourdomain.com/contract/${contract.id}?token=${contract.accessToken}';
  }
}
