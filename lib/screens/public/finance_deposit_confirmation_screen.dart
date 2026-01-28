import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/streams/appointment.dart';
import '../../services/firebase/sales_appointment_service.dart';

class FinanceDepositConfirmationScreen extends StatefulWidget {
  final String? appointmentId;
  final String? token;

  const FinanceDepositConfirmationScreen({
    super.key,
    this.appointmentId,
    this.token,
  });

  @override
  State<FinanceDepositConfirmationScreen> createState() =>
      _FinanceDepositConfirmationScreenState();
}

class _FinanceDepositConfirmationScreenState
    extends State<FinanceDepositConfirmationScreen> {
  final _service = SalesAppointmentService();
  late final Future<DepositConfirmationResult> _confirmationFuture;
  SalesAppointment? _appointment;

  // Static state to handle widget recreation
  static final Set<String> _processingAppointments = {};
  static final Map<String, DepositConfirmationResult> _processingResults = {};

  @override
  void initState() {
    super.initState();
    // Initialize once - survives widget rebuilds
    _confirmationFuture = _processConfirmation();
    _loadAppointment();
  }

  Future<void> _loadAppointment() async {
    if (widget.appointmentId != null) {
      try {
        final appointment = await _service.getAppointment(widget.appointmentId!);
        if (mounted) {
          setState(() {
            _appointment = appointment;
          });
        }
      } catch (e) {
        // Ignore errors - appointment display is optional
      }
    }
  }

  Future<DepositConfirmationResult> _processConfirmation() async {
    final appointmentId = widget.appointmentId;
    final token = widget.token;

    if (appointmentId == null || token == null) {
      return const DepositConfirmationResult(
        success: false,
        message: 'The confirmation link is missing some details.',
        status: DepositResponseStatus.invalid,
      );
    }

    if (_processingResults.containsKey(appointmentId)) {
      return _processingResults[appointmentId]!;
    }

    if (_processingAppointments.contains(appointmentId)) {
      return await _waitForResult(appointmentId);
    }

    _processingAppointments.add(appointmentId);

    try {
      final result = await _service.handleFinanceDepositConfirmation(
        appointmentId: appointmentId,
        token: token,
      );

      _processingResults[appointmentId] = result;
      return result;
    } finally {
      _processingAppointments.remove(appointmentId);
    }
  }

  Future<DepositConfirmationResult> _waitForResult(String appointmentId) async {
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (_processingResults.containsKey(appointmentId)) {
        return _processingResults[appointmentId]!;
      }

      if (!_processingAppointments.contains(appointmentId)) {
        break;
      }
    }

    // Timeout - return error
    return const DepositConfirmationResult(
      success: false,
      message: 'Request timeout. Please try again.',
      status: DepositResponseStatus.invalid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FutureBuilder<DepositConfirmationResult>(
                future: _confirmationFuture,
                builder: (context, snapshot) {
                  // Loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.hourglass_empty,
                          size: 64,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Please wait while we record your confirmation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 1.4),
                        ),
                        SizedBox(height: 16),
                        CircularProgressIndicator(),
                      ],
                    );
                  }

                  // Error state (unexpected errors)
                  if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Something went wrong',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                    );
                  }

                  // Success state - show result
                  final result = snapshot.data!;
                  final isError = !result.success;
                  final title = result.success
                      ? 'Deposit marked as received'
                      : 'Link issue';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 64,
                        color: isError ? Colors.redAccent : Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                      // Show proof of payment if available
                      if (_appointment != null &&
                          _appointment!.depositProofUrl != null &&
                          _appointment!.depositProofUrl!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Proof of Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final isPdf = _appointment!.depositProofUrl!
                                .toLowerCase()
                                .contains('.pdf');
                            return InkWell(
                              onTap: () => _showProofFile(
                                _appointment!.depositProofUrl!,
                                isPdf,
                              ),
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: isPdf
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.picture_as_pdf,
                                              size: 64,
                                              color: Colors.red[700],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'PDF Document',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to view',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Image.network(
                                        _appointment!.depositProofUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        if (_appointment!.depositProofUploadedByName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Uploaded by ${_appointment!.depositProofUploadedByName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                      // Show customer-uploaded proof if available
                      if (_appointment != null &&
                          _appointment!.customerUploadedProofUrl != null &&
                          _appointment!.customerUploadedProofUrl!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Customer Uploaded Proof',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_appointment!.customerProofVerified)
                              const Icon(Icons.verified, color: Colors.green, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final isPdf = _appointment!.customerUploadedProofUrl!
                                .toLowerCase()
                                .contains('.pdf');
                            return InkWell(
                              onTap: () => _showProofFile(
                                _appointment!.customerUploadedProofUrl!,
                                isPdf,
                              ),
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _appointment!.customerProofVerified
                                        ? Colors.green
                                        : Colors.orange,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: isPdf
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.picture_as_pdf,
                                              size: 64,
                                              color: Colors.red[700],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'PDF Document',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to view',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Image.network(
                                        _appointment!.customerUploadedProofUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        if (_appointment!.customerUploadedProofAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Uploaded by customer on ${_appointment!.customerUploadedProofAt.toString().split(' ')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_appointment!.customerProofVerified &&
                            _appointment!.customerProofVerifiedByName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Verified by ${_appointment!.customerProofVerifiedByName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProofFile(String fileUrl, bool isPdf) {
    if (isPdf) {
      // For PDF, open in a new browser tab
      if (kIsWeb) {
        // ignore: avoid_web_libraries_in_flutter
        html.window.open(fileUrl, '_blank');
      } else {
        // For mobile, show dialog (same as current implementation)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Proof of Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[700]),
                const SizedBox(height: 16),
                const Text('Click the button below to view the PDF document.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // On mobile, PDF viewing requires external app
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
              ),
            ],
          ),
        );
      }
    } else {
      // For images, show in dialog with zoom
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Proof of Payment'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    fileUrl,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
