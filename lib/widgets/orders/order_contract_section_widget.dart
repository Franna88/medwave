import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/streams/order.dart' as models;
import '../../models/contracts/contract.dart';
import '../../providers/contract_provider.dart';
import '../../theme/app_theme.dart';

/// Read-only widget showing agreement status and View Agreement CTA for an order.
/// Used in the Operations stream Order Detail Dialog.
class OrderContractSectionWidget extends StatefulWidget {
  final models.Order order;

  const OrderContractSectionWidget({super.key, required this.order});

  @override
  State<OrderContractSectionWidget> createState() =>
      _OrderContractSectionWidgetState();
}

class _OrderContractSectionWidgetState
    extends State<OrderContractSectionWidget> {
  Contract? _contract;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  Future<void> _loadContract() async {
    if (widget.order.appointmentId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<ContractProvider>();
    final contracts = await provider.loadContractsByAppointmentId(
      widget.order.appointmentId,
    );

    if (mounted) {
      setState(() {
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

  Future<void> _viewContract() async {
    if (_contract == null) return;

    try {
      Uri uri;
      if (_contract!.pdfUrl != null && _contract!.pdfUrl!.isNotEmpty) {
        uri = Uri.parse(_contract!.pdfUrl!);
      } else {
        final provider = context.read<ContractProvider>();
        final url = provider.getFullContractUrl(_contract!);
        uri = Uri.parse(url);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open agreement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening agreement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Agreement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_contract == null || widget.order.appointmentId.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              'No signed agreement available',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorFromHex(
                      _contract!.statusColor,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _colorFromHex(_contract!.statusColor),
                    ),
                  ),
                  child: Text(
                    _contract!.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _colorFromHex(_contract!.statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewContract,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Agreement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Color _colorFromHex(String hex) {
  final hexCode = hex.replaceAll('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}
