import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/streams/order.dart' as models;
import '../../models/admin/installer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/installer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/firebase/order_service.dart';
import '../../theme/app_theme.dart';

class OrderDetailDialog extends StatefulWidget {
  final models.Order order;
  final VoidCallback? onOrderUpdated;

  const OrderDetailDialog({
    super.key,
    required this.order,
    this.onOrderUpdated,
  });

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  final OrderService _orderService = OrderService();
  late models.Order _currentOrder;

  bool _isSendingEmail = false;
  bool _isSavingInstaller = false;
  bool _isSavingDate = false;
  String? _selectedInstallerId;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _selectedInstallerId = widget.order.assignedInstallerId;
  }

  Future<void> _sendBookingEmail() async {
    setState(() => _isSendingEmail = true);

    try {
      final sent = await _orderService.sendInstallationBookingEmail(
        orderId: _currentOrder.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? 'Installation booking email sent!'
                  : 'Failed to send email. Please try again.',
            ),
            backgroundColor: sent ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  Future<void> _assignInstaller(Installer installer) async {
    setState(() => _isSavingInstaller = true);

    try {
      await _orderService.assignInstaller(
        orderId: _currentOrder.id,
        installerId: installer.id,
        installerName: installer.fullName,
      );

      setState(() {
        _selectedInstallerId = installer.id;
        _currentOrder = _currentOrder.copyWith(
          assignedInstallerId: installer.id,
          assignedInstallerName: installer.fullName,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installer ${installer.fullName} assigned'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onOrderUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning installer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingInstaller = false);
      }
    }
  }

  Future<void> _setInstallDate() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    // Show date picker starting from customer's earliest selected date or now
    final initialDate = _currentOrder.earliestSelectedDate ??
        DateTime.now().add(const Duration(days: 21));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Installation Date',
    );

    if (pickedDate == null) return;

    setState(() => _isSavingDate = true);

    try {
      await _orderService.setConfirmedInstallDate(
        orderId: _currentOrder.id,
        installDate: pickedDate,
        userId: userId,
        userName: userName,
      );

      setState(() {
        _currentOrder = _currentOrder.copyWith(
          confirmedInstallDate: pickedDate,
          installBookingStatus: models.InstallBookingStatus.confirmed,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Install date set to ${DateFormat('MMM d, yyyy').format(pickedDate)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onOrderUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting install date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDate = false);
      }
    }
  }

  void _showStockDialog() {
    showDialog(
      context: context,
      builder: (context) => _StockViewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfo(),
                    const SizedBox(height: 24),
                    _buildInstallationBookingSection(),
                    const SizedBox(height: 24),
                    _buildInstallerSection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(),
                    if (_currentOrder.notes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildNotesSection(),
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _currentOrder.customerName.isNotEmpty
                  ? _currentOrder.customerName[0].toUpperCase()
                  : 'O',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentOrder.customerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${_currentOrder.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return _buildSection(
      title: 'Customer Information',
      icon: Icons.person,
      children: [
        _buildInfoRow('Email', _currentOrder.email),
        _buildInfoRow('Phone', _currentOrder.phone),
        _buildInfoRow(
          'Order Date',
          _currentOrder.orderDate != null
              ? DateFormat('MMM d, yyyy').format(_currentOrder.orderDate!)
              : 'N/A',
        ),
        _buildInfoRow('Stage', _currentOrder.currentStage.replaceAll('_', ' ').toUpperCase()),
        _buildInfoRow('Time in Stage', _currentOrder.timeInStageDisplay),
      ],
    );
  }

  Widget _buildInstallationBookingSection() {
    final hasSelectedDates = _currentOrder.customerSelectedDates.isNotEmpty;
    final hasConfirmedDate = _currentOrder.confirmedInstallDate != null;

    return _buildSection(
      title: 'Installation Booking',
      icon: Icons.calendar_month,
      children: [
        // Booking status
        Row(
          children: [
            const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500)),
            _buildStatusChip(_currentOrder.installBookingStatus),
          ],
        ),
        const SizedBox(height: 12),

        // Customer selected dates
        if (hasSelectedDates) ...[
          const Text(
            'Customer Preferred Dates:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ..._currentOrder.customerSelectedDates.map(
            (date) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Customer has not selected installation dates yet.',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Confirmed install date
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirmed Install Date:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasConfirmedDate
                        ? DateFormat('EEEE, MMMM d, yyyy')
                            .format(_currentOrder.confirmedInstallDate!)
                        : 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      color: hasConfirmedDate ? Colors.blue[700] : Colors.grey,
                      fontWeight:
                          hasConfirmedDate ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSavingDate ? null : _setInstallDate,
              icon: _isSavingDate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_calendar, size: 18),
              label: Text(hasConfirmedDate ? 'Change' : 'Set Date'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstallerSection() {
    return Consumer<InstallerProvider>(
      builder: (context, installerProvider, child) {
        final installers = installerProvider.activeInstallers;

        return _buildSection(
          title: 'Installer Assignment',
          icon: Icons.engineering,
          children: [
            if (installerProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (installers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('No active installers available.'),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedInstallerId,
                decoration: InputDecoration(
                  labelText: 'Select Installer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...installers.map((installer) {
                    return DropdownMenuItem<String>(
                      value: installer.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(installer.fullName),
                          Text(
                            installer.serviceArea,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: _isSavingInstaller
                    ? null
                    : (value) {
                        if (value != null) {
                          final installer = installers.firstWhere(
                            (i) => i.id == value,
                          );
                          _assignInstaller(installer);
                        }
                      },
              ),
            if (_currentOrder.assignedInstallerName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Assigned to: ${_currentOrder.assignedInstallerName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionsSection() {
    return _buildSection(
      title: 'Actions',
      icon: Icons.touch_app,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Send/Resend booking email
            ElevatedButton.icon(
              onPressed: _isSendingEmail ? null : _sendBookingEmail,
              icon: _isSendingEmail
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.email, size: 18),
              label: Text(
                _currentOrder.installBookingEmailSentAt != null
                    ? 'Resend Booking Email'
                    : 'Send Booking Email',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            // View stock
            OutlinedButton.icon(
              onPressed: _showStockDialog,
              icon: const Icon(Icons.inventory_2, size: 18),
              label: const Text('View Stock'),
            ),
          ],
        ),
        if (_currentOrder.installBookingEmailSentAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Last email sent: ${DateFormat('MMM d, yyyy h:mm a').format(_currentOrder.installBookingEmailSentAt!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildSection(
      title: 'Notes',
      icon: Icons.note,
      children: [
        ..._currentOrder.notes.reversed.take(5).map(
              (note) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${note.createdByName ?? 'Unknown'} • ${DateFormat('MMM d, h:mm a').format(note.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(models.InstallBookingStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case models.InstallBookingStatus.pending:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'Awaiting Customer';
        break;
      case models.InstallBookingStatus.datesSelected:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Dates Selected';
        break;
      case models.InstallBookingStatus.confirmed:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'Confirmed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// Dialog to show available stock
class _StockViewDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Available Stock',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Consumer<InventoryProvider>(
                builder: (context, inventoryProvider, child) {
                  if (inventoryProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final stockItems = inventoryProvider.allStockItems;

                  if (stockItems.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No stock items available.'),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: stockItems.length,
                    itemBuilder: (context, index) {
                      final stock = stockItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: stock.isOutOfStock
                              ? Colors.red.shade50
                              : stock.isLowStock
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stock.isOutOfStock
                                ? Colors.red.shade200
                                : stock.isLowStock
                                    ? Colors.orange.shade200
                                    : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stock.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    stock.warehouseLocation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${stock.currentQty}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: stock.isOutOfStock
                                        ? Colors.red[700]
                                        : stock.isLowStock
                                            ? Colors.orange[700]
                                            : Colors.green[700],
                                  ),
                                ),
                                Text(
                                  stock.stockStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: stock.isOutOfStock
                                        ? Colors.red[700]
                                        : stock.isLowStock
                                            ? Colors.orange[700]
                                            : Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

