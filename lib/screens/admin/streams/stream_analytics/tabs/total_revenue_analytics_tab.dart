import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/streams/appointment.dart' as app_models;
import '../../../../../models/streams/order.dart' as order_models;
import '../../../../../services/firebase/order_service.dart';
import '../../../../../services/firebase/sales_appointment_service.dart';
import '../../../../../theme/app_theme.dart';
import '../utils/analytics_helpers.dart';
import '../utils/closed_sales_analytics_helpers.dart';
import '../utils/deposit_analytics_helpers.dart';
import '../widgets/charts/analytics_charts.dart';
import '../widgets/shared/section_title.dart';
import '../widgets/shared/stat_card.dart';

String _inPeriodLabel(String dateFilter) {
  switch (dateFilter) {
    case 'today':
      return 'Today';
    case 'yesterday':
      return 'Yesterday';
    case 'last7days':
      return 'Last 7 Days';
    case 'last30days':
      return 'Last 30 Days';
    case 'last90days':
      return 'Last 90 Days';
    default:
      return 'In period';
  }
}

/// Build chart data: revenue (deposits + closed-sale balance) per period. Period label = midpoint.
List<Map<String, dynamic>> _buildRevenueChartData({
  required List<app_models.SalesAppointment> withDepositMade,
  required List<order_models.Order> withPayment,
  required Map<String, app_models.SalesAppointment> appointmentsById,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required bool includeDeposits,
  required bool includeClosedSales,
  int maxPoints = 12,
}) {
  final durationDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 365 * 2);
  final step = durationDays / maxPoints.clamp(1, 24);
  final n = maxPoints.clamp(1, 24);
  final chartData = <Map<String, dynamic>>[];

  for (var i = 0; i < n; i++) {
    final periodStart = rangeStart.add(Duration(days: (step * i).round()));
    final periodEnd = rangeStart.add(Duration(days: (step * (i + 1)).round()));
    double value = 0;
    if (includeDeposits) {
      for (final a in withDepositMade) {
        final at = getDepositMadeEnteredAt(a);
        final amount = a.depositAmount;
        if (at != null &&
            amount != null &&
            !at.isBefore(periodStart) &&
            at.isBefore(periodEnd)) {
          value += amount;
        }
      }
    }
    if (includeClosedSales) {
      for (final o in withPayment) {
        final at = getPaymentEnteredAt(o);
        if (at == null ||
            at.isBefore(periodStart) ||
            !at.isBefore(periodEnd)) continue;
        final subtotal = getOrderValue(o);
        final deposit = appointmentsById[o.appointmentId]?.depositAmount ?? 0;
        value += (subtotal - deposit).clamp(0.0, double.infinity);
      }
    }
    final periodMid = periodStart.add(
      Duration(milliseconds: periodEnd.difference(periodStart).inMilliseconds ~/ 2),
    );
    chartData.add({
      'label': DateFormat('MMM d').format(periodMid),
      'value': value,
    });
  }
  return chartData;
}

class TotalRevenueAnalyticsTab extends StatefulWidget {
  final String dateFilter;
  final String streamFilter;

  const TotalRevenueAnalyticsTab({
    super.key,
    required this.dateFilter,
    required this.streamFilter,
  });

  @override
  State<TotalRevenueAnalyticsTab> createState() =>
      _TotalRevenueAnalyticsTabState();
}

class _TotalRevenueAnalyticsTabState extends State<TotalRevenueAnalyticsTab> {
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  final OrderService _orderService = OrderService();
  StreamSubscription<List<app_models.SalesAppointment>>? _appSub;
  StreamSubscription<List<order_models.Order>>? _orderSub;
  List<app_models.SalesAppointment>? _appointments;
  List<order_models.Order>? _orders;

  @override
  void initState() {
    super.initState();
    _appSub = _appointmentService.appointmentsStream().listen((list) {
      if (mounted) setState(() => _appointments = list);
    });
    _orderSub = _orderService.ordersStream().listen((list) {
      if (mounted) setState(() => _orders = list);
    });
  }

