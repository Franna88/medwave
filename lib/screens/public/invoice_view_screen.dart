import 'package:flutter/material.dart';

import '../../services/firebase/order_service.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String? orderId;
  final String? token;

  const InvoiceViewScreen({
    super.key,
    this.orderId,
    this.token,
  });

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  final _service = OrderService();
  late final Future<bool> _emailFuture;

  // Static state to handle widget recreation
  static final Set<String> _processingOrders = {};
  static final Map<String, bool> _processingResults = {};

  @override
  void initState() {
    super.initState();
    // Initialize once - survives widget rebuilds
    _emailFuture = _processInvoiceView();
  }

  Future<bool> _processInvoiceView() async {
    final orderId = widget.orderId;
    final token = widget.token;

    if (orderId == null || token == null) {
      return false;
    }

    if (_processingResults.containsKey(orderId)) {
      return _processingResults[orderId]!;
    }

    if (_processingOrders.contains(orderId)) {
      return await _waitForResult(orderId);
    }

    _processingOrders.add(orderId);

    try {
      final result = await _service.sendPaymentConfirmationEmailAfterInvoice(
        orderId: orderId,
        token: token,
      );

      _processingResults[orderId] = result;
      return result;
    } finally {
      _processingOrders.remove(orderId);
    }
  }

  Future<bool> _waitForResult(String orderId) async {
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (_processingResults.containsKey(orderId)) {
        return _processingResults[orderId]!;
      }

      if (!_processingOrders.contains(orderId)) {
        break;
      }
    }

    return false;
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
              child: FutureBuilder<bool>(
                future: _emailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading invoice...'),
                      ],
                    );
                  }

                  final emailSent = snapshot.data ?? false;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        emailSent
                            ? Icons.receipt_long
                            : Icons.error_outline,
                        size: 64,
                        color: emailSent
                            ? const Color(0xFF162694)
                            : Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Invoice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.orderId != null) ...[
                        Text(
                          'Order ID: ${widget.orderId}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        emailSent
                            ? 'Your invoice is being processed. You will receive a payment confirmation email shortly.'
                            : 'Unable to process invoice. Please contact support.',
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
