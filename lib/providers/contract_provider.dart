import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/contracts/contract.dart';
import '../models/streams/appointment.dart';
import '../services/firebase/admin_service.dart';
import '../services/firebase/contract_service.dart';
import '../services/firebase/sales_appointment_service.dart';
import '../services/emailjs_service.dart';

/// Provider for managing contract state
class ContractProvider extends ChangeNotifier {
  final ContractService _service = ContractService();

  Contract? _currentContract;
  List<Contract> _allContracts = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  StreamSubscription<List<Contract>>? _subscription;
  bool _lastContractBccSent = true;

  // Getters
  Contract? get currentContract => _currentContract;
  List<Contract> get allContracts => _allContracts;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get lastContractBccSent => _lastContractBccSent;

  /// Generate contract for an appointment
  Future<Contract?> generateContractForAppointment({
    required SalesAppointment appointment,
    required String createdBy,
    required String createdByName,
  }) async {
    if (_isSaving) return null;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final contract = await _service.createContract(
        appointment: appointment,
        createdBy: createdBy,
        createdByName: createdByName,
      );

      _currentContract = contract;

      // Contract is created but NOT automatically sent
      // Admin can manually send it via the "Resend Contract Email" button after reviewing/editing

      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractProvider: Contract generated successfully');
      }

