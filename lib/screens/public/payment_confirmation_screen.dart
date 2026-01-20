import 'package:flutter/material.dart';

import '../../services/firebase/order_service.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String? orderId;
  final String? decision;
  final String? token;

  const PaymentConfirmationScreen({
    super.key,
    this.orderId,
    this.decision,
    this.token,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final _service = OrderService();

  String _title = 'Checking your response...';
  String _message = 'Please wait while we record your response.';
  bool _isError = false;
  bool _isLoaded = false;
  bool _isProcessing = false; // Prevent duplicate calls

  // Static set to track processing orders across widget recreations
  static final Set<String> _processingOrders = {};

  // Static map to store results across widget recreations
  static final Map<String, PaymentConfirmationResult> _processingResults = {};

  @override
  void initState() {
    super.initState();
    _processResponse();
  }

  Future<void> _processResponse() async {
    final orderId = widget.orderId;
    final decision = widget.decision?.toLowerCase();
    final token = widget.token;

    if (orderId == null || decision == null || token == null) {
      setState(() {
        _title = 'Missing information';
        _message = 'The confirmation link is missing some details.';
        _isError = true;
        _isLoaded = true;
      });
      return;
    }

    // Check if result already exists from another widget instance
    if (_processingResults.containsKey(orderId)) {
      final cachedResult = _processingResults[orderId]!;
      _updateUIWithResult(cachedResult);
      return;
    }

    // Prevent duplicate calls - check both instance flags and static set
    if (_isProcessing || _isLoaded) {
      return;
    }

    // If another widget is processing, wait for it
    if (_processingOrders.contains(orderId)) {
      _waitForResult(orderId);
      return;
    }

    _isProcessing = true;
    _processingOrders.add(orderId);

    final result = await _service.handlePaymentConfirmationResponse(
      orderId: orderId,
      decision: decision,
      token: token,
    );

    // Store result for other widget instances
    _processingResults[orderId] = result;

    // Clean up processing set
    _processingOrders.remove(orderId);

    if (!mounted) {
      return;
    }

    _updateUIWithResult(result);
  }

  void _updateUIWithResult(PaymentConfirmationResult result) {
    if (!mounted) return;

    setState(() {
      _isLoaded = true;
      _isError = !result.success;

      switch (result.status) {
        case PaymentResponseStatus.confirmed:
          _title = 'Thank you for your payment';
          _message = 'We have recorded your confirmation.';
          break;
        case PaymentResponseStatus.declined:
          _title = 'Thanks for letting us know';
          _message = 'We will send another mail in 2 days to verify again.';
          break;
        case PaymentResponseStatus.invalid:
          _title = 'Link issue';
          _message = result.message;
          break;
      }
    });
  }

  Future<void> _waitForResult(String orderId) async {
    // Poll for result with timeout
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (_processingResults.containsKey(orderId)) {
        final result = _processingResults[orderId]!;
        _updateUIWithResult(result);
        return;
      }

      if (!_processingOrders.contains(orderId)) {
        break;
      }
    }
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isError ? Icons.error_outline : Icons.check_circle_outline,
                    size: 64,
                    color: _isError ? Colors.redAccent : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  if (!_isLoaded) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

