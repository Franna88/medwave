import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';

/// Screen for practitioners to manually enter their bank account details
/// Bank details are stored for manual payouts by superadmin
class BankAccountSetupScreen extends StatefulWidget {
  const BankAccountSetupScreen({super.key});

  @override
  State<BankAccountSetupScreen> createState() => _BankAccountSetupScreenState();
}

class _BankAccountSetupScreenState extends State<BankAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _branchCodeController = TextEditingController();
  
  String? _selectedBank;
  bool _isSaving = false;

  // Hardcoded list of major South African banks
  final List<String> _banks = [
    'ABSA Bank',
    'African Bank',
    'Capitec Bank',
    'Discovery Bank',
    'First National Bank (FNB)',
    'Investec Bank',
    'Nedbank',
    'Standard Bank',
    'TymeBank',
  ];

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  /// Save bank account details to user profile
  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userProfileProvider = context.read<UserProfileProvider>();
    final userProfile = userProfileProvider.userProfile;

    if (userProfile == null) {
      _showErrorSnackBar('User profile not found');
      return;
    }

    // Confirm with user
    final confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Update user profile with bank details
      final success = await userProfileProvider.updateProfile(
        bankName: _selectedBank!,
        bankAccountNumber: _accountNumberController.text.trim(),
        bankAccountName: _accountHolderController.text.trim(),
        bankCode: _branchCodeController.text.trim(), // Using branch code
        subaccountCreatedAt: DateTime.now(),
      );

      setState(() {
        _isSaving = false;
      });

      if (success) {
        _showSuccessSnackBar('Bank account details saved successfully!');

        // Navigate back
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showErrorSnackBar('Failed to save bank details. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      _showErrorSnackBar('Failed to save bank account. Please try again.');
    }
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bank Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please confirm your bank account details:'),
            const SizedBox(height: 16),
            _buildDetailRow('Bank', _selectedBank!),
            _buildDetailRow('Account Holder', _accountHolderController.text),
            _buildDetailRow('Account Number', _accountNumberController.text),
            _buildDetailRow('Branch Code', _branchCodeController.text),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payouts will be processed manually by admin to this account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bank Account'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 32),

              // Bank selection
              _buildBankDropdown(),
              const SizedBox(height: 16),

              // Account holder name
              _buildAccountHolderField(),
              const SizedBox(height: 16),

              // Account number input
              _buildAccountNumberField(),
              const SizedBox(height: 16),

              // Branch code input
              _buildBranchCodeField(),
              const SizedBox(height: 32),

              // Save button
              _buildSaveButton(),

              const SizedBox(height: 24),

              // Help text
              _buildHelpText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_balance,
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Add Your Bank Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your bank details for receiving payouts',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBank,
      decoration: InputDecoration(
        labelText: 'Select Bank *',
        prefixIcon: Icon(Icons.account_balance, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      items: _banks.map((bank) {
        return DropdownMenuItem<String>(
          value: bank,
          child: Text(bank),
        );
      }).toList(),
      onChanged: (bank) {
        setState(() {
          _selectedBank = bank;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a bank';
        }
        return null;
      },
    );
  }

  Widget _buildAccountHolderField() {
    return TextFormField(
      controller: _accountHolderController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Account Holder Name *',
        hintText: 'Enter full name as per bank account',
        prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter account holder name';
        }
        if (value.length < 3) {
          return 'Name must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildAccountNumberField() {
    return TextFormField(
      controller: _accountNumberController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        labelText: 'Account Number *',
        hintText: 'Enter your account number',
        prefixIcon: Icon(Icons.numbers, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter account number';
        }
        if (value.length < 10) {
          return 'Account number must be at least 10 digits';
        }
        return null;
      },
    );
  }

  Widget _buildBranchCodeField() {
    return TextFormField(
      controller: _branchCodeController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: 'Branch Code *',
        hintText: 'Enter bank branch code',
        prefixIcon: Icon(Icons.business, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        helperText: 'Usually 6 digits (check your bank statement)',
        helperMaxLines: 2,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter branch code';
        }
        if (value.length < 4) {
          return 'Branch code must be at least 4 digits';
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveBankDetails,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.save),
      label: Text(_isSaving ? 'Saving...' : 'Save Bank Account'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.successColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Important Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(Icons.check_circle_outline, 
            'Bank details are securely stored and encrypted'),
          _buildInfoItem(Icons.payment, 
            'Payouts will be processed manually by admin'),
          _buildInfoItem(Icons.schedule, 
            'Payouts are typically processed within 48 hours'),
          _buildInfoItem(Icons.account_balance_wallet, 
            'You can view payout history in your dashboard'),
          const SizedBox(height: 12),
          Text(
            'Double-check your bank details before saving. Incorrect details may cause payout delays.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
