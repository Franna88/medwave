import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'invoice_redirect_stub.dart'
    if (dart.library.html) 'invoice_redirect_web.dart'
    as redirect;

import '../../services/firebase/order_service.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String? orderId;
  final String? token;

  const InvoiceViewScreen({super.key, this.orderId, this.token});

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  final _service = OrderService();

  /// Invoice PDF URL once loaded; null while loading or on error.
  String? _invoicePdfUrl;

  /// Error message if PDF URL could not be resolved.
  String? _pdfError;

  /// Prevents redirect from running more than once.
  bool _redirected = false;

  // Static state to handle widget recreation
  static final Set<String> _processingOrders = {};
  static final Map<String, bool> _processingResults = {};

  @override
  void initState() {
    super.initState();
    // Send payment confirmation email when customer opens the link
    _processInvoiceView();
    // Pre-fetch PDF URL then redirect to it
    _loadInvoicePdfUrl();
  }

  /// Load invoice PDF URL and store in state; do not open/launch.
  Future<void> _loadInvoicePdfUrl() async {
    final orderId = widget.orderId;
    final token = widget.token;

    if (orderId == null || token == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _pdfError = null;
        _invoicePdfUrl = null;
      });
    }

    try {
      final order = await _service.getOrder(orderId);
      if (order == null) {
        if (mounted) {
          setState(() => _pdfError = 'Order not found');
        }
        return;
      }

      if (order.paymentConfirmationToken != token) {
        if (mounted) {
          setState(() => _pdfError = 'Invalid link');
        }
        return;
      }

      String? pdfUrl = order.invoicePdfUrl;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        try {
          final storage = FirebaseStorage.instance;
          final ref = storage.ref().child(
            'invoices/$orderId/invoice_$orderId.pdf',
          );
          pdfUrl = await ref.getDownloadURL();
        } catch (e) {
          if (kDebugMode) {
            print('Could not get invoice PDF URL: $e');
          }
          if (mounted) {
            setState(() => _pdfError = 'Invoice could not be loaded');
          }
          return;
        }
      }

      if (pdfUrl.isNotEmpty && mounted) {
        setState(() {
          _invoicePdfUrl = pdfUrl;
          _pdfError = null;
        });
        _redirectToPdf();
      } else if (mounted) {
        setState(() => _pdfError = 'Invoice could not be loaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading invoice: $e');
      }
      if (mounted) {
        setState(() => _pdfError = 'Invoice could not be loaded');
      }
    }
  }

  /// Redirect current tab to PDF (web) or open in external app (non-web).
  void _redirectToPdf() {
    final url = _invoicePdfUrl;
    if (url == null || url.isEmpty || _redirected) return;
    _redirected = true;
    if (kIsWeb) {
      redirect.redirectToPdf(url);
    } else {
      final uri = Uri.parse(url);
      canLaunchUrl(uri).then((ok) {
        if (ok) launchUrl(uri, mode: LaunchMode.externalApplication);
      });
    }
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
        child: _pdfError != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Invoice could not be opened. Please contact support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _loadInvoicePdfUrl,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try again'),
                  ),
                ],
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening your invoice…'),
                ],
              ),
      ),
    );
  }
}
