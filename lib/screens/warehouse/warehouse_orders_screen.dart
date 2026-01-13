import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/streams/order.dart' as models;
import '../../services/firebase/order_service.dart';
import '../../theme/app_theme.dart';
import 'order_processing_screen.dart';
import 'shipping_details_screen.dart';

/// Screen displaying warehouse orders with tab-based filtering
/// Tabs: To Pick, Needs Waybill, Out for Delivery
class WarehouseOrdersScreen extends StatefulWidget {
  const WarehouseOrdersScreen({super.key});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  List<models.Order> _allOrders = [];
  List<models.Order> _toPickOrders = [];
  List<models.Order> _needsWaybillOrders = [];
  List<models.Order> _outForDeliveryOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    _orderService.ordersStream().listen((orders) {
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _categorizeOrders();
          _isLoading = false;
        });
      }
    });
  }

  void _categorizeOrders() {
    // Filter by search query first
    var filteredOrders = _allOrders;
    if (_searchQuery.isNotEmpty) {
      filteredOrders = _allOrders.where((order) {
        return order.customerName.toLowerCase().contains(_searchQuery) ||
            order.email.toLowerCase().contains(_searchQuery) ||
            order.phone.contains(_searchQuery);
      }).toList();
    }

    // To Pick: priority_shipment or inventory_packing_list
    _toPickOrders = filteredOrders.where((order) {
      return order.currentStage == 'priority_shipment' ||
          order.currentStage == 'inventory_packing_list';
    }).toList();

    // Sort by install date (nearest first)
    _toPickOrders.sort((a, b) {
      final dateA = a.confirmedInstallDate ?? a.earliestSelectedDate;
      final dateB = b.confirmedInstallDate ?? b.earliestSelectedDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    // Needs Waybill: items_picked stage
    _needsWaybillOrders = filteredOrders.where((order) {
      return order.currentStage == 'items_picked';
    }).toList();

    // Sort by picked date (most recent first)
    _needsWaybillOrders.sort((a, b) {
      final dateA = a.pickedAt;
      final dateB = b.pickedAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    // Out for Delivery: out_for_delivery stage
    _outForDeliveryOrders = filteredOrders.where((order) {
      return order.currentStage == 'out_for_delivery';
    }).toList();

    // Sort by most recent first
    _outForDeliveryOrders.sort((a, b) {
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _categorizeOrders();
    });
  }

  void _navigateToProcessing(models.Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderProcessingScreen(order: order),
      ),
    );
  }

  void _navigateToShipping(models.Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShippingDetailsScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdersList(_toPickOrders, OrderTabType.toPick),
                      _buildOrdersList(
                        _needsWaybillOrders,
                        OrderTabType.needsWaybill,
                      ),
                      _buildOrdersList(
                        _outForDeliveryOrders,
                        OrderTabType.outForDelivery,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.headerGradientStart, AppTheme.headerGradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Warehouse Fulfillment',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2, size: 18),
                const SizedBox(width: 6),
                const Text('To Pick'),
                if (_toPickOrders.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildTabBadge(_toPickOrders.length, AppTheme.primaryColor),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 6),
                const Text('Waybill'),
                if (_needsWaybillOrders.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildTabBadge(
                    _needsWaybillOrders.length,
                    AppTheme.warningColor,
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping, size: 18),
                const SizedBox(width: 6),
                const Text('Shipped'),
                if (_outForDeliveryOrders.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildTabBadge(
                    _outForDeliveryOrders.length,
                    AppTheme.successColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, email, or phone...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<models.Order> orders, OrderTabType tabType) {
    if (orders.isEmpty) {
      return _buildEmptyState(tabType);
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadOrders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, tabType);
        },
      ),
    );
  }

  Widget _buildEmptyState(OrderTabType tabType) {
    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (tabType) {
      case OrderTabType.toPick:
        title = 'No Orders to Pick';
        subtitle = 'All orders have been picked';
        icon = Icons.check_circle_outline;
        color = AppTheme.successColor;
        break;
      case OrderTabType.needsWaybill:
        title = 'No Waybills Pending';
        subtitle = 'All picked orders have waybills';
        icon = Icons.receipt_long;
        color = AppTheme.primaryColor;
        break;
      case OrderTabType.outForDelivery:
        title = 'No Shipments';
        subtitle = 'No orders out for delivery yet';
        icon = Icons.local_shipping;
        color = AppTheme.secondaryColor;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: color),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(models.Order order, OrderTabType tabType) {
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(order, tabType), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleOrderTap(order, tabType),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(order, tabType),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Info chips based on tab type
                _buildInfoRow(order, tabType, dateFormat),

                if (order.optInQuestions?['Shipping address'] != null &&
                    order.optInQuestions!['Shipping address']!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildShippingAddressInfo(order),
                ],

                // Progress bar for picking orders
                if (tabType == OrderTabType.toPick &&
                    order.currentStage == 'inventory_packing_list') ...[
                  const SizedBox(height: 12),
                  _buildPickingProgress(order),
                ],

                // Tracking info for shipped orders
                if (tabType == OrderTabType.outForDelivery &&
                    order.trackingNumber != null) ...[
                  const SizedBox(height: 12),
                  _buildTrackingInfo(order),
                ],

                const SizedBox(height: 12),
                _buildActionButton(order, tabType),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(models.Order order, OrderTabType tabType) {
    switch (tabType) {
      case OrderTabType.toPick:
        if (order.currentStage == 'inventory_packing_list') {
          return AppTheme.warningColor.withOpacity(0.5);
        }
        return AppTheme.borderColor;
      case OrderTabType.needsWaybill:
        return AppTheme.warningColor.withOpacity(0.5);
      case OrderTabType.outForDelivery:
        return AppTheme.successColor.withOpacity(0.5);
    }
  }

  Widget _buildStatusBadge(models.Order order, OrderTabType tabType) {
    String text;
    Color color;

    switch (tabType) {
      case OrderTabType.toPick:
        if (order.currentStage == 'inventory_packing_list') {
          if (order.isPartiallyPicked) {
            text = '${(order.pickingProgress * 100).toInt()}% picked';
          } else {
            text = 'Picking';
          }
          color = AppTheme.warningColor;
        } else {
          text = 'Pending';
          color = AppTheme.primaryColor;
        }
        break;
      case OrderTabType.needsWaybill:
        text = 'Needs Waybill';
        color = AppTheme.warningColor;
        break;
      case OrderTabType.outForDelivery:
        text = 'Shipped';
        color = AppTheme.successColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    models.Order order,
    OrderTabType tabType,
    DateFormat dateFormat,
  ) {
    final effectiveDate =
        order.confirmedInstallDate ?? order.earliestSelectedDate;

    return Row(
      children: [
        _buildInfoChip(
          Icons.calendar_today,
          effectiveDate != null ? dateFormat.format(effectiveDate) : 'No date',
          AppTheme.primaryColor,
        ),
        const SizedBox(width: 12),
        _buildInfoChip(
          Icons.inventory_2_outlined,
          '${order.items.length} items',
          AppTheme.secondaryColor,
        ),
        if (tabType == OrderTabType.needsWaybill) ...[
          const SizedBox(width: 12),
          _buildInfoChip(
            Icons.check_circle,
            'All Picked',
            AppTheme.successColor,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPickingProgress(models.Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Picking Progress',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor.withOpacity(0.7),
              ),
            ),
            Text(
              '${order.pickedItemCount}/${order.items.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: order.pickingProgress,
            backgroundColor: AppTheme.borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.warningColor,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildShippingAddressInfo(models.Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shipping Address',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.optInQuestions!['Shipping address']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo(models.Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, size: 20, color: AppTheme.successColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking Number',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Text(
                  order.trackingNumber ?? 'N/A',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
          if (order.waybillPhotoUrl != null)
            Icon(Icons.photo, size: 20, color: AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _buildActionButton(models.Order order, OrderTabType tabType) {
    String label;
    IconData icon;
    Color color;
    VoidCallback? onPressed;

    switch (tabType) {
      case OrderTabType.toPick:
        final isInProgress = order.currentStage == 'inventory_packing_list';
        label = isInProgress ? 'Continue Picking' : 'Start Picking';
        icon = isInProgress ? Icons.checklist : Icons.play_arrow;
        color = isInProgress ? AppTheme.warningColor : AppTheme.primaryColor;
        onPressed = () => _navigateToProcessing(order);
        break;
      case OrderTabType.needsWaybill:
        label = 'Add Tracking & Waybill';
        icon = Icons.add_photo_alternate;
        color = AppTheme.warningColor;
        onPressed = () => _navigateToShipping(order);
        break;
      case OrderTabType.outForDelivery:
        label = 'View Details';
        icon = Icons.visibility;
        color = AppTheme.successColor;
        onPressed = null; // View only for now
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _handleOrderTap(models.Order order, OrderTabType tabType) {
    switch (tabType) {
      case OrderTabType.toPick:
        _navigateToProcessing(order);
        break;
      case OrderTabType.needsWaybill:
        _navigateToShipping(order);
        break;
      case OrderTabType.outForDelivery:
        // Could show a detail view in the future
        break;
    }
  }
}

enum OrderTabType { toPick, needsWaybill, outForDelivery }