  @override
  void dispose() {
    _appSub?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }

  bool get _showData =>
      widget.streamFilter == 'all' ||
      widget.streamFilter == 'sales' ||
      widget.streamFilter == 'operations';

  bool get _includeDeposits =>
      widget.streamFilter == 'all' || widget.streamFilter == 'sales';

  bool get _includeClosedSales =>
      widget.streamFilter == 'all' || widget.streamFilter == 'operations';

  @override
  Widget build(BuildContext context) {
    if (_appointments == null || _orders == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final appointments = _appointments!;
    final orders = _orders!;
    final appointmentsById = {for (final a in appointments) a.id: a};

    final withDepositMade = _includeDeposits
        ? appointments.where(hasEverEnteredDepositMade).toList()
        : <app_models.SalesAppointment>[];
    final withPayment = _includeClosedSales
        ? orders.where(hasEverEnteredPayment).toList()
        : <order_models.Order>[];

    // Deposits in period
    final depositsInPeriod = withDepositMade.where((a) {
      final at = getDepositMadeEnteredAt(a);
      return at != null &&
          AnalyticsHelpers.isInDateRange(at, widget.dateFilter) &&
          a.depositAmount != null;
    }).toList();
    final depositsSum = depositsInPeriod.fold<double>(
      0,
      (sum, a) => sum + (a.depositAmount ?? 0),
    );

    // Closed sales in period (balance only: subtotal - linked deposit)
    final closedSalesInPeriod = withPayment.where((o) {
      final at = getPaymentEnteredAt(o);
      return at != null &&
          AnalyticsHelpers.isInDateRange(at, widget.dateFilter);
    }).toList();
    double closedSalesSum = 0;
    for (final o in closedSalesInPeriod) {
      final subtotal = getOrderValue(o);
      final deposit = appointmentsById[o.appointmentId]?.depositAmount ?? 0;
      closedSalesSum += (subtotal - deposit).clamp(0.0, double.infinity);
    }

    final totalRevenue = depositsSum + closedSalesSum;

    final range = AnalyticsHelpers.getDateRange(widget.dateFilter);
    final rangeStart =
        range['start'] ?? DateTime.now().subtract(const Duration(days: 365));
    final rangeEnd = range['end'] ?? DateTime.now();
    final chartData = _buildRevenueChartData(
      withDepositMade: withDepositMade,
      withPayment: withPayment,
      appointmentsById: appointmentsById,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      includeDeposits: _includeDeposits,
      includeClosedSales: _includeClosedSales,
    );

    final bySource = <String, double>{
      'Deposits': depositsSum,
      'Closed Sales': closedSalesSum,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_showData)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select All, Sales, or Operations to see Total Revenue.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor.withOpacity(0.9),
                ),
              ),
            ),
          StatsRow(
            cards: [
              StatCard(
                label: 'Total Revenue',
                value: AnalyticsHelpers.formatCurrency(totalRevenue),
                color: AppTheme.successColor,
                icon: Icons.attach_money,
              ),
              StatCard(
                label: _inPeriodLabel(widget.dateFilter),
                value: AnalyticsHelpers.formatCurrency(totalRevenue),
                color: AppTheme.primaryColor,
                icon: Icons.calendar_today,
              ),
              StatCard(
                label: 'Growth',
                value: '–',
                color: AppTheme.secondaryColor,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Revenue Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildRevenueChart(chartData),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Revenue by Source'),
          const SizedBox(height: 16),
          _buildRevenueBySourceList(bySource),
        ],
      ),
    );
  }

  Widget _buildRevenueBySourceList(Map<String, double> sources) {
    return Column(
      children: sources.entries.map((entry) {
        IconData icon;
        Color color;
        switch (entry.key.toLowerCase()) {
          case 'deposits':
            icon = Icons.account_balance_wallet;
            color = AppTheme.primaryColor;
            break;
          case 'closed sales':
            icon = Icons.check_circle;
            color = AppTheme.successColor;
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
