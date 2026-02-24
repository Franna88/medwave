import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/streams/appointment.dart' as models;
import '../../../../../services/firebase/sales_appointment_service.dart';
import '../../../../../theme/app_theme.dart';
import '../utils/analytics_helpers.dart';
import '../utils/deposit_analytics_helpers.dart';
import '../widgets/charts/analytics_charts.dart';
import '../widgets/shared/section_title.dart';
import '../widgets/shared/stat_card.dart';

/// In-period stat label from date filter.
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

/// Build chart data: value (sum of depositAmount) per period for deposits in range.
List<Map<String, dynamic>> _buildDepositsChartData({
  required List<models.SalesAppointment> withDepositMade,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required String dateFilter,
  int maxPoints = 12,
}) {
  final durationDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 365 * 2);
  final step = durationDays / maxPoints.clamp(1, 24);
  final n = maxPoints.clamp(1, 24);
  final chartData = <Map<String, dynamic>>[];

  for (var i = 0; i < n; i++) {
    final periodStart = rangeStart.add(Duration(days: (step * i).round()));
    final periodEnd = rangeStart.add(Duration(days: (step * (i + 1)).round()));
    double sum = 0;
    for (final a in withDepositMade) {
      final at = getDepositMadeEnteredAt(a);
      final amount = a.depositAmount;
      if (at != null &&
          amount != null &&
          !at.isBefore(periodStart) &&
          at.isBefore(periodEnd)) {
        sum += amount;
      }
    }
    chartData.add({
      'label': DateFormat('MMM d').format(periodStart),
      'value': sum,
    });
  }
  return chartData;
}

class DepositsAnalyticsTab extends StatefulWidget {
  final String dateFilter;
  final String streamFilter;

  const DepositsAnalyticsTab({
    super.key,
    required this.dateFilter,
    required this.streamFilter,
  });

  @override
  State<DepositsAnalyticsTab> createState() => _DepositsAnalyticsTabState();
}

class _DepositsAnalyticsTabState extends State<DepositsAnalyticsTab> {
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  StreamSubscription<List<models.SalesAppointment>>? _subscription;
  List<models.SalesAppointment>? _appointments;

  @override
  void initState() {
    super.initState();
    _subscription = _appointmentService.appointmentsStream().listen((appointments) {
      if (mounted) {
        setState(() => _appointments = appointments);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _showData =>
      widget.streamFilter == 'all' || widget.streamFilter == 'sales';

  @override
  Widget build(BuildContext context) {
    if (_appointments == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final appointments = _appointments!;
    final withDepositMade = _showData
        ? appointments.where(hasEverEnteredDepositMade).toList()
        : <models.SalesAppointment>[];

    final total = withDepositMade.length;

    final inPeriodList = withDepositMade
        .where((a) {
          final at = getDepositMadeEnteredAt(a);
          return at != null &&
              AnalyticsHelpers.isInDateRange(at, widget.dateFilter);
        })
        .toList();
    final inPeriodCount = inPeriodList.length;

    final inPeriodWithAmount =
        inPeriodList.where((a) => a.depositAmount != null).toList();
    final totalValue = inPeriodWithAmount.fold<double>(
        0, (sum, a) => sum + (a.depositAmount ?? 0));
    final countWithAmount = inPeriodWithAmount.length;
    final average =
        countWithAmount > 0 ? totalValue / countWithAmount : 0.0;

    final range = AnalyticsHelpers.getDateRange(widget.dateFilter);
    final rangeStart =
        range['start'] ?? DateTime.now().subtract(const Duration(days: 365));
    final rangeEnd = range['end'] ?? DateTime.now();
    final chartData = _buildDepositsChartData(
      withDepositMade: withDepositMade,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      dateFilter: widget.dateFilter,
    );

    double fullPaymentValue = 0;
    double depositOnlyValue = 0;
    for (final a in inPeriodList) {
      final amount = a.depositAmount ?? 0;
      if (a.paymentType == 'full_payment') {
        fullPaymentValue += amount;
      } else {
        depositOnlyValue += amount;
      }
    }
    final breakdown = <String, double>{
      'Full Payment': fullPaymentValue,
      'Deposit Only': depositOnlyValue,
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
                'Select Sales or All Streams to see Deposits analytics.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor.withOpacity(0.9),
                ),
              ),
            ),
          StatsRow(
            cards: [
              StatCard(
                label: 'Total Deposits',
                value: '$total',
                color: AppTheme.primaryColor,
                icon: Icons.account_balance_wallet,
              ),
              StatCard(
                label: _inPeriodLabel(widget.dateFilter),
                value: '$inPeriodCount',
                color: AppTheme.successColor,
                icon: Icons.calendar_today,
              ),
              StatCard(
                label: 'Total Value',
                value: AnalyticsHelpers.formatCurrency(totalValue),
                color: AppTheme.infoColor,
                icon: Icons.attach_money,
              ),
              StatCard(
                label: 'Average Deposit',
                value: AnalyticsHelpers.formatCurrency(average),
                color: AppTheme.infoColor,
                icon: Icons.calculate,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Deposits Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildDepositsChart(chartData),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Deposit Breakdown'),
          const SizedBox(height: 16),
          _buildDepositBreakdown(breakdown),
        ],
      ),
    );
  }

  Widget _buildDepositBreakdown(Map<String, double> breakdown) {
    if (breakdown.values.every((v) => v == 0)) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No deposits in period',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ),
      );
    }
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
                      entry.key.contains('Full')
                          ? Icons.payment
                          : Icons.account_balance_wallet,
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
}
