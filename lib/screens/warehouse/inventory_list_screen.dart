import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory/inventory_stock.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/app_theme.dart';
import 'stock_take_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryProvider>();
      provider.listenToInventory();
      // Initialize stock records for products that don't have them
      provider.initializeStockForProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildHeader(context, provider),
              _buildStatsRow(provider),
              _buildSearchAndFilter(context, provider),
              Expanded(
                child: _buildInventoryList(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InventoryProvider provider) {
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
                Icons.inventory_2_outlined,
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
                    'Inventory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${provider.allStockItems.length} products',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(InventoryProvider provider) {
    final stats = provider.stats;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatCard(
            'In Stock',
            stats['inStock']?.toString() ?? '0',
            AppTheme.successColor,
            Icons.check_circle_outline,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Low Stock',
            stats['lowStock']?.toString() ?? '0',
            AppTheme.warningColor,
            Icons.warning_amber_outlined,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Out of Stock',
            stats['outOfStock']?.toString() ?? '0',
            AppTheme.errorColor,
            Icons.error_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, InventoryProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) => provider.setSearchQuery(value),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              filled: true,
              fillColor: AppTheme.cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', provider),
                const SizedBox(width: 8),
                _buildFilterChip('In Stock', 'in_stock', provider),
                const SizedBox(width: 8),
                _buildFilterChip('Low Stock', 'low_stock', provider),
                const SizedBox(width: 8),
                _buildFilterChip('Out of Stock', 'out_of_stock', provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, InventoryProvider provider) {
    final isSelected = provider.filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        provider.setFilterStatus(value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildInventoryList(BuildContext context, InventoryProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Error loading inventory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              style: TextStyle(color: AppTheme.secondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.listenToInventory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = provider.stockItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.secondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              provider.searchQuery.isNotEmpty || provider.filterStatus != 'all'
                  ? 'No matching products found'
                  : 'No products in inventory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            if (provider.searchQuery.isNotEmpty || provider.filterStatus != 'all') ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => provider.clearFilters(),
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final stock = items[index];
          return _buildInventoryCard(context, stock);
        },
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, InventoryStock stock) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: stock.isOutOfStock
              ? AppTheme.errorColor.withOpacity(0.5)
              : stock.isLowStock
                  ? AppTheme.warningColor.withOpacity(0.5)
                  : AppTheme.borderColor,
          width: stock.isLowStock || stock.isOutOfStock ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openStockTake(context, stock),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stock.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildStatusBadge(stock),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoPill(
                    Icons.inventory_2_outlined,
                    'Qty: ${stock.currentQty}',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoPill(
                    Icons.warning_amber_outlined,
                    'Min: ${stock.minStockLevel}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppTheme.secondaryColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stock.shelfLocation.isNotEmpty
                          ? '${stock.warehouseLocation} - ${stock.shelfLocation}'
                          : stock.warehouseLocation,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                  if (stock.lastStockTakeDate != null) ...[
                    Icon(
                      Icons.update,
                      size: 14,
                      color: AppTheme.secondaryColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(stock.lastStockTakeDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InventoryStock stock) {
    Color color;
    String label;

    if (stock.isOutOfStock) {
      color = AppTheme.errorColor;
      label = 'Out of Stock';
    } else if (stock.isLowStock) {
      color = AppTheme.warningColor;
      label = 'Low Stock';
    } else {
      color = AppTheme.successColor;
      label = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.secondaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _openStockTake(BuildContext context, InventoryStock stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StockTakeScreen(stock: stock),
      ),
    );
  }
}

