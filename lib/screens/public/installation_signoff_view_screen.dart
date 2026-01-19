import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/installation/installation_signoff.dart';
import '../../providers/installation_signoff_provider.dart';
import '../../theme/app_theme.dart';

/// Public installation sign-off viewing and signing screen (unauthenticated)
class InstallationSignoffViewScreen extends StatefulWidget {
  final String signoffId;
  final String? token;

  const InstallationSignoffViewScreen({
    super.key,
    required this.signoffId,
    this.token,
  });

  @override
  State<InstallationSignoffViewScreen> createState() =>
      _InstallationSignoffViewScreenState();
}

class _InstallationSignoffViewScreenState
    extends State<InstallationSignoffViewScreen> {
  final TextEditingController _signatureController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasAgreed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSignoff();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSignoff() async {
    final provider = context.read<InstallationSignoffProvider>();
    final signoff = await provider.loadSignoffByIdAndToken(
      widget.signoffId,
      widget.token,
    );

    // Mark as viewed if successfully loaded and pending
    if (signoff != null && signoff.status == SignoffStatus.pending) {
      await provider.markSignoffAsViewed(widget.signoffId);
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
      _showError('Please agree to confirm receipt');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<InstallationSignoffProvider>();
      final signoff = provider.currentSignoff;

      // Auto-fill all items as confirmed
      final itemsConfirmed = <String, bool>{};
      if (signoff != null) {
        for (final item in signoff.items) {
          itemsConfirmed[item.name] = true;
        }
      }

      final success = await provider.signSignoff(
        signoffId: widget.signoffId,
        digitalSignature: signature,
        itemsConfirmed: itemsConfirmed,
        ipAddress: 'client-ip', // TODO: Capture from backend/Firebase Function
        userAgent: 'Flutter App',
      );

      if (success && mounted) {
        setState(() => _isSubmitting = false);
        // Screen will automatically show signed view
      } else if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(provider.error ?? 'Failed to sign');
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
      body: Consumer<InstallationSignoffProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoading();
          }

          if (provider.error != null) {
            return _buildError(provider.error!);
          }

          final signoff = provider.currentSignoff;
          if (signoff == null) {
            return _buildError('Installation sign-off not found');
          }

          // Check if already signed
          if (signoff.hasSigned) {
            return _buildSigned(signoff);
          }

          // Active sign-off - show signing flow
          return _buildActiveSignoff(signoff);
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
          Text('Loading installation sign-off...'),
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
              'Unable to Load Sign-off',
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

  Widget _buildSigned(InstallationSignoff signoff) {
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
                      'Receipt Confirmed Successfully!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signed on ${dateFormat.format(signoff.signedAt!)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Signature details
              _buildCard(
                title: 'Confirmation Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Confirmed by',
                      signoff.digitalSignature ?? '-',
                    ),
                    if (signoff.digitalSignatureToken != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Confirmation ID',
                        signoff.digitalSignatureToken!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoRow('Customer', signoff.customerName),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', signoff.email),
                    const SizedBox(height: 12),
                    _buildInfoRow('Phone', signoff.phone),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Acknowledged items
              _buildCard(
                title: 'Acknowledged Items',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: signoff.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.name} (Qty: ${item.quantity})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Thank you message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Thank You!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Thank you for confirming your installation. Your confirmation has been recorded for our records.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSignoff(InstallationSignoff signoff) {
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
                    _buildCustomerInfo(signoff),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Items acknowledgement
                    _buildItemsAcknowledgement(signoff),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Signature section
                    _buildSignatureSection(),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Acknowledgment
                    _buildAcknowledgment(),
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
          Expanded(
            flex: 3,
            child: Text(
              'Installation Sign-off',
              style: TextStyle(
                fontSize: isMobile ? 14 : 28,
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

  Widget _buildCustomerInfo(InstallationSignoff signoff) {
    return _buildCard(
      title: 'Customer Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Name', signoff.customerName),
          const SizedBox(height: 12),
          _buildInfoRow('Email', signoff.email),
          const SizedBox(height: 12),
          _buildInfoRow('Phone', signoff.phone),
          if (signoff.deliveryAddress != null &&
              signoff.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Delivery Address', signoff.deliveryAddress!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            'Date',
            DateFormat('MMMM dd, yyyy').format(signoff.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsAcknowledgement(InstallationSignoff signoff) {
    return _buildCard(
      title: 'Item Acknowledgement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The following items were delivered/installed:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ...signoff.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} (Qty: ${item.quantity})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAcknowledgment() {
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
              Icon(Icons.assignment_turned_in, color: Colors.amber[900]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Acknowledgement',
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
            'By signing below, you acknowledge receipt and acceptance of the items listed above.',
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
                    'I acknowledge receipt and accept the items listed above',
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
                    'Confirm Receipt',
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
}
