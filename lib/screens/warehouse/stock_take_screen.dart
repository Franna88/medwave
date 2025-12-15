import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/inventory/inventory_stock.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';

class StockTakeScreen extends StatefulWidget {
  final InventoryStock stock;

  const StockTakeScreen({super.key, required this.stock});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  late TextEditingController _qtyController;
  late TextEditingController _locationController;
  late TextEditingController _shelfController;
  late TextEditingController _minLevelController;
  late TextEditingController _notesController;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.stock.currentQty.toString());
    _locationController = TextEditingController(text: widget.stock.warehouseLocation);
    _shelfController = TextEditingController(text: widget.stock.shelfLocation);
    _minLevelController = TextEditingController(text: widget.stock.minStockLevel.toString());
    _notesController = TextEditingController();

    _qtyController.addListener(_onChanged);
    _locationController.addListener(_onChanged);
    _shelfController.addListener(_onChanged);
    _minLevelController.addListener(_onChanged);
  }

  void _onChanged() {
    final currentQty = int.tryParse(_qtyController.text) ?? widget.stock.currentQty;
    final currentMinLevel = int.tryParse(_minLevelController.text) ?? widget.stock.minStockLevel;

    setState(() {
      _hasChanges = currentQty != widget.stock.currentQty ||
          _locationController.text != widget.stock.warehouseLocation ||
          _shelfController.text != widget.stock.shelfLocation ||
          currentMinLevel != widget.stock.minStockLevel;
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _locationController.dispose();
    _shelfController.dispose();
    _minLevelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Stock Take'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductInfo(),
            const SizedBox(height: 24),
            _buildCurrentStatus(),
            const SizedBox(height: 24),
            _buildStockTakeForm(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stock.productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Product ID: ${widget.stock.productId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Current Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Current Qty',
                  widget.stock.currentQty.toString(),
                  Icons.inventory_2_outlined,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Min Level',
                  widget.stock.minStockLevel.toString(),
                  Icons.warning_amber_outlined,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Status',
                  widget.stock.stockStatus,
                  _getStatusIcon(widget.stock),
                  color: _getStatusColor(widget.stock),
                ),
              ),
            ],
          ),
          if (widget.stock.lastStockTakeDate != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.update,
                  size: 14,
                  color: AppTheme.secondaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Last stock take: ${_formatDateTime(widget.stock.lastStockTakeDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, {Color? color}) {
    color ??= AppTheme.secondaryColor;
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.secondaryColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(InventoryStock stock) {
    if (stock.isOutOfStock) return Icons.error_outline;
    if (stock.isLowStock) return Icons.warning_amber_outlined;
    return Icons.check_circle_outline;
  }

  Color _getStatusColor(InventoryStock stock) {
    if (stock.isOutOfStock) return AppTheme.errorColor;
    if (stock.isLowStock) return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  Widget _buildStockTakeForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
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
          Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Update Stock Quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min Stock Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minLevelController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickAdjustButtons(),
        ],
      ),
    );
  }

  Widget _buildQuickAdjustButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildQuickButton(-10, '-10'),
        const SizedBox(width: 8),
        _buildQuickButton(-1, '-1'),
        const SizedBox(width: 16),
        _buildQuickButton(1, '+1'),
        const SizedBox(width: 8),
        _buildQuickButton(10, '+10'),
      ],
    );
  }

  Widget _buildQuickButton(int delta, String label) {
    return OutlinedButton(
      onPressed: () {
        final current = int.tryParse(_qtyController.text) ?? 0;
        final newValue = (current + delta).clamp(0, 999999);
        _qtyController.text = newValue.toString();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: AppTheme.primaryColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Warehouse Location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.warehouse_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shelfController,
            decoration: InputDecoration(
              labelText: 'Shelf / Bin Location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.shelves),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add notes about this stock take...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _hasChanges && !_isLoading ? _saveStockTake : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save),
                      SizedBox(width: 8),
                      Text(
                        'Save Stock Take',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveStockTake() async {
    final newQty = int.tryParse(_qtyController.text);
    final newMinLevel = int.tryParse(_minLevelController.text);

    if (newQty == null || newMinLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numbers'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<InventoryProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? 'unknown';

      // Update quantity if changed
      if (newQty != widget.stock.currentQty) {
        await provider.updateStockQuantity(
          stockId: widget.stock.id,
          newQty: newQty,
          updatedBy: userId,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
      }

      // Update location and min level if changed
      if (_locationController.text != widget.stock.warehouseLocation ||
          _shelfController.text != widget.stock.shelfLocation ||
          newMinLevel != widget.stock.minStockLevel) {
        final updatedStock = widget.stock.copyWith(
          warehouseLocation: _locationController.text,
          shelfLocation: _shelfController.text,
          minStockLevel: newMinLevel,
        );
        await provider.updateInventoryStock(updatedStock);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

