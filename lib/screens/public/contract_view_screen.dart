import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contracts/contract.dart';
import '../../providers/contract_provider.dart';
import '../../theme/app_theme.dart';

/// Public contract viewing and signing screen (unauthenticated)
class ContractViewScreen extends StatefulWidget {
  final String contractId;
  final String? token;

  const ContractViewScreen({super.key, required this.contractId, this.token});

  @override
  State<ContractViewScreen> createState() => _ContractViewScreenState();
}

class _ContractViewScreenState extends State<ContractViewScreen> {
  final TextEditingController _signatureController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasAgreed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContract() async {
    final provider = context.read<ContractProvider>();
    final contract = await provider.loadContractByIdAndToken(
      widget.contractId,
      widget.token,
    );

    // Mark as viewed if successfully loaded and pending
    if (contract != null && contract.status == ContractStatus.pending) {
      await provider.markContractAsViewed(widget.contractId);
    }
  }

  Future<void> _handleSign() async {
    if (_isSubmitting) return;

    final signature = _signatureController.text.trim();

    if (signature.isEmpty) {
      _showError('Please enter your full legal name');
      return;
    }

    if (!_hasAgreed) {
      _showError('Please agree to the contract terms');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ContractProvider>();

      // In a real app, you would capture actual IP address from backend
      // For now, we'll use a placeholder
      final success = await provider.signContract(
        contractId: widget.contractId,
        digitalSignature: signature,
        ipAddress: 'client-ip', // TODO: Capture from backend/Firebase Function
        userAgent: 'Flutter App',
      );

      if (success && mounted) {
        setState(() => _isSubmitting = false);
        // Screen will automatically show signed view
      } else if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(provider.error ?? 'Failed to sign contract');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('An error occurred: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<ContractProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoading();
          }

          if (provider.error != null) {
            return _buildError(provider.error!);
          }

          final contract = provider.currentContract;
          if (contract == null) {
            return _buildError('Contract not found');
          }

          // Check if voided
          if (contract.status == ContractStatus.voided) {
            return _buildVoided(contract);
          }

          // Check if already signed
          if (contract.hasSigned) {
            return _buildSigned(contract);
          }

          // Active contract - show signing flow
          return _buildActiveContract(contract);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading contract...'),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Contract',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoided(Contract contract) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'Contract Voided',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This contract has been cancelled and is no longer valid.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (contract.voidReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  'Reason: ${contract.voidReason}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSigned(Contract contract) {
    final dateFormat = DateFormat('MMMM dd, yyyy \'at\' hh:mm a');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Contract Signed Successfully!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signed on ${dateFormat.format(contract.signedAt!)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Signature details
              _buildCard(
                title: 'Signature Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Signed by',
                      contract.digitalSignature ?? '-',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Signature ID',
                      contract.digitalSignatureToken ?? '-',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Customer', contract.customerName),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', contract.email),
                    const SizedBox(height: 12),
                    _buildInfoRow('Phone', contract.phone),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // PDF Download (if available)
              if (contract.pdfUrl != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final uri = Uri.parse(contract.pdfUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    } catch (e) {
                      _showError('Unable to download PDF: $e');
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Signed Contract PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Next steps - different messaging for full payment vs deposit
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: contract.isFullPayment ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: contract.isFullPayment ? Colors.green[200]! : Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          contract.isFullPayment ? Icons.star : Icons.info_outline,
                          color: contract.isFullPayment ? Colors.green[700] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'What\'s Next?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: contract.isFullPayment ? Colors.green[800] : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (contract.isFullPayment) ...[
                      // Full Payment messaging
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PRIORITY ORDER - Full Payment',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Thank you for choosing full payment! You will receive payment instructions via email shortly. '
                        'As a full payment customer, your order will receive priority scheduling for installation.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total Amount: R ${contract.subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ] else ...[
                      // Deposit messaging (original)
                      Text(
                        'You will receive deposit payment instructions via email shortly. '
                        'Please complete the payment to proceed with your order.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Deposit Amount: R ${contract.depositAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveContract(Contract contract) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(),
                    SizedBox(height: isMobile ? 20 : 32),

                    // Customer info
                    _buildCustomerInfo(contract),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Quote/Invoice
                    _buildQuoteSection(contract),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Contract content
                    _buildContractContent(contract),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Legal compliance
                    _buildLegalCompliance(),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Signature section
                    _buildSignatureSection(),
                    const SizedBox(height: 100), // Space for fixed button
                  ],
                ),
              ),
            ),
          ),
        ),

        // Fixed bottom button
        _buildFixedSignButton(),
      ],
    );
  }

  Widget _buildHeader() {
    // Use MediaQuery to make it responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo on the left - responsive sizing
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? 120 : 180,
              maxHeight: isMobile ? 40 : 60,
            ),
            child: Image.asset(
              'images/medwave_logo_white.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          // Title on the right - responsive sizing
          Expanded(
            flex: 3,
            child: Text(
              'Service Agreement',
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Contract contract) {
    return _buildCard(
      title: 'Customer Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Name', contract.customerName),
          const SizedBox(height: 12),
          _buildInfoRow('Email', contract.email),
          const SizedBox(height: 12),
          _buildInfoRow('Phone', contract.phone),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Date',
            DateFormat('MMMM dd, yyyy').format(contract.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection(Contract contract) {
    return _buildCard(
      title: 'Quote',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Products
          ...contract.products.map((product) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    'R ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(height: 32),

          // Pricing summary - right aligned like standard invoices
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Subtotal
              _buildPriceRow('Subtotal', contract.subtotal),
              const SizedBox(height: 12),

              // Deposit (40%)
              _buildPriceRow('Initial Deposit (40%)', contract.depositAmount),
              const SizedBox(height: 12),

              // Remaining balance (60%)
              _buildPriceRow(
                'Remaining Balance (60%)',
                contract.remainingBalance,
                isSubdued: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContractContent(Contract contract) {
    // Parse Quill Delta content and display as plain text for now
    // In a production app, you'd want to properly render the rich text
    final plainText =
        contract.contractContentData['plainText'] as String? ?? '';

    return _buildCard(
      title: 'Agreement Terms',
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          plainText,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }

  Widget _buildLegalCompliance() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: Colors.amber[900]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Legal Agreement',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'By signing below, you acknowledge that you have read, understood, '
            'and agree to be bound by all terms and conditions outlined in this agreement. '
            'Your electronic signature has the same legal effect as a handwritten signature.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() => _hasAgreed = !_hasAgreed);
            },
            child: Row(
              children: [
                Checkbox(
                  value: _hasAgreed,
                  onChanged: (value) {
                    setState(() => _hasAgreed = value ?? false);
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                Expanded(
                  child: Text(
                    'I have read and agree to the contract terms',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return _buildCard(
      title: 'Digital Signature',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type your full legal name as it appears on official documents:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signatureController,
            decoration: InputDecoration(
              hintText: 'John Doe',
              prefixIcon: const Icon(Icons.edit),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _buildFixedSignButton() {
    final canSign = _hasAgreed && _signatureController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canSign && !_isSubmitting ? _handleSign : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sign Contract',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isHighlighted = false,
    bool isSubdued = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlighted ? 18 : 16,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isSubdued ? Colors.grey[600] : Colors.black,
          ),
        ),
        Text(
          'R ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isHighlighted ? 20 : 16,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            color: isHighlighted
                ? AppTheme.primaryColor
                : (isSubdued ? Colors.grey[600] : Colors.black),
          ),
        ),
      ],
    );
  }
}
