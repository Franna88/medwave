import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Result data from stage transition dialog
class StageTransitionResult {
  final dynamic note; // Can be String or Map<String, dynamic> for questionnaire
  final double? amount;
  final String? invoiceNumber;

  StageTransitionResult({required this.note, this.amount, this.invoiceNumber});
}

/// Dialog for confirming stage transition and requiring a note
class StageTransitionDialog extends StatefulWidget {
  final String fromStage;
  final String toStage;
  final String toStageId;

  const StageTransitionDialog({
    super.key,
    required this.fromStage,
    required this.toStage,
    required this.toStageId,
  });

  @override
  State<StageTransitionDialog> createState() => _StageTransitionDialogState();
}

class _StageTransitionDialogState extends State<StageTransitionDialog> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _requiresPaymentInfo {
    return widget.toStageId == 'deposit_made' ||
        widget.toStageId == 'cash_collected';
  }

  String get _paymentLabel {
    return widget.toStageId == 'deposit_made' ? 'Deposit' : 'Cash Collected';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Move Lead',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stage transition visual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.fromStage,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.toStage,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment info fields (if required)
              if (_requiresPaymentInfo) ...[
                Text(
                  '$_paymentLabel Information *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount *',
                          prefixText: 'R ',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final amount = double.tryParse(value.trim());
                          if (amount == null || amount <= 0) {
                            return 'Invalid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _invoiceController,
                        decoration: InputDecoration(
                          labelText: 'Invoice Number *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Note field
              Text(
                'Add a note about this transition *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: _requiresPaymentInfo
                      ? 'e.g., Payment received via bank transfer, client satisfied...'
                      : 'e.g., Called and confirmed interest, scheduled follow-up...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please add a note about this transition';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more details (at least 10 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final result = StageTransitionResult(
                          note: _noteController.text.trim(),
                          amount: _requiresPaymentInfo
                              ? double.tryParse(_amountController.text.trim())
                              : null,
                          invoiceNumber: _requiresPaymentInfo
                              ? _invoiceController.text.trim()
                              : null,
                        );
                        Navigator.of(context).pop(result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Confirm Move'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
