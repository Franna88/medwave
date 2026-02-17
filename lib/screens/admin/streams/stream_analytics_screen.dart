import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'stream_analytics/widgets/shared/analytics_header.dart';
import 'stream_analytics/widgets/shared/analytics_filters_bar.dart';
import 'stream_analytics/widgets/shared/stat_card.dart';
import 'stream_analytics/widgets/shared/section_title.dart';
import 'stream_analytics/widgets/charts/analytics_charts.dart';
import 'stream_analytics/data/analytics_data_generators.dart';
import 'stream_analytics/utils/analytics_helpers.dart';

class StreamAnalyticsScreen extends StatefulWidget {
  const StreamAnalyticsScreen({super.key});

  @override
  State<StreamAnalyticsScreen> createState() => _StreamAnalyticsScreenState();
}

class _StreamAnalyticsScreenState extends State<StreamAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter state
  String _dateFilter = 'last30days';
  String _streamFilter = 'all';
  
  // Stock Levels filter state
  final TextEditingController _stockSearchController = TextEditingController();
  String _stockFilterStatus = 'all'; // all, in_stock, low_stock, out_of_stock
  String _stockSortBy = 'name'; // name, quantity, status

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stockSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const AnalyticsHeader(),
          AnalyticsFiltersBar(
            dateFilter: _dateFilter,
            streamFilter: _streamFilter,
            onDateFilterChanged: (value) => setState(() => _dateFilter = value),
            onStreamFilterChanged: (value) => setState(() => _streamFilter = value),
            onResetFilters: () {
              setState(() {
                _dateFilter = 'last30days';
                _streamFilter = 'all';
              });
            },
          ),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOptInsTab(),
                _buildDepositsTab(),
                _buildClosedSalesTab(),
                _buildLatePaymentsTab(),
                _buildTotalRevenueTab(),
                _buildGrossMarginTab(),
                _buildStockLevelsTab(),
                _buildStockForecastingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryColor,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: [
          Tab(text: 'Opt-Ins', icon: Icon(Icons.how_to_reg, size: 18)),
          Tab(text: 'Deposits', icon: Icon(Icons.account_balance_wallet, size: 18)),
          Tab(text: 'Closed Sales', icon: Icon(Icons.check_circle, size: 18)),
          Tab(text: 'Late Payments', icon: Icon(Icons.payment, size: 18)),
          Tab(text: 'Total Revenue', icon: Icon(Icons.attach_money, size: 18)),
          Tab(text: 'Gross Margin', icon: Icon(Icons.trending_up, size: 18)),
          Tab(text: 'Stock Levels', icon: Icon(Icons.inventory_2, size: 18)),
          Tab(text: 'Forecasting', icon: Icon(Icons.show_chart, size: 18)),
        ],
      ),
    );
  }


  // Opt-Ins Tab
  Widget _buildOptInsTab() {
    final mockData = AnalyticsDataGenerators.generateOptInsData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Total Opt-Ins', value: '${mockData['total']}', color: AppTheme.primaryColor, icon: Icons.how_to_reg),
            StatCard(label: 'This Month', value: '${mockData['thisMonth']}', color: AppTheme.successColor, icon: Icons.calendar_today),
            StatCard(label: 'Conversion Rate', value: '${mockData['conversionRate']}%', color: AppTheme.infoColor, icon: Icons.trending_up),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Opt-Ins Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildOptInsChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Recent Opt-Ins'),
          const SizedBox(height: 16),
          _buildOptInsList(mockData['recent'] as List<Map<String, dynamic>>),
        ],
      ),
    );
  }

  // Deposits Tab
  Widget _buildDepositsTab() {
    final mockData = AnalyticsDataGenerators.generateDepositsData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Total Deposits', value: '${mockData['count']}', color: AppTheme.primaryColor, icon: Icons.account_balance_wallet),
            StatCard(label: 'Total Value', value: AnalyticsHelpers.formatCurrency(mockData['totalValue']), color: AppTheme.successColor, icon: Icons.attach_money),
            StatCard(label: 'Average Deposit', value: AnalyticsHelpers.formatCurrency(mockData['average']), color: AppTheme.infoColor, icon: Icons.calculate),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Deposits Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildDepositsChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Deposit Breakdown'),
          const SizedBox(height: 16),
          _buildDepositBreakdown(mockData['breakdown'] as Map<String, dynamic>),
        ],
      ),
    );
  }

  // Closed Sales Tab
  Widget _buildClosedSalesTab() {
    final mockData = AnalyticsDataGenerators.generateClosedSalesData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Total Sales', value: '${mockData['count']}', color: AppTheme.successColor, icon: Icons.check_circle),
            StatCard(label: 'Total Value', value: AnalyticsHelpers.formatCurrency(mockData['totalValue']), color: AppTheme.primaryColor, icon: Icons.attach_money),
            StatCard(label: 'Avg Sale Value', value: AnalyticsHelpers.formatCurrency(mockData['average']), color: AppTheme.infoColor, icon: Icons.trending_up),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Sales Performance'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildSalesChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Top Sales'),
          const SizedBox(height: 16),
          _buildSalesList(mockData['topSales'] as List<Map<String, dynamic>>),
        ],
      ),
    );
  }

  // Late Payments Tab
  Widget _buildLatePaymentsTab() {
    final mockData = AnalyticsDataGenerators.generateLatePaymentsData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Late Payments', value: '${mockData['count']}', color: AppTheme.errorColor, icon: Icons.payment),
            StatCard(label: 'Total Outstanding', value: AnalyticsHelpers.formatCurrency(mockData['totalOutstanding']), color: AppTheme.warningColor, icon: Icons.money_off),
            StatCard(label: 'Avg Days Late', value: '${mockData['avgDaysLate']}', color: AppTheme.errorColor, icon: Icons.schedule),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Late Payments Trend'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildLatePaymentsChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Pending Payments'),
          const SizedBox(height: 16),
          _buildLatePaymentsList(mockData['pending'] as List<Map<String, dynamic>>),
        ],
      ),
    );
  }

  // Total Revenue Tab
  Widget _buildTotalRevenueTab() {
    final mockData = AnalyticsDataGenerators.generateRevenueData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Total Revenue', value: AnalyticsHelpers.formatCurrency(mockData['total']), color: AppTheme.successColor, icon: Icons.attach_money),
            StatCard(label: 'This Month', value: AnalyticsHelpers.formatCurrency(mockData['thisMonth']), color: AppTheme.primaryColor, icon: Icons.calendar_today),
            StatCard(label: 'Growth', value: '${mockData['growth']}%', color: mockData['growth'] >= 0 ? AppTheme.successColor : AppTheme.errorColor, icon: Icons.trending_up),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Revenue Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildRevenueChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Revenue by Source'),
          const SizedBox(height: 16),
          _buildRevenueBySource(mockData['bySource'] as Map<String, double>),
        ],
      ),
    );
  }

  // Gross Margin Tab
  Widget _buildGrossMarginTab() {
    final mockData = AnalyticsDataGenerators.generateGrossMarginData(_dateFilter);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Gross Margin', value: '${mockData['margin']}%', color: AppTheme.successColor, icon: Icons.trending_up),
            StatCard(label: 'Total Profit', value: AnalyticsHelpers.formatCurrency(mockData['profit']), color: AppTheme.primaryColor, icon: Icons.account_balance),
            StatCard(label: 'COGS', value: AnalyticsHelpers.formatCurrency(mockData['cogs']), color: AppTheme.secondaryColor, icon: Icons.shopping_cart),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Margin Trend'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildMarginChart(mockData['chartData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Profit Breakdown'),
          const SizedBox(height: 16),
          _buildProfitBreakdown(mockData['breakdown'] as Map<String, dynamic>),
        ],
      ),
    );
  }

  // Stock Levels Tab
  Widget _buildStockLevelsTab() {
    final mockData = AnalyticsDataGenerators.generateStockLevelsData();
    final allItems = mockData['allItems'] as List<Map<String, dynamic>>;
    final filteredItems = _filterAndSortStockItems(allItems);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: StatsRow(cards: [
              StatCard(label: 'In Stock', value: '${mockData['inStock']}', color: AppTheme.successColor, icon: Icons.check_circle),
              StatCard(label: 'Low Stock', value: '${mockData['lowStock']}', color: AppTheme.warningColor, icon: Icons.warning),
              StatCard(label: 'Out of Stock', value: '${mockData['outOfStock']}', color: AppTheme.errorColor, icon: Icons.error),
            ]),
          ),
          // Search and Filter Bar
          _buildStockSearchAndFilter(),
          // Chart (collapsible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnalyticsCharts.buildStockLevelsChart(mockData['chartData'] as List<Map<String, dynamic>>),
          ),
          const SizedBox(height: 16),
          // Items List (scrolls with the page via shrinkWrap)
          filteredItems.isEmpty
              ? SizedBox(
                  height: 200,
                  child: _buildEmptyStockState(),
                )
              : _buildStockItemsList(filteredItems),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildStockSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _stockSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search products by name, location...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _stockSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _stockSearchController.clear();
                        setState(() {});
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
          // Filter chips and sort
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStockFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildStockFilterChip('In Stock', 'in_stock'),
                      const SizedBox(width: 8),
                      _buildStockFilterChip('Low Stock', 'low_stock'),
                      const SizedBox(width: 8),
                      _buildStockFilterChip('Out of Stock', 'out_of_stock'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.cardColor,
                ),
                child: DropdownButton<String>(
                  value: _stockSortBy,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: AppTheme.secondaryColor),
                  style: TextStyle(fontSize: 12, color: AppTheme.textColor),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                    DropdownMenuItem(value: 'quantity', child: Text('Sort: Quantity')),
                    DropdownMenuItem(value: 'status', child: Text('Sort: Status')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _stockSortBy = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStockFilterChip(String label, String value) {
    final isSelected = _stockFilterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _stockFilterStatus = value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
  
  List<Map<String, dynamic>> _filterAndSortStockItems(List<Map<String, dynamic>> items) {
    var filtered = items;
    
    // Apply search filter
    if (_stockSearchController.text.isNotEmpty) {
      final query = _stockSearchController.text.toLowerCase();
      filtered = filtered.where((item) {
        final nameMatch = item['name'].toString().toLowerCase().contains(query);
        final location = item['location'];
        final locationMatch = location != null && location.toString().toLowerCase().contains(query);
        return nameMatch || locationMatch;
      }).toList();
    }
    
    // Apply status filter
    if (_stockFilterStatus != 'all') {
      filtered = filtered.where((item) {
        final status = item['status'] as String;
        switch (_stockFilterStatus) {
          case 'in_stock':
            return status == 'in_stock';
          case 'low_stock':
            return status == 'low_stock';
          case 'out_of_stock':
            return status == 'out_of_stock';
          default:
            return true;
        }
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (_stockSortBy) {
        case 'quantity':
          return (b['current'] as int).compareTo(a['current'] as int);
        case 'status':
          final statusOrder = {'out_of_stock': 0, 'low_stock': 1, 'in_stock': 2};
          final aStatus = statusOrder[a['status']] ?? 3;
          final bStatus = statusOrder[b['status']] ?? 3;
          return aStatus.compareTo(bStatus);
        case 'name':
        default:
          return (a['name'] as String).compareTo(b['name'] as String);
      }
    });
    
    return filtered;
  }
  
  Widget _buildEmptyStockState() {
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
            _stockSearchController.text.isNotEmpty || _stockFilterStatus != 'all'
                ? 'No items match your filters'
                : 'No stock items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          if (_stockSearchController.text.isNotEmpty || _stockFilterStatus != 'all') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _stockSearchController.clear();
                setState(() {
                  _stockFilterStatus = 'all';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStockItemsList(List<Map<String, dynamic>> items) {
    // Group items by status
    final groupedItems = <String, List<Map<String, dynamic>>>{};
    for (var item in items) {
      final status = item['status'] as String;
      groupedItems.putIfAbsent(status, () => []).add(item);
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final status = groupedItems.keys.elementAt(index);
        final statusItems = groupedItems[status]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0) const SizedBox(height: 24),
            _buildStockStatusHeader(status, statusItems.length),
            const SizedBox(height: 12),
            ...statusItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStockItemCard(item),
            )),
          ],
        );
      },
    );
  }
  
  Widget _buildStockStatusHeader(String status, int count) {
    String title;
    IconData icon;
    Color color;
    
    switch (status) {
      case 'in_stock':
        title = 'In Stock';
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case 'low_stock':
        title = 'Low Stock';
        icon = Icons.warning;
        color = AppTheme.warningColor;
        break;
      case 'out_of_stock':
        title = 'Out of Stock';
        icon = Icons.error;
        color = AppTheme.errorColor;
        break;
      default:
        title = 'Other';
        icon = Icons.inventory_2;
        color = AppTheme.secondaryColor;
    }
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStockItemCard(Map<String, dynamic> item) {
    final status = item['status'] as String;
    Color borderColor;
    Color statusColor;
    
    switch (status) {
      case 'in_stock':
        borderColor = AppTheme.successColor.withOpacity(0.3);
        statusColor = AppTheme.successColor;
        break;
      case 'low_stock':
        borderColor = AppTheme.warningColor.withOpacity(0.3);
        statusColor = AppTheme.warningColor;
        break;
      case 'out_of_stock':
        borderColor = AppTheme.errorColor.withOpacity(0.3);
        statusColor = AppTheme.errorColor;
        break;
      default:
        borderColor = AppTheme.borderColor;
        statusColor = AppTheme.secondaryColor;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStockInfoChip(
                            Icons.inventory_2_outlined,
                            'Qty: ${item['current']}',
                            AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildStockInfoChip(
                            Icons.warning_amber_outlined,
                            'Min: ${item['min']}',
                            AppTheme.warningColor,
                          ),
                          if (item['location'] != null) ...[
                            const SizedBox(width: 8),
                            _buildStockInfoChip(
                              Icons.location_on,
                              item['location'],
                              AppTheme.infoColor,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${item['percent']}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status == 'in_stock' 
                          ? 'In Stock'
                          : status == 'low_stock'
                              ? 'Low Stock'
                              : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStockInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Stock Forecasting Tab
  Widget _buildStockForecastingTab() {
    final mockData = AnalyticsDataGenerators.generateForecastingData();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsRow(cards: [
            StatCard(label: 'Forecast Period', value: '6 Months', color: AppTheme.primaryColor, icon: Icons.calendar_today),
            StatCard(label: 'Predicted Demand', value: '${mockData['predictedDemand']}', color: AppTheme.infoColor, icon: Icons.show_chart),
            StatCard(label: 'Reorder Points', value: '${mockData['reorderPoints']}', color: AppTheme.warningColor, icon: Icons.warning),
          ]),
          const SizedBox(height: 24),
          const SectionTitle(title: '6-Month Demand Forecast'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildForecastChart(mockData['forecastData'] as List<Map<String, dynamic>>),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Recommended Reorders'),
          const SizedBox(height: 16),
          _buildReorderList(mockData['reorders'] as List<Map<String, dynamic>>),
        ],
      ),
    );
  }

  // List Widgets
  Widget _buildOptInsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No opt-ins found',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
    
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['date'],
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        item['source'],
                        style: TextStyle(
                          color: AppTheme.secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDepositBreakdown(Map<String, dynamic> breakdown) {
    return Column(
      children: breakdown.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      entry.key.contains('Full') ? Icons.payment : Icons.account_balance_wallet,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              Text(
                AnalyticsHelpers.formatCurrency(entry.value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No sales found',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
    
    return Column(
      children: sales.map((sale) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale['customer'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sale['date'],
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AnalyticsHelpers.formatCurrency(sale['amount']),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Closed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLatePaymentsList(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No late payments found',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
    
    return Column(
      children: payments.map((payment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['customer'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 12,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${payment['daysLate']} days late',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                payment['date'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AnalyticsHelpers.formatCurrency(payment['amount']),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Outstanding',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevenueBySource(Map<String, double> sources) {
    return Column(
      children: sources.entries.map((entry) {
        IconData icon;
        Color color;
        switch (entry.key.toLowerCase()) {
          case 'sales':
            icon = Icons.attach_money;
            color = AppTheme.successColor;
            break;
          case 'deposits':
            icon = Icons.account_balance_wallet;
            color = AppTheme.primaryColor;
            break;
          case 'installations':
            icon = Icons.build;
            color = AppTheme.infoColor;
            break;
          default:
            icon = Icons.trending_up;
            color = AppTheme.secondaryColor;
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              Text(
                AnalyticsHelpers.formatCurrency(entry.value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfitBreakdown(Map<String, dynamic> breakdown) {
    return Column(
      children: breakdown.entries.map((entry) {
        IconData icon;
        Color color;
        
        if (entry.key.toLowerCase().contains('revenue')) {
          icon = Icons.trending_up;
          color = AppTheme.successColor;
        } else if (entry.key.toLowerCase().contains('cogs')) {
          icon = Icons.shopping_cart;
          color = AppTheme.errorColor;
        } else if (entry.key.toLowerCase().contains('profit')) {
          icon = Icons.account_balance;
          color = AppTheme.primaryColor;
        } else {
          icon = Icons.percent;
          color = AppTheme.infoColor;
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              Text(
                entry.value is double
                    ? AnalyticsHelpers.formatCurrency(entry.value)
                    : '${entry.value}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReorderList(List<Map<String, dynamic>> reorders) {
    if (reorders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No reorders needed',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
    
    return Column(
      children: reorders.map((reorder) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warningColor.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.warning,
                        color: AppTheme.warningColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reorder['name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Reorder: ${reorder['quantity']} units',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reorder['date'],
                                style: TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recommended',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

}
