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

  String _title = 'Processing...';
  String _message = 'Please wait while we record your confirmation.';
  bool _isError = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final appointmentId = widget.appointmentId;
    final token = widget.token;

    if (appointmentId == null || token == null) {
      setState(() {
        _title = 'Missing information';
        _message = 'The confirmation link is missing some details.';
        _isError = true;
        _isLoaded = true;
      });
      return;
    }

    final result = await _service.handleFinanceDepositConfirmation(
      appointmentId: appointmentId,
      token: token,
    );

    if (!mounted) return;

    setState(() {
      _isLoaded = true;
      _isError = !result.success;
      _title = result.success ? 'Deposit marked received' : 'Link issue';
      _message = result.message;
    });
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
