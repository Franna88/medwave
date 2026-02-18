import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/streams/appointment.dart' as models;
import '../../../../../models/streams/stream_stage.dart';
import '../../../../../services/firebase/sales_appointment_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/appointments/appointment_detail_dialog.dart';
import '../utils/analytics_helpers.dart';
import '../utils/opt_in_analytics_helpers.dart';
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

/// Build cumulative chart data: list of { label, value } for period ends in range.
List<Map<String, dynamic>> _buildCumulativeChartData({
  required List<DateTime> optInDates,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  int maxPoints = 12,
}) {
  if (optInDates.isEmpty) {
    final step = rangeEnd.difference(rangeStart).inDays / maxPoints.clamp(1, 365);
    return List.generate(maxPoints.clamp(1, 24), (i) {
      final d = rangeStart.add(Duration(days: (step * (i + 1)).round()));
      return {'label': DateFormat('MMM d').format(d), 'value': 0};
    });
  }
  final sortedDates = List<DateTime>.from(optInDates)..sort();
  final durationDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 365 * 2);
  final step = durationDays / maxPoints.clamp(1, 24);
  final periodEnds = List.generate(maxPoints.clamp(1, 24), (i) {
    final days = (step * (i + 1)).round();
    return DateTime(rangeStart.year, rangeStart.month, rangeStart.day)
        .add(Duration(days: days));
  });
  final chartData = <Map<String, dynamic>>[];
  int cumulative = 0;
  int dateIdx = 0;
  for (final periodEnd in periodEnds) {
    while (dateIdx < sortedDates.length && sortedDates[dateIdx].isBefore(periodEnd.add(const Duration(days: 1)))) {
      cumulative++;
      dateIdx++;
    }
    chartData.add({
      'label': DateFormat('MMM d').format(periodEnd),
      'value': cumulative,
    });
  }
  return chartData;
}

class OptInAnalyticsTab extends StatefulWidget {
  final String dateFilter;
  final String streamFilter;

  const OptInAnalyticsTab({
    super.key,
    required this.dateFilter,
    required this.streamFilter,
  });

  @override
  State<OptInAnalyticsTab> createState() => _OptInAnalyticsTabState();
}

class _OptInAnalyticsTabState extends State<OptInAnalyticsTab> {
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  StreamSubscription<List<models.SalesAppointment>>? _subscription;
  List<models.SalesAppointment>? _appointments;
  static const int _recentCount = 10;

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
    final withOptIn = _showData
        ? appointments.where(hasEverEnteredOptIn).toList()
        : <models.SalesAppointment>[];
    final total = withOptIn.length;
    final inPeriod = total == 0
        ? 0
        : withOptIn
            .where((a) => AnalyticsHelpers.isInDateRange(getOptInEnteredAt(a)!, widget.dateFilter))
            .length;
    final converted =
        withOptIn.where(hasMovedToDepositRequestedOrLater).length;
    final conversionRate = total > 0 ? (converted / total * 100) : 0.0;

    final optInDates = withOptIn
        .map((a) => getOptInEnteredAt(a))
        .whereType<DateTime>()
        .toList();
    final range = AnalyticsHelpers.getDateRange(widget.dateFilter);
    final rangeStart = range['start'] ?? DateTime.now().subtract(const Duration(days: 365));
    final rangeEnd = range['end'] ?? DateTime.now();
    final chartData = _buildCumulativeChartData(
      optInDates: optInDates,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final recent = withOptIn
        .map((a) => (appointment: a, enteredAt: getOptInEnteredAt(a)!))
        .toList()
      ..sort((a, b) => b.enteredAt.compareTo(a.enteredAt));
    final recentList = recent.take(_recentCount).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_showData)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select Sales or All Streams to see Opt In analytics.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor.withOpacity(0.9),
                ),
              ),
            ),
          StatsRow(
            cards: [
              StatCard(
                label: 'Total Opt-Ins',
                value: '$total',
                color: AppTheme.primaryColor,
                icon: Icons.how_to_reg,
              ),
              StatCard(
                label: _inPeriodLabel(widget.dateFilter),
                value: '$inPeriod',
                color: AppTheme.successColor,
                icon: Icons.calendar_today,
              ),
              StatCard(
                label: 'Conversion Rate',
                value: total > 0 ? '${conversionRate.toStringAsFixed(1)}%' : '0%',
                color: AppTheme.infoColor,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Opt-Ins Over Time'),
          const SizedBox(height: 16),
          AnalyticsCharts.buildOptInsChart(chartData),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Recent Opt-Ins'),
          const SizedBox(height: 16),
          _buildRecentList(recentList),
        ],
      ),
    );
  }

  Widget _buildRecentList(
    List<({models.SalesAppointment appointment, DateTime enteredAt})> items,
  ) {
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
        final apt = item.appointment;
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
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AppointmentDetailDialog(
                    appointment: apt,
                    stages: StreamStage.getSalesStages(),
                  ),
                );
              },
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
                            apt.customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, y').format(item.enteredAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryColor.withOpacity(0.7),
                            ),
                          ),
                        ],
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
}
