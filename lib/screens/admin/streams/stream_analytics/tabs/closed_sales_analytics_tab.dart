import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/streams/order.dart' as models;
import '../../../../../services/firebase/order_service.dart';
import '../../../../../theme/app_theme.dart';
import '../utils/analytics_helpers.dart';
import '../utils/closed_sales_analytics_helpers.dart';
import '../widgets/charts/analytics_charts.dart';
import '../widgets/shared/section_title.dart';
import '../widgets/shared/stat_card.dart';

/// Build chart data: count of closed sales per period (orders entering payment in each period).
List<Map<String, dynamic>> _buildClosedSalesChartData({
  required List<models.Order> withPayment,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  int maxPoints = 12,
}) {
  final durationDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 365 * 2);
  final step = durationDays / maxPoints.clamp(1, 24);
  final n = maxPoints.clamp(1, 24);
  final chartData = <Map<String, dynamic>>[];

  for (var i = 0; i < n; i++) {
    final periodStart = rangeStart.add(Duration(days: (step * i).round()));
    final periodEnd = rangeStart.add(Duration(days: (step * (i + 1)).round()));
    int count = 0;
    for (final o in withPayment) {
      final at = getPaymentEnteredAt(o);
      if (at != null &&
          !at.isBefore(periodStart) &&
          at.isBefore(periodEnd)) {
        count++;
      }
    }
    // Label by period midpoint so a sale on Jan 7 shows under a Jan label, not Dec
    final periodMid = periodStart.add(Duration(milliseconds: periodEnd.difference(periodStart).inMilliseconds ~/ 2));
    chartData.add({
      'label': DateFormat('MMM d').format(periodMid),
      'count': count,
    });
  }
  return chartData;
}

class ClosedSalesAnalyticsTab extends StatefulWidget {
  final String dateFilter;
  final String streamFilter;

  const ClosedSalesAnalyticsTab({
    super.key,
    required this.dateFilter,
    required this.streamFilter,
  });

  @override
  State<ClosedSalesAnalyticsTab> createState() =>
      _ClosedSalesAnalyticsTabState();
}

class _ClosedSalesAnalyticsTabState extends State<ClosedSalesAnalyticsTab> {
  final OrderService _orderService = OrderService();
  StreamSubscription<List<models.Order>>? _subscription;
  List<models.Order>? _orders;
  static const int _topSalesCount = 10;

  @override
  void initState() {
    super.initState();
    _subscription = _orderService.ordersStream().listen((orders) {
      if (mounted) {
        setState(() => _orders = orders);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _showData =>
      widget.streamFilter == 'all' || widget.streamFilter == 'operations';

  @override
  Widget build(BuildContext context) {
    if (_orders == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final orders = _orders!;
    final withPayment = _showData
        ? orders.where(hasEverEnteredPayment).toList()
        : <models.Order>[];

    final inPeriodList = withPayment
        .where((o) {
          final at = getPaymentEnteredAt(o);
          return at != null &&
              AnalyticsHelpers.isInDateRange(at, widget.dateFilter);
        })
        .toList();
    final totalSales = inPeriodList.length;
    final totalValue =
        inPeriodList.fold<double>(0, (sum, o) => sum + getOrderValue(o));
    final average =
        totalSales > 0 ? totalValue / totalSales : 0.0;

    final range = AnalyticsHelpers.getDateRange(widget.dateFilter);
    final rangeStart =
        range['start'] ?? DateTime.now().subtract(const Duration(days: 365));
    final rangeEnd = range['end'] ?? DateTime.now();
    final chartData = _buildClosedSalesChartData(
      withPayment: withPayment,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final topSales = inPeriodList
        .map((o) => (order: o, at: getPaymentEnteredAt(o)!))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final topSalesList = topSales.take(_topSalesCount).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_showData)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select Operations or All Streams to see Closed Sales analytics.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor.withOpacity(0.9),
                ),
              ),
            ),
          StatsRow(
            cards: [
              StatCard(
                label: 'Total Sales',
                value: '$totalSales',
                color: AppTheme.successColor,
                icon: Icons.check_circle,
              ),
              StatCard(
                label: 'Total Value',
                value: AnalyticsHelpers.formatCurrency(totalValue),
                color: AppTheme.primaryColor,
                icon: Icons.attach_money,
              ),
              StatCard(
                label: 'Avg Sale Value',
                value: AnalyticsHelpers.formatCurrency(average),
                color: AppTheme.infoColor,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Sales Performance'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildSalesChart(chartData),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Top Sales'),
          const SizedBox(height: 16),
          _buildTopSalesList(topSalesList),
        ],
      ),
    );
  }

  Widget _buildTopSalesList(
    List<({models.Order order, DateTime at})> items,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No closed sales in period',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
    return Column(
      children: items.map((item) {
        final o = item.order;
        final value = getOrderValue(o);
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
                            o.customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, y').format(item.at),
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
                          AnalyticsHelpers.formatCurrency(value),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
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
