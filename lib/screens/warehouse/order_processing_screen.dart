import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/streams/order.dart' as models;
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/firebase/order_service.dart';
import '../../theme/app_theme.dart';
import 'shipping_details_screen.dart';

/// Screen for processing an order - shows item checklist for picking
class OrderProcessingScreen extends StatefulWidget {
  final models.Order order;

  const OrderProcessingScreen({super.key, required this.order});

  @override
  State<OrderProcessingScreen> createState() => _OrderProcessingScreenState();
}

class _OrderProcessingScreenState extends State<OrderProcessingScreen> {
  final OrderService _orderService = OrderService();

  late models.Order _currentOrder;
  late Map<String, bool> _pickedItems;
  bool _isLoading = false;
  bool _isMovingToPickList = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _pickedItems = Map<String, bool>.from(widget.order.pickedItems);

    // Initialize picked items map with all items set to false if empty
    if (_pickedItems.isEmpty) {
      for (final item in widget.order.items) {
        _pickedItems[item.name] = false;
      }
    }

    // If order is still in priority_shipment, move to inventory_packing_list
    if (_currentOrder.currentStage == 'priority_shipment') {
      _moveToPackingList();
    }

    // Load inventory for stock validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().listenToInventory();
    });
  }

  Future<void> _moveToPackingList() async {
    setState(() => _isMovingToPickList = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? '';
      final userName = authProvider.user?.displayName ?? 'Warehouse User';

      await _orderService.moveOrderToStage(
        orderId: _currentOrder.id,
        newStage: 'inventory_packing_list',
        note: 'Started picking items',
        userId: userId,
        userName: userName,
      );

      // Update local state
      setState(() {
        _currentOrder = _currentOrder.copyWith(
          currentStage: 'inventory_packing_list',
        );
        _isMovingToPickList = false;
      });
    } catch (e) {
      setState(() => _isMovingToPickList = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleItemPicked(String itemName, bool picked) async {
    // If trying to pick an item, validate stock availability
    if (picked) {
      final inventoryProvider = context.read<InventoryProvider>();

      // Check if item exists in inventory
      final hasStock = inventoryProvider.allStockItems.any(
        (s) => s.productName.toLowerCase() == itemName.toLowerCase(),
      );

      if (hasStock) {
        final stockItem = inventoryProvider.allStockItems.firstWhere(
          (s) => s.productName.toLowerCase() == itemName.toLowerCase(),
        );

        // Block picking if item is out of stock
        if (stockItem.isOutOfStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot pick "$itemName": Item is out of stock. Please contact admin to override.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
          return; // Don't proceed with picking
        }

        // Warn if item is low stock
        if (stockItem.isLowStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Warning: "$itemName" is low stock (${stockItem.currentQty} remaining)',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Item not found in inventory - allow picking but warn
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Warning: "$itemName" not found in inventory system',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    setState(() {
      _pickedItems[itemName] = picked;
    });

    // Save to Firestore
    try {
      await _orderService.updatePickedItems(
        orderId: _currentOrder.id,
        pickedItems: _pickedItems,
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _pickedItems[itemName] = !picked;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  bool get _allItemsPicked {
    for (final item in _currentOrder.items) {
      if (_pickedItems[item.name] != true) return false;
    }
    return true;
  }

  int get _pickedCount => _pickedItems.values.where((v) => v).length;

  double get _pickingProgress {
    if (_currentOrder.items.isEmpty) return 0.0;
    return _pickedCount / _currentOrder.items.length;
  }

  Future<void> _proceedToShipping() async {
    if (!_allItemsPicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick all items before proceeding'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? '';
      final userName = authProvider.user?.displayName ?? 'Warehouse User';

      // Move to items_picked stage
      await _orderService.moveOrderToStage(
        orderId: _currentOrder.id,
        newStage: 'items_picked',
        note: 'All items picked',
        userId: userId,
        userName: userName,
      );

      // Update picked timestamp
      await _orderService.setPickedDetails(
        orderId: _currentOrder.id,
        pickedBy: userId,
        pickedByName: userName,
      );

      if (mounted) {
        // Navigate to shipping details screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ShippingDetailsScreen(
              order: _currentOrder.copyWith(
                currentStage: 'items_picked',
                pickedItems: _pickedItems,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          if (_isMovingToPickList)
            const LinearProgressIndicator()
          else
            _buildProgressBar(),
          Expanded(child: _buildItemsList()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.headerGradientStart, AppTheme.headerGradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pick List',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentOrder.customerName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentOrder.confirmedInstallDate != null
                            ? dateFormat.format(
                                _currentOrder.confirmedInstallDate!,
                              )
                            : 'No date',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Picked',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryColor.withOpacity(0.7),
                ),
              ),
              Text(
                '$_pickedCount / ${_currentOrder.items.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _allItemsPicked
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _pickingProgress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                _allItemsPicked ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              minHeight: 10,
            ),
          ),
          if (_allItemsPicked) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'All items picked!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_currentOrder.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.secondaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No items in this order',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.secondaryColor.withOpacity(0.7),
              ),
            ),
            if (_currentOrder.splitFromOrderId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All items were moved to a split order due to out of stock override.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order has no items to pick.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentOrder.items.length,
      itemBuilder: (context, index) {
        final item = _currentOrder.items[index];
        final isPicked = _pickedItems[item.name] ?? false;
        return _buildItemCard(item, isPicked, index);
      },
    );
  }

  Widget _buildItemCard(models.OrderItem item, bool isPicked, int index) {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        // Check stock status for this item
        final hasStock = inventoryProvider.allStockItems.any(
          (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
        );

        bool isOutOfStock = false;
        bool isLowStock = false;
        int? stockQty;

        if (hasStock) {
          final stockItem = inventoryProvider.allStockItems.firstWhere(
            (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
          );
          isOutOfStock = stockItem.isOutOfStock;
          isLowStock = stockItem.isLowStock;
          stockQty = stockItem.currentQty;
        }

        // Block picking if out of stock (unless already picked)
        final canPick = !isOutOfStock || isPicked;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isPicked
                ? Colors.white
                : isOutOfStock
                ? Colors.red.shade50
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPicked
                  ? AppTheme.successColor.withOpacity(0.5)
                  : isOutOfStock
                  ? Colors.red.shade300
                  : AppTheme.borderColor,
              width: isPicked
                  ? 2
                  : isOutOfStock
                  ? 2
                  : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPicked
                    ? AppTheme.successColor.withOpacity(0.1)
                    : isOutOfStock
                    ? Colors.red.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canPick
                  ? () => _toggleItemPicked(item.name, !isPicked)
                  : null,
              child: Opacity(
                opacity: canPick ? 1.0 : 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isPicked
                              ? AppTheme.successColor.withOpacity(0.1)
                              : isOutOfStock
                              ? Colors.red.shade100
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPicked
                                  ? AppTheme.successColor
                                  : isOutOfStock
                                  ? Colors.red[700]
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isPicked
                                          ? AppTheme.secondaryColor.withOpacity(
                                              0.6,
                                            )
                                          : isOutOfStock
                                          ? Colors.red[800]
                                          : AppTheme.textColor,
                                      decoration: isPicked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                // Stock status badge
                                if (hasStock && !isPicked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? Colors.red.shade100
                                          : isLowStock
                                          ? Colors.orange.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isOutOfStock
                                            ? Colors.red.shade300
                                            : isLowStock
                                            ? Colors.orange.shade300
                                            : Colors.green.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      isOutOfStock
                                          ? 'Out of Stock'
                                          : isLowStock
                                          ? 'Low ($stockQty)'
                                          : 'In Stock ($stockQty)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isOutOfStock
                                            ? Colors.red[700]
                                            : isLowStock
                                            ? Colors.orange[700]
                                            : Colors.green[700],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryColor.withOpacity(0.6),
                              ),
                            ),
                            // Warning message for out of stock
                            if (isOutOfStock && !isPicked) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 14,
                                    color: Colors.red[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Cannot pick - Out of stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isPicked
                              ? AppTheme.successColor
                              : isOutOfStock
                              ? Colors.red.shade200
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPicked
                                ? AppTheme.successColor
                                : isOutOfStock
                                ? Colors.red.shade400
                                : AppTheme.borderColor,
                            width: 2,
                          ),
                        ),
                        child: isPicked
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : isOutOfStock
                            ? Icon(
                                Icons.block,
                                color: Colors.red[700],
                                size: 18,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading || !_allItemsPicked
                ? null
                : _proceedToShipping,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.local_shipping),
            label: Text(
              _allItemsPicked ? 'Proceed to Shipping' : 'Pick All Items First',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _allItemsPicked
                  ? AppTheme.successColor
                  : AppTheme.secondaryColor.withOpacity(0.3),
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
          ),
        ),
      ),
    );
  }
}
