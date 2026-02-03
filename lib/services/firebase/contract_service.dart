import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../models/contracts/contract.dart';
import '../../models/streams/appointment.dart';
import 'contract_content_service.dart';
import 'sales_appointment_service.dart';
import '../pdf/contract_pdf_service.dart';

/// Service for managing contracts in Firebase
class ContractService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ContractContentService _contractContentService =
      ContractContentService();
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  final ContractPdfService _pdfService = ContractPdfService();

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

      // Extract and validate shipping address
      final shippingAddress = appointment.optInQuestions?['Shipping address'];

      if (shippingAddress == null || shippingAddress.trim().isEmpty) {
        throw Exception(
          'Shipping address is required for contract generation. Please update the appointment details.',
        );
      }

      // Calculate totals (products and packages)
      double subtotal = 0;
      for (final product in appointment.optInProducts) {
        subtotal += product.price * product.quantity;
      }
      for (final pkg in appointment.optInPackages) {
        subtotal += pkg.price * pkg.quantity;
      }

      final totalInclVat = subtotal * 1.15; // 15% VAT
      final depositAmount = totalInclVat * 0.10; // 10% deposit
      final remainingBalance = totalInclVat - depositAmount; // 90% balance

      // Create contract document reference
      final docRef = _firestore.collection(_collectionPath).doc();

      // Generate access token
      final accessToken = generateAccessToken(docRef.id);

      // Build products from opt-in products and packages
      final productsFromProducts = appointment.optInProducts
          .map((p) => ContractProduct(
              id: p.id, name: p.name, price: p.price, quantity: p.quantity))
          .toList();
      final productsFromPackages = appointment.optInPackages
          .map((p) => ContractProduct(
              id: p.id,
              name: p.name,
              price: p.price,
              quantity: p.quantity,
              lineType: 'packageHeader'))
          .toList();
      final allProducts = [...productsFromProducts, ...productsFromPackages];

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
        shippingAddress: shippingAddress,
        contractContentVersion: contractContent.version,
        contractContentData: {
          'content': contractContent.content,
          'plainText': contractContent.plainText,
        },
        products: allProducts,
        subtotal: subtotal,
        depositAmount: depositAmount,
        remainingBalance: remainingBalance,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
        paymentType: appointment.paymentType,
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

  /// Create a contract revision (edited version of existing contract)
  Future<Contract> createContractRevision({
    required Contract originalContract,
    required SalesAppointment appointment,
    required String createdBy,
    required String createdByName,
    String? editReason,
    // Editable fields
    List<ContractProduct>? products,
    String? customerName,
    String? email,
    String? phone,
    String? shippingAddress,
    String? paymentType,
    Map<String, dynamic>? editedContractContent, // Allow editing contract terms
    double? subtotal, // Optional calculated subtotal (accounts for quantities)
  }) async {
    try {
      // Get current contract content (use same version as original)
      final contractContent = await _contractContentService
          .getContractContent();

      if (!contractContent.hasContent) {
        throw Exception('Contract content is not configured.');
      }

      // Use provided values or fall back to original contract values
      final finalProducts = products ?? originalContract.products;
      final finalCustomerName = customerName ?? originalContract.customerName;
      final finalEmail = email ?? originalContract.email;
      final finalPhone = phone ?? originalContract.phone;
      final finalShippingAddress =
          shippingAddress ?? originalContract.shippingAddress;
      final finalPaymentType = paymentType ?? originalContract.paymentType;

      // Use provided subtotal if available, otherwise calculate from products
      // Note: ContractProduct doesn't have quantity, so if subtotal is provided,
      // it should already account for quantities. Otherwise, we calculate from unit prices.
      double finalSubtotal;
      if (subtotal != null) {
        finalSubtotal = subtotal;
      } else {
        // Fallback: calculate from products (for backward compatibility)
        finalSubtotal = 0;
        for (final product in finalProducts) {
          finalSubtotal += product.price;
        }
      }

      final totalInclVat = finalSubtotal * 1.15; // 15% VAT
      final depositAmount = totalInclVat * 0.10; // 10% deposit
      final remainingBalance = totalInclVat - depositAmount; // 90% balance

      // Get revision number: always chain to root contract so numbers increment (1, 2, 3...)
      final rootId = originalContract.parentContractId ?? originalContract.id;
      final existingRevisions = await getContractsByAppointmentId(
        appointment.id,
      );
      final revisionsOfRoot = existingRevisions
          .where((c) => c.id == rootId || c.parentContractId == rootId)
          .toList();
      final revisionNumber = revisionsOfRoot.length + 1;

      // Create new contract document
      final docRef = _firestore.collection(_collectionPath).doc();
      final accessToken = generateAccessToken(docRef.id);

      // Use edited contract content if provided, otherwise use original
      final finalContractContentData =
          editedContractContent ?? originalContract.contractContentData;

      // Create revision contract
      final revisionContract = Contract(
        id: docRef.id,
        accessToken: accessToken,
        status: ContractStatus.pending,
        appointmentId: appointment.id,
        leadId: appointment.leadId,
        customerName: finalCustomerName,
        email: finalEmail,
        phone: finalPhone,
        shippingAddress: finalShippingAddress,
        contractContentVersion: originalContract.contractContentVersion,
        contractContentData:
            finalContractContentData, // Use edited content if provided
        products: finalProducts,
        subtotal: finalSubtotal,
        depositAmount: depositAmount,
        remainingBalance: remainingBalance,
        paymentType: finalPaymentType,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
        // Revision tracking (always point to root so history is one chain)
        parentContractId: rootId,
        revisionNumber: revisionNumber,
        editReason: editReason,
        editedBy: createdBy,
        editedAt: DateTime.now(),
      );

      await docRef.set(revisionContract.toMap());

      if (kDebugMode) {
        print(
          '✅ ContractService: Contract revision created: ${revisionContract.id} (revision #$revisionNumber)',
        );
      }

      return revisionContract;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error creating contract revision: $e');
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
          final contractViewUrl = getFullContractUrl(contract);
          // Move appointment to Deposit Requested stage with email notification
          await _appointmentService.moveAppointmentToStage(
            appointmentId: contract.appointmentId,
            newStage: 'deposit_requested',
            note:
                'Contract digitally signed by ${contract.customerName} (Contract ID: $contractId). Deposit request email sent.',
            userId: 'system',
            userName: 'System (Contract Signing)',
            shouldSendDepositEmail: true, // Triggers deposit confirmation email
            contractViewUrl: contractViewUrl,
          );
          if (kDebugMode) {
            print(
              '✅ ContractService: Appointment moved to Deposit Requested with email',
            );
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

      // Generate and upload PDF (non-blocking if it fails)
      try {
        await generateAndUploadPdf(contractId);
      } catch (pdfError) {
        // Log but don't throw - contract is still signed successfully
        if (kDebugMode) {
          print('⚠️ Contract signed but PDF generation failed: $pdfError');
          print('   Admin can regenerate PDF later from admin panel');
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

  /// Generate and upload PDF for a contract (can be called independently)
  Future<String> generateAndUploadPdf(String contractId) async {
    try {
      // #region agent log
      final overallStartTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [CONTRACT-SERVICE-START] contractId=$contractId, time=$overallStartTime (Hyp: E)',
        );
      // #endregion
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(contractId)
          .get();

      if (!doc.exists) {
        throw Exception('Contract not found');
      }

      // #region agent log
      final fetchEndTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [FIRESTORE-FETCH] fetch_time=${fetchEndTime - overallStartTime}ms (Hyp: E)',
        );
      // #endregion

      final contract = Contract.fromFirestore(doc);

      if (!contract.hasSigned) {
        throw Exception('Contract must be signed before generating PDF');
      }

      if (kDebugMode) {
        print('📄 Generating PDF with cover page for contract: $contractId');
      }

      // Generate PDF (now includes cover page automatically)
      final pdfBytes = await _pdfService.generatePdfBytes(contract);
      final pdfUrl = await _pdfService.uploadPdfToStorage(contract, pdfBytes);

      // #region agent log
      final updateStartTime = DateTime.now().millisecondsSinceEpoch;
      // #endregion
      // Update contract with PDF URL
      await _firestore.collection(_collectionPath).doc(contractId).update({
        'pdfUrl': pdfUrl,
      });

      // #region agent log
      final overallEndTime = DateTime.now().millisecondsSinceEpoch;
      if (kDebugMode)
        print(
          '🔍 [FIRESTORE-UPDATE] update_time=${overallEndTime - updateStartTime}ms (Hyp: E)',
        );
      if (kDebugMode)
        print(
          '🔍 [CONTRACT-SERVICE-COMPLETE] total_time=${overallEndTime - overallStartTime}ms (Hyp: All)',
        );
      // #endregion

      if (kDebugMode) {
        print('✅ PDF generated and uploaded successfully: $pdfUrl');
      }

      return pdfUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating PDF: $e');
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

  /// Get contract revision history (original + all revisions)
  Future<List<Contract>> getContractRevisionHistory(String contractId) async {
    try {
      // Get the contract (could be original or a revision)
      final contract = await getContractById(contractId);
      if (contract == null) return [];

      // Find the original contract
      final originalContractId = contract.parentContractId ?? contract.id;

      // Get all contracts for this appointment
      final allContracts = await getContractsByAppointmentId(
        contract.appointmentId,
      );

      // Filter to get original + all its revisions
      final revisionHistory = allContracts.where((c) {
        return c.id == originalContractId ||
            c.parentContractId == originalContractId;
      }).toList();

      // Sort by revision number (0 = original, then 1, 2, 3...)
      revisionHistory.sort(
        (a, b) => a.revisionNumber.compareTo(b.revisionNumber),
      );

      return revisionHistory;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractService: Error getting revision history: $e');
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
