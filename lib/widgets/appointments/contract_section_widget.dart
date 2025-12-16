import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/streams/appointment.dart';
import '../../models/contracts/contract.dart';
import '../../providers/contract_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Widget showing contract status and actions for an appointment
class ContractSectionWidget extends StatefulWidget {
  final SalesAppointment appointment;
  final VoidCallback? onContractGenerated;
  final VoidCallback? onContractSigned;

  const ContractSectionWidget({
    super.key,
    required this.appointment,
    this.onContractGenerated,
    this.onContractSigned,
  });

  @override
  State<ContractSectionWidget> createState() => _ContractSectionWidgetState();
}

class _ContractSectionWidgetState extends State<ContractSectionWidget> {
  Contract? _contract;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  Future<void> _loadContract() async {
    setState(() => _isLoading = true);

    final provider = context.read<ContractProvider>();
    final contracts = await provider.loadContractsByAppointmentId(
      widget.appointment.id,
    );

    if (mounted) {
      setState(() {
        // Get the most recent non-voided contract
        _contract = contracts.isEmpty
            ? null
            : contracts.firstWhere(
                (c) => c.status != ContractStatus.voided,
                orElse: () => contracts.first,
              );
        _isLoading = false;
      });
    }
  }

  Future<void> _generateContract() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Contract'),
        content: Text(
          'Generate a contract for ${widget.appointment.customerName}?\n\n'
          'This will create a secure link that can be sent to the customer for signing.',
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
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ContractProvider>();
    final contract = await provider.generateContractForAppointment(
      appointment: widget.appointment,
      createdBy: userId,
      createdByName: userName ?? 'Unknown',
    );

    if (contract != null && mounted) {
      setState(() => _contract = contract);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onContractGenerated?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to generate contract'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    if (_contract == null) return;

    final provider = context.read<ContractProvider>();
    final url = provider.getFullContractUrl(_contract!);

    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract link copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _voidContract() async {
    if (_contract == null) return;

    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Contract'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to void this contract? This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Void Contract'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final reason = reasonController.text.trim();
    reasonController.dispose();

    final provider = context.read<ContractProvider>();
    final success = await provider.voidContract(
      contractId: _contract!.id,
      voidedBy: userId,
      voidReason: reason.isEmpty ? null : reason,
    );

    if (success && mounted) {
      await _loadContract(); // Reload

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract voided successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to void contract'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewContract() {
    if (_contract == null) return;

    final provider = context.read<ContractProvider>();
    final url = provider.getFullContractUrl(_contract!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contract Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy this link to share with the customer:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(url, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyLink();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPdf() async {
    if (_contract?.pdfUrl == null) return;

    try {
      final uri = Uri.parse(_contract!.pdfUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open PDF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show for Opt In stage
    if (widget.appointment.currentStage != 'opt_in') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Contract',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_contract == null)
            _buildNoContract()
          else if (_contract!.status == ContractStatus.signed)
            _buildSigned()
          else if (_contract!.status == ContractStatus.voided)
            _buildVoided()
          else
            _buildPending(),
        ],
      ),
    );
  }

  Widget _buildNoContract() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'No contract has been generated yet.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _generateContract,
          icon: const Icon(Icons.add),
          label: const Text('Generate Contract'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPending() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _contract!.status == ContractStatus.viewed
                ? Colors.blue[100]
                : Colors.amber[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _contract!.status == ContractStatus.viewed
                ? 'Viewed - Pending Signature'
                : 'Pending Signature',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _contract!.status == ContractStatus.viewed
                  ? Colors.blue[900]
                  : Colors.amber[900],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Created date
        _buildInfoRow(
          Icons.calendar_today,
          'Created',
          dateFormat.format(_contract!.createdAt),
        ),

        if (_contract!.viewedAt != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.visibility,
            'Viewed',
            dateFormat.format(_contract!.viewedAt!),
          ),
        ],

        const SizedBox(height: 16),

        // Actions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _viewContract,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('View Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Link'),
            ),
            OutlinedButton.icon(
              onPressed: _voidContract,
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Void'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSigned() {
    final dateFormat = DateFormat('MMM dd, yyyy \'at\' hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green[900]),
              const SizedBox(width: 4),
              Text(
                'Signed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildInfoRow(
          Icons.person,
          'Signed by',
          _contract!.digitalSignature ?? '-',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          Icons.access_time,
          'Signed at',
          _contract!.signedAt != null
              ? dateFormat.format(_contract!.signedAt!)
              : '-',
        ),

        if (_contract!.ipAddress != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(Icons.computer, 'IP Address', _contract!.ipAddress!),
        ],

        const SizedBox(height: 12),

        // Note about stage movement
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lead will automatically move to Deposit Requested',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _viewContract,
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Contract'),
              ),
            ),
            if (_contract!.pdfUrl != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildVoided() {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Voided',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red[900],
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildInfoRow(
          Icons.block,
          'Voided at',
          _contract!.voidedAt != null
              ? dateFormat.format(_contract!.voidedAt!)
              : '-',
        ),

        if (_contract!.voidReason != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(Icons.notes, 'Reason', _contract!.voidReason!),
        ],

        const SizedBox(height: 12),

        // Generate new contract button
        ElevatedButton.icon(
          onPressed: _generateContract,
          icon: const Icon(Icons.refresh),
          label: const Text('Generate New Contract'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
