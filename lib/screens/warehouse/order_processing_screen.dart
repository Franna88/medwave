import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/inventory/inventory_stock.dart';
import '../../models/streams/order.dart' as models;
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/product_items_provider.dart';
import '../../providers/product_packages_provider.dart';
import '../../services/firebase/order_service.dart';
import '../../theme/app_theme.dart';
import 'shipping_details_screen.dart';

/// One row in the flattened pick list (one card = one product, packages expanded).
class _PickListRow {
  final models.OrderItem orderItem;
  final String displayName;
  final int displayQty;
  final int? stockQty;
  final bool isOutOfStock;
  final bool isLowStock;
  final bool hasInsufficientStock;
  final bool orderLineIsOutOfStock;

  /// Set for package constituent rows; used for composite pick key.
  final String? productId;

  const _PickListRow({
    required this.orderItem,
    required this.displayName,
    required this.displayQty,
    this.stockQty,
    required this.isOutOfStock,
    required this.isLowStock,
    required this.hasInsufficientStock,
    required this.orderLineIsOutOfStock,
    this.productId,
  });

  String get pickKey =>
      productId != null ? '${orderItem.name}|$productId' : orderItem.name;
}

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

    // Initialize picked items map: for non-package items use item.name; package rows use composite keys (added when user picks)
    if (_pickedItems.isEmpty) {
      for (final item in widget.order.items) {
        if (item.packageId == null) _pickedItems[item.name] = false;
      }
    }

    // If order is still in priority_shipment, move to inventory_packing_list
    if (_currentOrder.currentStage == 'priority_shipment') {
      _moveToPackingList();
    }

    // Load inventory and packages for stock validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().listenToInventory();
      context.read<ProductPackagesProvider>().listenToPackages();
      context.read<ProductItemsProvider>().listenToProducts();
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

  Future<void> _toggleItemPicked(String pickKey, bool picked) async {
    // If trying to pick, validate stock. Composite key "orderLineName|productId" = single package row; else order line name.
    final isComposite = pickKey.contains('|');
    final orderLineName = isComposite ? pickKey.split('|').first : pickKey;
    final productIdForRow = isComposite && pickKey.split('|').length > 1
        ? pickKey.substring(orderLineName.length + 1)
        : null;

    if (picked) {
      final inventoryProvider = context.read<InventoryProvider>();
      final orderItem = _currentOrder.items.firstWhere(
        (item) => item.name == orderLineName,
        orElse: () =>
            models.OrderItem(name: orderLineName, quantity: 1, price: 0),
      );

      if (productIdForRow != null && orderItem.packageId != null) {
        // Single package row: validate only this product's stock
        final packageProvider = context.read<ProductPackagesProvider>();
        final pkg = packageProvider.packages
            .where((p) => p.id == orderItem.packageId)
            .toList();
        if (pkg.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot pick: Package not found.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final entry = pkg.first.packageItems
            .where((e) => e.productId == productIdForRow)
            .toList();
        if (entry.isEmpty) return;
        final requiredQty = entry.first.quantity * orderItem.quantity;
        final stockMatch = inventoryProvider.allStockItems
            .where((s) => s.productId == productIdForRow)
            .toList();
        if (stockMatch.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot pick: Product has no inventory record.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
        final stockItem = stockMatch.first;
        if (stockItem.currentQty < requiredQty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot pick: ${stockItem.productName} only ${stockItem.currentQty} in stock, need $requiredQty.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } else if (orderItem.packageId != null) {
        // Legacy: whole package picked at once (should not happen with composite keys)
        final packageProvider = context.read<ProductPackagesProvider>();
        final pkg = packageProvider.packages
            .where((p) => p.id == orderItem.packageId)
            .toList();
        if (pkg.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot pick: Package not found.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final package = pkg.first;
        for (final e in package.packageItems) {
          final requiredQty = e.quantity * orderItem.quantity;
          final stockMatch = inventoryProvider.allStockItems
              .where((s) => s.productId == e.productId)
              .toList();
          if (stockMatch.isEmpty || stockMatch.first.currentQty < requiredQty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot pick: Insufficient stock for package item.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
      } else {
        // Product or legacy: match by productId or name
        final requiredQty = orderItem.quantity;
        InventoryStock? stockItem;
        if (orderItem.productId != null) {
          final byId = inventoryProvider.allStockItems
              .where((s) => s.productId == orderItem.productId)
              .toList();
          stockItem = byId.isEmpty ? null : byId.first;
        }
        final stockByName = inventoryProvider.allStockItems
            .where(
              (s) => s.productName.toLowerCase() == orderLineName.toLowerCase(),
            )
            .toList();
        final hasStock = stockItem != null || stockByName.isNotEmpty;
        final stock =
            stockItem ?? (stockByName.isNotEmpty ? stockByName.first : null);

        if (hasStock && stock != null) {
          if (stock.currentQty < requiredQty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot pick: Only ${stock.currentQty} in stock, but $requiredQty needed. Please contact admin to override.',
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
            return;
          }
          if (stock.isOutOfStock) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cannot pick: Item is out of stock. Please contact admin to override.',
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
            return;
          }
          if (stock.isLowStock && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Warning: "${orderItem.name}" is low stock (${stock.currentQty} remaining)',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (!hasStock && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Warning: "${orderItem.name}" not found in inventory system',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    setState(() {
      _pickedItems[pickKey] = picked;
    });

    try {
      await _orderService.updatePickedItems(
        orderId: _currentOrder.id,
        pickedItems: _pickedItems,
      );
    } catch (e) {
      setState(() {
        _pickedItems[pickKey] = !picked;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  /// Number of order lines where every constituent row is picked (uses flattened rows; supports composite keys and legacy).
  int _computePickedOrderLineCount(List<_PickListRow> rows) {
    if (_currentOrder.items.isEmpty) return 0;
    final orderLineNames = _currentOrder.items.map((i) => i.name).toSet();
    int count = 0;
    for (final name in orderLineNames) {
      final lineRows = rows.where((r) => r.orderItem.name == name).toList();
      if (lineRows.isEmpty) continue;
      final allPicked = lineRows.every((r) {
        final key = r.pickKey;
        final v = _pickedItems[key];
        if (v == true) return true;
        if (r.productId != null && _pickedItems[name] == true) return true;
        return false;
      });
      if (allPicked) count++;
    }
    return count;
  }

  Future<void> _proceedToShipping() async {
    if (_currentOrder.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick all items before proceeding'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final inventoryProvider = context.read<InventoryProvider>();
    final packageProvider = context.read<ProductPackagesProvider>();
    final productProvider = context.read<ProductItemsProvider>();
    final rows = _buildFlattenedRows(
      inventoryProvider,
      packageProvider,
      productProvider,
    );
    final pickedCount = _computePickedOrderLineCount(rows);
    final allItemsPicked = pickedCount == _currentOrder.items.length;
    if (!allItemsPicked) {
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
      body:
          Consumer3<
            InventoryProvider,
            ProductPackagesProvider,
            ProductItemsProvider
          >(
            builder:
                (
                  context,
                  inventoryProvider,
                  packageProvider,
                  productProvider,
                  _,
                ) {
                  final rows = _buildFlattenedRows(
                    inventoryProvider,
                    packageProvider,
                    productProvider,
                  );
                  final pickedCount = _computePickedOrderLineCount(rows);
                  final totalCount = _currentOrder.items.length;
                  final allItemsPicked =
                      totalCount > 0 && pickedCount == totalCount;
                  final progress = totalCount > 0
                      ? pickedCount / totalCount
                      : 0.0;
                  return Column(
                    children: [
                      _buildHeader(),
                      if (_isMovingToPickList)
                        const LinearProgressIndicator()
                      else
                        _buildProgressBar(
                          pickedCount: pickedCount,
                          totalCount: totalCount,
                          progress: progress,
                          allItemsPicked: allItemsPicked,
                        ),
                      Expanded(child: _buildItemsList(rows: rows)),
                      _buildBottomBar(allItemsPicked: allItemsPicked),
                    ],
                  );
                },
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

  Widget _buildProgressBar({
    required int pickedCount,
    required int totalCount,
    required double progress,
    required bool allItemsPicked,
  }) {
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
                '$pickedCount / $totalCount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: allItemsPicked
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
              value: progress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                allItemsPicked ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              minHeight: 10,
            ),
          ),
          if (allItemsPicked) ...[
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

  Widget _buildItemsList({required List<_PickListRow> rows}) {
    if (rows.isEmpty) {
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
      itemCount: rows.length,
      itemBuilder: (context, index) {
        return _buildPickRowCard(rows[index], index);
      },
    );
  }

  List<_PickListRow> _buildFlattenedRows(
    InventoryProvider inventoryProvider,
    ProductPackagesProvider packageProvider,
    ProductItemsProvider productProvider,
  ) {
    final List<_PickListRow> rows = [];
    for (final item in _currentOrder.items) {
      if (item.packageId != null) {
        final pkg = packageProvider.packages
            .where((p) => p.id == item.packageId)
            .toList();
        if (pkg.isEmpty) {
          rows.add(
            _PickListRow(
              orderItem: item,
              displayName: item.name,
              displayQty: item.quantity,
              stockQty: null,
              isOutOfStock: true,
              isLowStock: false,
              hasInsufficientStock: true,
              orderLineIsOutOfStock: true,
            ),
          );
        } else {
          final package = pkg.first;
          bool orderLineIsOutOfStock = false;
          for (final entry in package.packageItems) {
            final stockMatch = inventoryProvider.allStockItems
                .where((s) => s.productId == entry.productId)
                .toList();
            final hasStock = stockMatch.isNotEmpty;
            final currentQty = hasStock ? stockMatch.first.currentQty : 0;
            final requiredQty = entry.quantity * item.quantity;
            if (!hasStock || currentQty < requiredQty) {
              orderLineIsOutOfStock = true;
            }
          }
          for (final entry in package.packageItems) {
            final product = productProvider.items
                .where((p) => p.id == entry.productId)
                .toList();
            final name = product.isEmpty
                ? 'Product ${entry.productId}'
                : product.first.name;
            final requiredQty = entry.quantity * item.quantity;
            final stockMatch = inventoryProvider.allStockItems
                .where((s) => s.productId == entry.productId)
                .toList();
            final hasStock = stockMatch.isNotEmpty;
            final currentQty = hasStock ? stockMatch.first.currentQty : 0;
            final itemOutOfStock = !hasStock || currentQty < requiredQty;
            final itemLowStock =
                hasStock &&
                stockMatch.first.isLowStock &&
                currentQty >= requiredQty;
            rows.add(
              _PickListRow(
                orderItem: item,
                displayName: name,
                displayQty: requiredQty,
                stockQty: hasStock ? currentQty : null,
                isOutOfStock: itemOutOfStock,
                isLowStock: itemLowStock,
                hasInsufficientStock: currentQty < requiredQty,
                orderLineIsOutOfStock: orderLineIsOutOfStock,
                productId: entry.productId,
              ),
            );
          }
        }
      } else {
        final byId = item.productId != null
            ? inventoryProvider.allStockItems
                  .where((s) => s.productId == item.productId)
                  .toList()
            : <InventoryStock>[];
        final byName = inventoryProvider.allStockItems
            .where(
              (s) => s.productName.toLowerCase() == item.name.toLowerCase(),
            )
            .toList();
        final hasStock = byId.isNotEmpty || byName.isNotEmpty;
        final stock = (byId.isNotEmpty
            ? byId.first
            : (byName.isNotEmpty ? byName.first : null));
        int? stockQty;
        bool isOutOfStock = false;
        bool isLowStock = false;
        bool hasInsufficientStock = false;
        if (hasStock && stock != null) {
          stockQty = stock.currentQty;
          hasInsufficientStock = stockQty < item.quantity;
          isOutOfStock = stock.isOutOfStock || hasInsufficientStock;
          isLowStock = stock.isLowStock;
        }
        rows.add(
          _PickListRow(
            orderItem: item,
            displayName: item.name,
            displayQty: item.quantity,
            stockQty: stockQty,
            isOutOfStock: isOutOfStock,
            isLowStock: isLowStock,
            hasInsufficientStock: hasInsufficientStock,
            orderLineIsOutOfStock: isOutOfStock,
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildPickRowCard(_PickListRow row, int displayIndex) {
    final isPicked =
        _pickedItems[row.pickKey] ??
        (row.productId != null && _pickedItems[row.orderItem.name] == true);
    final canPick = !row.orderLineIsOutOfStock || isPicked;
    final isOut = row.isOutOfStock || row.hasInsufficientStock;

    String badgeText;
    if (isOut) {
      badgeText = row.stockQty != null
          ? 'Low (${row.stockQty}) - Need ${row.displayQty}'
          : 'Out of Stock';
    } else if (row.isLowStock) {
      badgeText = 'Low (${row.stockQty})';
    } else {
      badgeText = 'In Stock (${row.stockQty})';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPicked
            ? Colors.white
            : row.orderLineIsOutOfStock
            ? Colors.red.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPicked
              ? AppTheme.successColor.withOpacity(0.5)
              : row.orderLineIsOutOfStock
              ? Colors.red.shade300
              : AppTheme.borderColor,
          width: isPicked || row.orderLineIsOutOfStock ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPicked
                ? AppTheme.successColor.withOpacity(0.1)
                : row.orderLineIsOutOfStock
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
              ? () => _toggleItemPicked(row.pickKey, !isPicked)
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
                          : row.orderLineIsOutOfStock
                          ? Colors.red.shade100
                          : AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${displayIndex + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPicked
                              ? AppTheme.successColor
                              : row.orderLineIsOutOfStock
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
                                row.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isPicked
                                      ? AppTheme.secondaryColor.withOpacity(0.6)
                                      : row.orderLineIsOutOfStock
                                      ? Colors.red[800]
                                      : AppTheme.textColor,
                                  decoration: isPicked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (!isPicked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? Colors.red.shade100
                                      : row.isLowStock
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOut
                                        ? Colors.red.shade300
                                        : row.isLowStock
                                        ? Colors.orange.shade300
                                        : Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOut
                                        ? Colors.red[700]
                                        : row.isLowStock
                                        ? Colors.orange[700]
                                        : Colors.green[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${row.displayQty}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryColor.withOpacity(0.6),
                          ),
                        ),
                        if (row.orderLineIsOutOfStock && !isPicked) ...[
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
                          : row.orderLineIsOutOfStock
                          ? Colors.red.shade200
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPicked
                            ? AppTheme.successColor
                            : row.orderLineIsOutOfStock
                            ? Colors.red.shade400
                            : AppTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    child: isPicked
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : row.orderLineIsOutOfStock
                        ? Icon(Icons.block, color: Colors.red[700], size: 18)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar({required bool allItemsPicked}) {
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
            onPressed: _isLoading || !allItemsPicked
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
              allItemsPicked ? 'Proceed to Shipping' : 'Pick All Items First',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: allItemsPicked
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
