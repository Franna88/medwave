import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/payment.dart';
import '../../models/appointment.dart';
import '../../services/paystack_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';

class PaymentQRDialog extends StatefulWidget {
  final Appointment appointment;
  final double amount;
  final String patientEmail;

  const PaymentQRDialog({
    super.key,
    required this.appointment,
    required this.amount,
    required this.patientEmail,
  });

  @override
  State<PaymentQRDialog> createState() => _PaymentQRDialogState();
}

class _PaymentQRDialogState extends State<PaymentQRDialog> {
  final PaystackService _paystackService = PaystackService();
  Payment? _payment;
  bool _isLoading = true;
  bool _isInitializing = false;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  StreamSubscription<Payment>? _paymentSubscription;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _paymentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      final settings = userProfileProvider.appSettings;

      if (!settings.sessionFeeEnabled) {
        throw Exception('Session fees are not enabled');
      }

      if (settings.paystackSecretKey == null || settings.paystackSecretKey!.isEmpty) {
        throw Exception('Paystack secret key not configured');
      }

      // Initialize payment with Paystack
      final payment = await _paystackService.initializePayment(
        patientId: widget.appointment.patientId,
        patientName: widget.appointment.patientName,
        practitionerId: widget.appointment.practitionerId ?? '',
        amount: widget.amount,
        email: widget.patientEmail,
        secretKey: settings.paystackSecretKey!,
        appointmentId: widget.appointment.id,
        currency: settings.currency,
        metadata: {
          'appointment_title': widget.appointment.title,
          'appointment_type': widget.appointment.type.name,
        },
      );

      setState(() {
        _payment = payment;
        _isLoading = false;
        _isInitializing = false;
      });

      // Start listening to payment updates
      _startPaymentStatusCheck();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isInitializing = false;
      });
    }
  }

  void _startPaymentStatusCheck() {
    if (_payment == null) return;

    // Listen to real-time updates from Firestore
    _paymentSubscription = _paystackService.streamPayment(_payment!.id).listen(
      (updatedPayment) {
        if (mounted) {
          setState(() {
            _payment = updatedPayment;
          });

          // Show success if payment completed
          if (updatedPayment.isCompleted) {
            _showPaymentSuccess();
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error monitoring payment: $error';
          });
        }
      },
    );

    // Also check periodically via API (every 10 seconds)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_payment == null) return;

    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      final settings = userProfileProvider.appSettings;

      if (settings.paystackSecretKey == null) return;

      final updatedPayment = await _paystackService.verifyPayment(
        paymentId: _payment!.id,
        reference: _payment!.paymentReference,
        secretKey: settings.paystackSecretKey!,
      );

      if (mounted) {
        setState(() {
          _payment = updatedPayment;
        });
      }
    } catch (e) {
      // Silently fail - we'll try again in 10 seconds
      debugPrint('Error checking payment status: $e');
    }
  }

  void _showPaymentSuccess() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment of ${_payment!.formattedAmount} received',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close success dialog
              Navigator.of(context).pop(_payment); // Close QR dialog with payment
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: const Text(
          'Are you sure you want to mark this payment as completed? '
          'This should only be used for cash payments or when payment was received outside the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true && _payment != null) {
      try {
        final updatedPayment = await _paystackService.markPaymentAsCompleted(
          paymentId: _payment!.id,
          notes: 'Manually marked as paid by practitioner',
        );

        if (mounted) {
          setState(() {
            _payment = updatedPayment;
          });
          _showPaymentSuccess();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text('Are you sure you want to cancel this payment request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && _payment != null) {
      try {
        await _paystackService.cancelPayment(
          paymentId: _payment!.id,
          reason: 'Cancelled by practitioner',
        );

        if (mounted) {
          Navigator.of(context).pop(null);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment QR Code'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildQRCodeState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _isInitializing ? 'Initializing payment...' : 'Loading...',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Initialization Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializePayment,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeState() {
    if (_payment == null) {
      return const Center(child: Text('No payment data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Payment status indicator
          if (_payment!.isCompleted)
            _buildStatusBadge(
              'Payment Completed',
              AppTheme.successColor,
              Icons.check_circle,
            )
          else if (_payment!.isFailed)
            _buildStatusBadge(
              'Payment Failed',
              AppTheme.errorColor,
              Icons.error,
            )
          else
            _buildStatusBadge(
              'Awaiting Payment',
              AppTheme.warningColor,
              Icons.pending,
            ),

          const SizedBox(height: 24),

          // Patient and appointment info
          _buildInfoCard(),

          const SizedBox(height: 24),

          // QR Code
          if (!_payment!.isCompleted && _payment!.authorizationUrl != null)
            _buildQRCode(),

          const SizedBox(height: 24),

          // Instructions
          if (!_payment!.isCompleted) _buildInstructions(),

          const SizedBox(height: 24),

          // Action buttons
          if (!_payment!.isCompleted) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      widget.appointment.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.event, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      widget.appointment.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.payments, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Fee',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _payment!.formattedAmount,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          QrImageView(
            data: _payment!.authorizationUrl!,
            version: QrVersions.auto,
            size: 280,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          ),
          const SizedBox(height: 16),
          Text(
            'Reference: ${_payment!.paymentReference}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '1',
            'Open your banking app (ABSA, Capitec, Nedbank, Standard Bank, or FNB)',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            '2',
            'Select "Scan to Pay" or QR payment option',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            '3',
            'Scan the QR code above',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(
            '4',
            'Confirm the payment in your banking app',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _markAsPaid,
            icon: const Icon(Icons.check),
            label: const Text('Mark as Paid (Cash)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancelPayment,
            icon: const Icon(Icons.close),
            label: const Text('Cancel Payment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

