import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/streams/order.dart' as models;
import '../../services/firebase/order_service.dart';
import '../../theme/app_theme.dart';
import 'order_processing_screen.dart';

/// Screen displaying orders due for installation within 30 days
/// Shows orders in Priority Shipment stage, sorted by nearest install date
class WarehouseOrdersScreen extends StatefulWidget {
  const WarehouseOrdersScreen({super.key});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  List<models.Order> _allOrders = [];
  List<models.Order> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    _orderService.ordersStream().listen((orders) {
      if (mounted) {
        setState(() {
          // Filter orders in priority_shipment OR inventory_packing_list stage
          // with confirmedInstallDate within next 30 days
          final now = DateTime.now();
          final thirtyDaysFromNow = now.add(const Duration(days: 30));

          _allOrders = orders.where((order) {
            // Check stage - show priority_shipment and inventory_packing_list
            final validStage = order.currentStage == 'priority_shipment' ||
                order.currentStage == 'inventory_packing_list';
            if (!validStage) return false;

            // Check if confirmedInstallDate exists and is within 30 days
            if (order.confirmedInstallDate == null) return false;

            final installDate = order.confirmedInstallDate!;
            return installDate.isAfter(now.subtract(const Duration(days: 1))) &&
                installDate.isBefore(thirtyDaysFromNow);
          }).toList();

          // Sort by confirmedInstallDate ascending (nearest first)
          _allOrders.sort((a, b) {
            final dateA = a.confirmedInstallDate;
            final dateB = b.confirmedInstallDate;
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateA.compareTo(dateB);
          });

          _filterOrders();
          _isLoading = false;
        });
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterOrders();
    });
  }

  void _filterOrders() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = _allOrders;
    } else {
      _filteredOrders = _allOrders.where((order) {
        return order.customerName.toLowerCase().contains(_searchQuery) ||
            order.email.toLowerCase().contains(_searchQuery) ||
            order.phone.contains(_searchQuery);
      }).toList();
    }
  }

  void _navigateToProcessing(models.Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderProcessingScreen(order: order),
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
          _buildStatsRow(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersList(),
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
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Due within 30 days',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredOrders.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final pendingCount = _allOrders
        .where((o) => o.currentStage == 'priority_shipment')
        .length;
    final inProgressCount = _allOrders
        .where((o) => o.currentStage == 'inventory_packing_list')
        .length;
    final partiallyPickedCount = _allOrders
        .where((o) => o.isPartiallyPicked)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingCount.toString(),
              AppTheme.primaryColor,
              Icons.pending_actions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              inProgressCount.toString(),
              AppTheme.warningColor,
              Icons.inventory_2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Partial',
              partiallyPickedCount.toString(),
              AppTheme.pinkColor,
              Icons.checklist,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Orders Due',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No orders are due for installation\nwithin the next 30 days',
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

  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadOrders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(models.Order order) {
    final dateFormat = DateFormat('EEE, MMM d');
    final daysUntilInstall = order.confirmedInstallDate != null
        ? order.confirmedInstallDate!.difference(DateTime.now()).inDays
        : 0;

    final isUrgent = daysUntilInstall <= 7;
    final isInProgress = order.currentStage == 'inventory_packing_list';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppTheme.errorColor.withOpacity(0.3)
              : isInProgress
                  ? AppTheme.warningColor.withOpacity(0.3)
                  : AppTheme.borderColor,
          width: isUrgent || isInProgress ? 2 : 1,
        ),
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
          onTap: () => _navigateToProcessing(order),
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
                    _buildStatusBadge(order, isUrgent, daysUntilInstall),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today,
                      order.confirmedInstallDate != null
                          ? dateFormat.format(order.confirmedInstallDate!)
                          : 'No date',
                      isUrgent ? AppTheme.errorColor : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.inventory_2_outlined,
                      '${order.items.length} items',
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                if (isInProgress) ...[
                  const SizedBox(height: 12),
                  _buildPickingProgress(order),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToProcessing(order),
                    icon: Icon(
                      isInProgress ? Icons.checklist : Icons.play_arrow,
                      size: 20,
                    ),
                    label: Text(isInProgress ? 'Continue Picking' : 'Process'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInProgress
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(models.Order order, bool isUrgent, int daysUntilInstall) {
    String text;
    Color color;

    if (order.currentStage == 'inventory_packing_list') {
      if (order.isPartiallyPicked) {
        text = '${(order.pickingProgress * 100).toInt()}% picked';
        color = AppTheme.warningColor;
      } else {
        text = 'Picking';
        color = AppTheme.warningColor;
      }
    } else if (isUrgent) {
      text = daysUntilInstall == 0
          ? 'Today!'
          : daysUntilInstall == 1
              ? 'Tomorrow'
              : '$daysUntilInstall days';
      color = AppTheme.errorColor;
    } else {
      text = '$daysUntilInstall days';
      color = AppTheme.primaryColor;
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
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

