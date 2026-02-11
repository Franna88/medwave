import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  
  // Upload section state
  bool _showUploadSection = false;
  bool _isUploading = false;
  String? _uploadedProofUrl;
  PaymentResponseStatus? _responseStatus;

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
      _responseStatus = result.status;

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

  Future<void> _pickAndUploadFile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    await _uploadProof(bytes, image.name);
  }

  Future<void> _pickAndUploadPdf() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF upload is only supported on web.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = await _pickPdfWeb();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await _uploadProof(bytes, file.name);
  }

  Future<XFile?> _pickPdfWeb() async {
    if (!kIsWeb) return null;

    final completer = Completer<XFile?>();
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'application/pdf,.pdf';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as List<int>;
          final xFile = XFile.fromData(
            Uint8List.fromList(bytes),
            name: file.name,
            mimeType: 'application/pdf',
          );
          completer.complete(xFile);
        });
      } else {
        completer.complete(null);
      }
    });

    Future.delayed(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  Future<void> _uploadProof(Uint8List bytes, String fileName) async {
    setState(() => _isUploading = true);

    final result = await _service.uploadCustomerFinalPaymentProof(
      orderId: widget.orderId!,
      fileData: bytes,
      fileName: fileName,
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (result.success) {
          _uploadedProofUrl = result.proofUrl;
          _showUploadSection = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload, size: 48, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            'Upload Proof of Payment',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload an image or PDF of your payment proof to help us process faster.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_isUploading)
            const CircularProgressIndicator()
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.image),
                  label: const Text('Image'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickAndUploadPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                ),
              ],
            ),
        ],
      ),
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
                  // Show upload button only for confirmed status and if not error
                  if (_isLoaded &&
                      !_isError &&
                      _responseStatus == PaymentResponseStatus.confirmed &&
                      !_showUploadSection &&
                      _uploadedProofUrl == null) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showUploadSection = true),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Proof of Payment'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                  // Show upload section
                  if (_showUploadSection && _uploadedProofUrl == null) ...[
                    const SizedBox(height: 24),
                    _buildUploadSection(),
                  ],
                  // Show success message after upload
                  if (_uploadedProofUrl != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 48),
                          SizedBox(height: 8),
                          Text(
                            'Proof of payment uploaded successfully!',
                            style: TextStyle(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Our team will verify your proof and process your order.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
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
