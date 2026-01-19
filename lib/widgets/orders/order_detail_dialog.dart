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
  bool _isDeleting = false;
  bool _isSplitting = false;
  String? _selectedInstallerId;
  Set<String> _selectedItemsForOverride = {}; // Items selected for override

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
        installerPhone: installer.phoneNumber,
        installerEmail: installer.email,
      );

      setState(() {
        _selectedInstallerId = installer.id;
        _currentOrder = _currentOrder.copyWith(
          assignedInstallerId: installer.id,
          assignedInstallerName: installer.fullName,
          assignedInstallerPhone: installer.phoneNumber,
          assignedInstallerEmail: installer.email,
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
    final initialDate =
        _currentOrder.earliestSelectedDate ??
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
    showDialog(context: context, builder: (context) => _StockViewDialog());
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Lead'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('This Order'),
            _buildDeleteItem('Sales Appointment'),
            _buildDeleteItem('All related Contracts'),
            _buildDeleteItem('Support Ticket (if exists)'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Lead'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteLead();
    }
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.remove_circle, size: 16, color: Colors.red[400]),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _deleteLead() async {
    setState(() => _isDeleting = true);

    try {
      await _orderService.deleteLeadCompletely(orderId: _currentOrder.id);

      if (mounted) {
        // Close the dialog first
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lead "${_currentOrder.customerName}" and all related data deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent to refresh
        widget.onOrderUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting lead: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _handleOverrideItems() async {
    if (_selectedItemsForOverride.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select items to override'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Override Out of Stock Items'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will create a new order (Order 2) with the selected items and remove them from this order (Order 1).',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Items to override:'),
            const SizedBox(height: 8),
            ..._selectedItemsForOverride.map(
              (itemName) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle,
                      size: 16,
                      color: Colors.orange[400],
                    ),
                    const SizedBox(width: 8),
                    Text(itemName),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The new order will appear in the same stage with a reference to this order.',
                      style: TextStyle(fontSize: 12),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Override Items'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSplitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? '';
      final userName = authProvider.userName;

      final newOrderId = await _orderService.splitOrderForOverriddenItems(
        orderId: _currentOrder.id,
        overriddenItemNames: _selectedItemsForOverride.toList(),
        userId: userId,
        userName: userName,
      );

      // Refresh the order
      final updatedOrder = await _orderService.getOrder(_currentOrder.id);
      if (updatedOrder != null) {
        setState(() {
          _currentOrder = updatedOrder;
          _selectedItemsForOverride.clear();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order split successfully! New order #${newOrderId.substring(0, 8)} created.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Notify parent to refresh
        widget.onOrderUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error splitting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSplitting = false);
      }
    }
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
                    // Show delivery info section when order has tracking/waybill
                    if (_currentOrder.trackingNumber != null ||
                        _currentOrder.waybillPhotoUrl != null) ...[
                      _buildDeliveryInfoSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildOrderItemsSection(),
                    const SizedBox(height: 24),
                    // Show business information if questionnaire data exists
                    if (_currentOrder.optInQuestions != null &&
                        _currentOrder.optInQuestions!.isNotEmpty) ...[
                      _buildBusinessInformationSection(),
                      const SizedBox(height: 24),
                    ],
                    // Show installation proof and signature if they exist
                    if (_currentOrder.proofOfInstallationPhotoUrls.isNotEmpty ||
                        _currentOrder.customerSignaturePhotoUrl != null) ...[
                      if (_currentOrder
                          .proofOfInstallationPhotoUrls
                          .isNotEmpty) ...[
                        _buildInstallationProofSection(),
                        const SizedBox(height: 24),
                      ],
                      if (_currentOrder.customerSignaturePhotoUrl != null) ...[
                        _buildCustomerSignatureSection(),
                        const SizedBox(height: 24),
                      ],
                    ],
                    _buildInstallationBookingSection(),
                    const SizedBox(height: 24),
                    _buildInstallerSection(),
                    const SizedBox(height: 24),
                    // Show shipped items from parent order if this is a split order
                    if (_currentOrder
                        .shippedItemsFromParentOrder
                        .isNotEmpty) ...[
                      _buildShippedItemsFromParentSection(),
                      const SizedBox(height: 24),
                    ],
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
      child: Column(
        children: [
          Row(
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
                      _formatOrderNumber(_currentOrder),
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
          // Split order badge
          if (_currentOrder.splitFromOrderId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_split, size: 16, color: Colors.orange[800]),
                  const SizedBox(width: 6),
                  Text(
                    'Split Order - Part of Order #${_currentOrder.splitFromOrderId!.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatOrderNumber(models.Order order) {
    if (order.splitFromOrderId != null) {
      // Show Order 2's ID with reference to Order 1
      return 'Order #${order.id.substring(0, 8)} (Part 2 of Order #${order.splitFromOrderId!.substring(0, 8)})';
    }
    return 'Order #${order.id.substring(0, 8)}';
  }

  String _formatInvoiceNumber(models.Order order) {
    if (order.splitFromOrderId != null && order.invoiceNumber != null) {
      // Order 2: Same invoice number as Order 1, but with notation showing it's part of Order 1
      return '${order.invoiceNumber} (Part 2 of Order #${order.splitFromOrderId!.substring(0, 8)})';
    }
    return order.invoiceNumber ?? 'N/A';
  }

  Widget _buildCustomerInfo() {
    return _buildSection(
      title: 'Customer Information',
      icon: Icons.person,
      children: [
        _buildInfoRow('Email', _currentOrder.email),
        _buildInfoRow('Phone', _currentOrder.phone),
        if (_currentOrder.optInQuestions?['Shipping address'] != null &&
            _currentOrder.optInQuestions!['Shipping address']!.isNotEmpty)
          _buildInfoRow(
            'Shipping Address',
            _currentOrder.optInQuestions!['Shipping address']!,
          ),
        _buildInfoRow(
          'Order Date',
          _currentOrder.orderDate != null
              ? DateFormat('MMM d, yyyy').format(_currentOrder.orderDate!)
              : 'N/A',
        ),
        _buildInfoRow(
          'Stage',
          _currentOrder.currentStage.replaceAll('_', ' ').toUpperCase(),
        ),
        _buildInfoRow('Time in Stage', _currentOrder.timeInStageDisplay),
        if (_currentOrder.invoiceNumber != null)
          _buildInfoRow('Invoice', _formatInvoiceNumber(_currentOrder)),
      ],
    );
  }

  Widget _buildDeliveryInfoSection() {
    final hasTracking =
        _currentOrder.trackingNumber != null &&
        _currentOrder.trackingNumber!.isNotEmpty;
    final hasWaybill =
        _currentOrder.waybillPhotoUrl != null &&
        _currentOrder.waybillPhotoUrl!.isNotEmpty;

    return _buildSection(
      title: 'Delivery Information',
      icon: Icons.local_shipping,
      children: [
        // Tracking Number
        if (hasTracking) ...[
          const Text(
            'Tracking Number:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentOrder.trackingNumber!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.blue[700], size: 20),
                  tooltip: 'Copy tracking number',
                  onPressed: () {
                    // Copy to clipboard functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tracking number copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600]),
                const SizedBox(width: 12),
                const Text('Tracking number not available'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Waybill Photo
        const Text(
          'Parcel Photo:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (hasWaybill) ...[
          GestureDetector(
            onTap: () => _showFullImage(_currentOrder.waybillPhotoUrl!),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _currentOrder.waybillPhotoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Tap to enlarge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parcel photo not available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load image',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 40,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallationProofSection() {
    final proofUrls = _currentOrder.proofOfInstallationPhotoUrls
        .where((url) => url.isNotEmpty)
        .toList();
    final hasProof = proofUrls.isNotEmpty;

    return _buildSection(
      title: 'Proof of Installation',
      icon: Icons.photo_camera,
      children: [
        Text(
          'Installation Photo${proofUrls.length > 1 ? 's' : ''}:',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (hasProof) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: proofUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final url = entry.value;
                return Container(
                  margin: EdgeInsets.only(
                    right: index < proofUrls.length - 1 ? 12 : 0,
                  ),
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showFullImage(url),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.zoom_in,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tap to enlarge',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (proofUrls.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Image ${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ] else ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installation proof not available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerSignatureSection() {
    final hasSignature =
        _currentOrder.customerSignaturePhotoUrl != null &&
        _currentOrder.customerSignaturePhotoUrl!.isNotEmpty;

    return _buildSection(
      title: 'Customer Signature',
      icon: Icons.draw,
      children: [
        const Text(
          'Signature Photo:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (hasSignature) ...[
          GestureDetector(
            onTap: () =>
                _showFullImage(_currentOrder.customerSignaturePhotoUrl!),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _currentOrder.customerSignaturePhotoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Tap to enlarge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customer signature not available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderItemsSection() {
    final items = _currentOrder.items;
    final pickedItems = _currentOrder.pickedItems;
    final pickedCount = pickedItems.values.where((v) => v).length;
    final totalCount = items.length;
    final progress = totalCount > 0 ? pickedCount / totalCount : 0.0;
    final allPicked = pickedCount == totalCount && totalCount > 0;

    return _buildSection(
      title: 'Order Items',
      icon: Icons.inventory_2,
      children: [
        // Show empty state if no items
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600]),
                const SizedBox(width: 12),
                const Text('No items in this order.'),
              ],
            ),
          )
        else ...[
          // Picking progress bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allPicked ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: allPicked ? Colors.green.shade200 : Colors.blue.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Picking Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: allPicked ? Colors.green[800] : Colors.blue[800],
                      ),
                    ),
                    Row(
                      children: [
                        if (allPicked)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[700],
                          ),
                        const SizedBox(width: 4),
                        Text(
                          '$pickedCount / $totalCount items',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: allPicked
                                ? Colors.green[800]
                                : Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allPicked ? Colors.green : AppTheme.primaryColor,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Override button (only show if order is in inventory_packing_list stage AND there are out-of-stock items selected)
          Consumer<InventoryProvider>(
            builder: (context, inventoryProvider, child) {
              // Show override functionality in inventory_packing_list OR items_picked stage
              // Allow override in items_picked stage for items that weren't picked yet
              final isInValidStage =
                  _currentOrder.currentStage == 'inventory_packing_list' ||
                  _currentOrder.currentStage == 'items_picked';

              if (!isInValidStage) {
                return const SizedBox.shrink();
              }

              // Check if there are any out-of-stock items (that haven't been picked)
              // Allow override for out-of-stock items even if other items have been picked
              final hasOutOfStockItems = items.any((item) {
                final hasStock = inventoryProvider.allStockItems.any(
                  (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
                );
                if (!hasStock) return false;
                final stockItem = inventoryProvider.allStockItems.firstWhere(
                  (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
                );
                final itemPicked = pickedItems[item.name] ?? false;
                // Item must be out of stock AND not already picked to be eligible for override
                return stockItem.isOutOfStock && !itemPicked;
              });

              if (hasOutOfStockItems && _selectedItemsForOverride.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: _isSplitting ? null : _handleOverrideItems,
                    icon: _isSplitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.assignment_return, size: 18),
                    label: Text(
                      _isSplitting
                          ? 'Splitting Order...'
                          : 'Override Selected Items (${_selectedItemsForOverride.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Item list
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isPicked = pickedItems[item.name] ?? false;

            return Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                // Find stock for this item
                final stockItem = inventoryProvider.allStockItems.firstWhere(
                  (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
                  orElse: () => inventoryProvider.allStockItems.isNotEmpty
                      ? inventoryProvider.allStockItems.first
                      : throw Exception('No stock'),
                );

                final hasStock = inventoryProvider.allStockItems.any(
                  (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
                );

                final isOutOfStock = hasStock && stockItem.isOutOfStock;
                // Allow override in inventory_packing_list OR items_picked stage
                // (for items that haven't been picked yet)
                final isInValidStage =
                    _currentOrder.currentStage == 'inventory_packing_list' ||
                    _currentOrder.currentStage == 'items_picked';
                final canOverride = isOutOfStock && !isPicked && isInValidStage;
                final isSelectedForOverride = _selectedItemsForOverride
                    .contains(item.name);

                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < items.length - 1 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPicked
                        ? Colors.green.shade50
                        : isSelectedForOverride
                        ? Colors.orange.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPicked
                          ? Colors.green.shade300
                          : isSelectedForOverride
                          ? Colors.orange.shade300
                          : Colors.grey.shade300,
                      width: isPicked || isSelectedForOverride ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox for override (only for out-of-stock, not picked items)
                      if (canOverride)
                        Checkbox(
                          value: isSelectedForOverride,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedItemsForOverride.add(item.name);
                              } else {
                                _selectedItemsForOverride.remove(item.name);
                              }
                            });
                          },
                          activeColor: Colors.orange,
                        )
                      else
                        const SizedBox(width: 40),
                      // Index number
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isPicked
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPicked
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isPicked
                                    ? Colors.grey[600]
                                    : Colors.black87,
                                decoration: isPicked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stock status badge
                      if (hasStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stockItem.isOutOfStock
                                ? Colors.red.shade100
                                : stockItem.isLowStock
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            stockItem.isOutOfStock
                                ? 'Out of Stock'
                                : stockItem.isLowStock
                                ? 'Low (${stockItem.currentQty})'
                                : 'In Stock (${stockItem.currentQty})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: stockItem.isOutOfStock
                                  ? Colors.red[700]
                                  : stockItem.isLowStock
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No stock info',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                      const SizedBox(width: 8),

                      // Picked status indicator (view only)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isPicked ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPicked
                                ? Colors.green
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isPicked
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
        // Show remaining items from parent order if this is a split order
        if (_currentOrder.splitFromOrderId != null &&
            _currentOrder.remainingItemsFromParentOrder.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Other Items from Original Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These items remained in Order #${_currentOrder.splitFromOrderId!.substring(0, 8)} and were not overridden:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ..._currentOrder.remainingItemsFromParentOrder
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: EdgeInsets.only(
                          bottom:
                              index <
                                  _currentOrder
                                          .remainingItemsFromParentOrder
                                          .length -
                                      1
                              ? 6
                              : 0,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: ${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 12,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'In Order 1',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBusinessInformationSection() {
    return _buildSection(
      title: 'Business Information',
      icon: Icons.business_center,
      children: [
        ..._currentOrder.optInQuestions!.entries.map((entry) {
          return _buildInfoRow(entry.key, entry.value);
        }).toList(),
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
            const Text(
              'Status: ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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
                        ? DateFormat(
                            'EEEE, MMMM d, yyyy',
                          ).format(_currentOrder.confirmedInstallDate!)
                        : 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      color: hasConfirmedDate ? Colors.blue[700] : Colors.grey,
                      fontWeight: hasConfirmedDate
                          ? FontWeight.w600
                          : FontWeight.normal,
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        ..._currentOrder.notes.reversed
            .take(5)
            .map(
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
                    Text(note.text, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${note.createdByName ?? 'Unknown'} • ${DateFormat('MMM d, h:mm a').format(note.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
        children: [
          // Delete Lead button (left side)
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _showDeleteConfirmation,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.delete_forever, size: 18),
            label: Text(_isDeleting ? 'Deleting...' : 'Delete Lead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const Spacer(),
          // Close button (right side)
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippedItemsFromParentSection() {
    final shippedItems = _currentOrder.shippedItemsFromParentOrder;

    return _buildSection(
      title: 'Items Shipped in Parent Order (Order 1)',
      icon: Icons.local_shipping,
      children: [
        const Text(
          'The following items were already shipped in the parent order:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ...shippedItems.map((shippedItem) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shippedItem.itemName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    Text(
                      'Qty: ${shippedItem.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ],
                ),
                if (shippedItem.waybillNumber != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.blue.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, size: 18, color: Colors.blue[800]),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waybill Number',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shippedItem.waybillNumber!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (shippedItem.trackingNumber != null &&
                    shippedItem.trackingNumber !=
                        shippedItem.waybillNumber) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 14,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tracking: ${shippedItem.trackingNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ],
                if (shippedItem.waybillPhotoUrl != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showFullImage(shippedItem.waybillPhotoUrl!),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              shippedItem.waybillPhotoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 32),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Tap to view',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
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
