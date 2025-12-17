import 'package:flutter/material.dart';

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

  // Static state to handle widget recreation
  static final Set<String> _processingAppointments = {};
  static final Map<String, DepositConfirmationResult> _processingResults = {};

  @override
  void initState() {
    super.initState();
    // Initialize once - survives widget rebuilds
    _confirmationFuture = _processConfirmation();
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
}