      return contract;
    } catch (e) {
      _error = 'Failed to generate contract: $e';
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error generating contract: $e');
      }

      return null;
    }
  }

  /// Create a contract revision (edited version)
  Future<Contract?> createContractRevision({
    required Contract originalContract,
    required SalesAppointment appointment,
    required String createdBy,
    required String createdByName,
    String? editReason,
    List<ContractProduct>? products,
    String? customerName,
    String? email,
    String? phone,
    String? shippingAddress,
    String? paymentType,
    Map<String, dynamic>? editedContractContent, // Allow editing contract terms
    double? subtotal, // Optional calculated subtotal (accounts for quantities)
  }) async {
    if (_isSaving) return null;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final revision = await _service.createContractRevision(
        originalContract: originalContract,
        appointment: appointment,
        createdBy: createdBy,
        createdByName: createdByName,
        editReason: editReason,
        products: products,
        customerName: customerName,
        email: email,
        phone: phone,
        shippingAddress: shippingAddress,
        paymentType: paymentType,
        editedContractContent: editedContractContent,
        subtotal: subtotal,
      );

      _currentContract = revision;
      _isSaving = false;
      notifyListeners();
      return revision;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  /// Resend contract email (for revisions or original contracts).
  /// Returns (success, errorMessage) so UI can show a short reason when send fails.
  Future<({bool success, String? errorMessage})> resendContractEmail({
    required Contract contract,
    required SalesAppointment appointment,
  }) async {
    try {
      final contractUrl = getFullContractUrl(contract);
      final result = await EmailJSService.sendContractLinkEmail(
        appointment: appointment,
        contractUrl: contractUrl,
      );
      if (result.success) {
        String? downloadUrl;
        try {
          downloadUrl = await _service.getContractPdfDownloadUrl(contract);
        } catch (e) {
          if (kDebugMode) {
            print(
              'ContractProvider: Could not generate PDF download link for BCC: $e',
            );
          }
        }
        String? assignedAdminEmail;
        if (appointment.assignedTo != null &&
            appointment.assignedTo!.trim().isNotEmpty) {
          assignedAdminEmail =
              await AdminService.getAdminEmailByUserId(appointment.assignedTo!);
        }
        _lastContractBccSent =
            await EmailJSService.sendContractSentNotificationToBcc(
              contractId: contract.id,
              customerName: appointment.customerName,
              contractSentDate: DateTime.now(),
              contractDownloadUrl: downloadUrl,
              assignedAdminEmail: assignedAdminEmail,
            );
        if (!_lastContractBccSent && kDebugMode) {
          print(
            'ContractProvider: Contract sent to client but BCC notification failed. In EmailJS set "To Email" to {{bcc_email}} or {{to_email}} (we send both).',
          );
        }
        return (success: true, errorMessage: null);
      }
      return (success: false, errorMessage: result.errorMessage);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      final msg = e.toString();
      final reason = msg.length > 80 ? msg.substring(0, 80) : msg;
      return (success: false, errorMessage: reason);
    }
  }

  /// Get contract revision history
  Future<List<Contract>> getContractRevisionHistory(String contractId) async {
    try {
      return await _service.getContractRevisionHistory(contractId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractProvider: Error getting revision history: $e');
      }
      return [];
    }
  }

  /// Load contract by ID and token (public access)
  Future<Contract?> loadContractByIdAndToken(
    String contractId,
    String? token,
  ) async {
    _isLoading = true;
    _error = null;
    _currentContract = null;
    notifyListeners();

    try {
      final contract = await _service.getContractByIdAndToken(
        contractId,
        token,
      );

      if (contract == null) {
        _error = 'Contract not found or invalid access token';
      } else {
        _currentContract = contract;
      }

      _isLoading = false;
      notifyListeners();

      return contract;
    } catch (e) {
      _error = 'Failed to load contract: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error loading contract: $e');
      }

      return null;
    }
  }

  /// Load contract by ID (admin access, no token needed)
  Future<Contract?> loadContractById(String contractId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final contract = await _service.getContractById(contractId);

      _currentContract = contract;
      _isLoading = false;
      notifyListeners();

      return contract;
    } catch (e) {
      _error = 'Failed to load contract: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error loading contract by ID: $e');
      }

      return null;
    }
  }

  /// Mark contract as viewed
  Future<void> markContractAsViewed(String contractId) async {
    try {
      await _service.markAsViewed(contractId);

      // Update local state if this is the current contract
      if (_currentContract?.id == contractId &&
          _currentContract?.status == ContractStatus.pending) {
        _currentContract = _currentContract!.copyWith(
          status: ContractStatus.viewed,
          viewedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractProvider: Error marking contract as viewed: $e');
      }
    }
  }

  /// Sign a contract
  Future<bool> signContract({
    required String contractId,
    required String digitalSignature,
    String? ipAddress,
    String? userAgent,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _service.signContract(
        contractId: contractId,
        digitalSignature: digitalSignature,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      // Reload contract to get updated fields (digitalSignatureToken, pdfUrl, etc.)
      await loadContractById(contractId);

      // Notify BCC list that contract was signed (non-blocking)
      if (_currentContract != null && _currentContract!.signedAt != null) {
        try {
          String? assignedAdminEmail;
          final appointment = await SalesAppointmentService().getAppointment(
            _currentContract!.appointmentId,
          );
          if (appointment?.assignedTo != null &&
              appointment!.assignedTo!.trim().isNotEmpty) {
            assignedAdminEmail =
                await AdminService.getAdminEmailByUserId(appointment.assignedTo!);
          }
          await EmailJSService.sendContractSignedNotificationToBcc(
            contractId: _currentContract!.id,
            customerName: _currentContract!.customerName,
            contractSignedDate: _currentContract!.signedAt!,
            assignedAdminEmail: assignedAdminEmail,
          );
        } catch (e) {
          if (kDebugMode) {
            print(
              '⚠️ ContractProvider: Contract signed but BCC notification failed: $e',
            );
          }
        }
      }

      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractProvider: Contract signed successfully');
      }

      return true;
    } catch (e) {
      _error = 'Failed to sign contract: $e';
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error signing contract: $e');
      }

      return false;
    }
  }

  /// Void a contract
  Future<bool> voidContract({
    required String contractId,
    required String voidedBy,
    String? voidReason,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _service.voidContract(
        contractId: contractId,
        voidedBy: voidedBy,
        voidReason: voidReason,
      );

      // Update local state
      if (_currentContract?.id == contractId) {
        _currentContract = _currentContract!.copyWith(
          status: ContractStatus.voided,
          voidedBy: voidedBy,
          voidedAt: DateTime.now(),
          voidReason: voidReason,
        );
      }

      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractProvider: Contract voided successfully');
      }

      return true;
    } catch (e) {
      _error = 'Failed to void contract: $e';
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error voiding contract: $e');
      }

      return false;
    }
  }

  /// Generate PDF for a contract (manual trigger)
  Future<bool> generateContractPdf(String contractId) async {
    try {
      _error = null;
      notifyListeners();

      await _service.generateAndUploadPdf(contractId);

      // Reload contract to get updated pdfUrl
      await loadContractById(contractId);

      if (kDebugMode) {
        print('✅ ContractProvider: PDF generated successfully');
      }

      return true;
    } catch (e) {
      _error = 'Failed to generate PDF: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error generating PDF: $e');
      }

      return false;
    }
  }

  /// Load contracts by appointment ID
  Future<List<Contract>> loadContractsByAppointmentId(
    String appointmentId,
  ) async {
    try {
      final contracts = await _service.getContractsByAppointmentId(
        appointmentId,
      );
      return contracts;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractProvider: Error loading contracts: $e');
      }
      return [];
    }
  }

  /// Load all contracts (for admin dashboard)
  Future<void> loadAllContracts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allContracts = await _service.getAllContracts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load contracts: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractProvider: Error loading all contracts: $e');
      }
    }
  }

  /// Subscribe to all contracts stream
  void subscribeToAllContracts() {
    _subscription?.cancel();
    _subscription = _service.watchAllContracts().listen(
      (contracts) {
        _allContracts = contracts;
        notifyListeners();

        if (kDebugMode) {
          print('✅ ContractProvider: Received ${contracts.length} contracts');
        }
      },
      onError: (error) {
        _error = 'Failed to watch contracts: $error';
        notifyListeners();

        if (kDebugMode) {
          print('❌ ContractProvider: Stream error: $error');
        }
      },
    );
  }

  /// Get contract link
  String getContractLink(Contract contract) {
    return _service.generateContractLink(contract);
  }

  /// Get full contract URL (for copying)
  String getFullContractUrl(Contract contract) {
    return _service.getFullContractUrl(contract);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear current contract
  void clearCurrentContract() {
    _currentContract = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
