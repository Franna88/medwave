import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/streams/order.dart';
import '../../models/installation/installation_signoff.dart';
import '../../providers/installation_signoff_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Widget showing installation sign-off status and actions for an order
class InstallationSignoffSectionWidget extends StatefulWidget {
  final Order order;
  final VoidCallback? onSignoffGenerated;
  final VoidCallback? onSignoffSigned;

  const InstallationSignoffSectionWidget({
    super.key,
    required this.order,
    this.onSignoffGenerated,
    this.onSignoffSigned,
  });

  @override
  State<InstallationSignoffSectionWidget> createState() =>
      _InstallationSignoffSectionWidgetState();
}

class _InstallationSignoffSectionWidgetState
    extends State<InstallationSignoffSectionWidget> {
  InstallationSignoff? _signoff;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSignoff();
  }

  Future<void> _loadSignoff() async {
    setState(() => _isLoading = true);

    final provider = context.read<InstallationSignoffProvider>();
    final signoffs = await provider.loadSignoffsByOrderId(widget.order.id);

    if (mounted) {
      setState(() {
        // Get the most recent sign-off
        _signoff = signoffs.isEmpty ? null : signoffs.first;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateSignoff() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Item Acknowledgement'),
        content: Text(
          'Generate an acknowledgement for ${widget.order.customerName}?\n\n'
          'This will create a secure link that can be sent to the customer for confirmation.',
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

    final provider = context.read<InstallationSignoffProvider>();
    final signoff = await provider.generateSignoffForOrder(
      order: widget.order,
      createdBy: userId,
      createdByName: userName ?? 'Unknown',
    );

    if (signoff != null && mounted) {
      setState(() => _signoff = signoff);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item acknowledgement generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSignoffGenerated?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to generate acknowledgement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    if (_signoff == null) return;

    final provider = context.read<InstallationSignoffProvider>();
    final url = provider.getFullSignoffUrl(_signoff!);

    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acknowledgement link copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewSignoff() {
    if (_signoff == null) return;

    final provider = context.read<InstallationSignoffProvider>();
    final url = provider.getFullSignoffUrl(_signoff!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Installation Sign-off Link'),
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

  @override
  Widget build(BuildContext context) {
    // Show only for Installed and Payment stages
    if (widget.order.currentStage != 'installed' &&
        widget.order.currentStage != 'payment') {
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
              Icon(Icons.assignment_turned_in,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Item Acknowledgement',
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
          else if (_signoff == null)
            _buildNoSignoff()
          else if (_signoff!.status == SignoffStatus.signed)
            _buildSigned()
          else
            _buildPending(),
        ],
      ),
    );
  }

  Widget _buildNoSignoff() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'No item acknowledgement has been generated yet.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _generateSignoff,
          icon: const Icon(Icons.add),
          label: const Text('Generate Acknowledgement'),
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
            color: _signoff!.status == SignoffStatus.viewed
                ? Colors.blue[100]
                : Colors.amber[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _signoff!.status == SignoffStatus.viewed
                ? 'Viewed - Pending Signature'
                : 'Pending Signature',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _signoff!.status == SignoffStatus.viewed
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
          dateFormat.format(_signoff!.createdAt),
        ),

        if (_signoff!.viewedAt != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.visibility,
            'Viewed',
            dateFormat.format(_signoff!.viewedAt!),
          ),
        ],

        const SizedBox(height: 16),

        // Actions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _viewSignoff,
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
          _signoff!.digitalSignature ?? '-',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          Icons.access_time,
          'Signed at',
          _signoff!.signedAt != null
              ? dateFormat.format(_signoff!.signedAt!)
              : '-',
        ),

        if (_signoff!.ipAddress != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(Icons.computer, 'IP Address', _signoff!.ipAddress!),
        ],

        const SizedBox(height: 12),

        // Acknowledged items
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Acknowledged Items:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              ..._signoff!.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.name} (${item.quantity})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Action buttons
        OutlinedButton.icon(
          onPressed: _viewSignoff,
          icon: const Icon(Icons.visibility, size: 18),
          label: const Text('View Acknowledgement'),
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
