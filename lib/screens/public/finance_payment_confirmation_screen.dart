import 'package:flutter/material.dart';

import '../../services/firebase/order_service.dart';

class FinancePaymentConfirmationScreen extends StatefulWidget {
  final String? orderId;
  final String? token;

  const FinancePaymentConfirmationScreen({
    super.key,
    this.orderId,
    this.token,
  });

  @override
  State<FinancePaymentConfirmationScreen> createState() =>
      _FinancePaymentConfirmationScreenState();
}

class _FinancePaymentConfirmationScreenState
    extends State<FinancePaymentConfirmationScreen> {
  final _service = OrderService();
  late final Future<PaymentConfirmationResult> _confirmationFuture;

  // Static state to handle widget recreation
  static final Set<String> _processingOrders = {};
  static final Map<String, PaymentConfirmationResult> _processingResults = {};

  @override
  void initState() {
    super.initState();
    // Initialize once - survives widget rebuilds
    _confirmationFuture = _processConfirmation();
  }

  Future<PaymentConfirmationResult> _processConfirmation() async {
    final orderId = widget.orderId;
    final token = widget.token;

    if (orderId == null || token == null) {
      return const PaymentConfirmationResult(
        success: false,
        message: 'The confirmation link is missing some details.',
        status: PaymentResponseStatus.invalid,
      );
    }

    if (_processingResults.containsKey(orderId)) {
      return _processingResults[orderId]!;
    }

    if (_processingOrders.contains(orderId)) {
      return await _waitForResult(orderId);
    }

    _processingOrders.add(orderId);

    try {
      final result = await _service.handleFinancePaymentConfirmation(
        orderId: orderId,
        token: token,
      );

      _processingResults[orderId] = result;
      return result;
    } finally {
      _processingOrders.remove(orderId);
    }
  }

  Future<PaymentConfirmationResult> _waitForResult(String orderId) async {
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (_processingResults.containsKey(orderId)) {
        return _processingResults[orderId]!;
      }

      if (!_processingOrders.contains(orderId)) {
        break;
      }
    }

    return const PaymentConfirmationResult(
      success: false,
      message: 'Timeout waiting for confirmation.',
      status: PaymentResponseStatus.invalid,
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
              child: FutureBuilder<PaymentConfirmationResult>(
                future: _confirmationFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing confirmation...'),
                      ],
                    );
                  }

                  final result = snapshot.data;
                  if (result == null) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Unable to process confirmation.'),
                      ],
                    );
                  }

                  final isSuccess = result.success;
                  final isConfirmed = result.status == PaymentResponseStatus.confirmed;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 64,
                        color: isSuccess ? Colors.green : Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSuccess
                            ? (isConfirmed
                                ? 'Payment Confirmed'
                                : 'Confirmation Recorded')
                            : 'Error',
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

