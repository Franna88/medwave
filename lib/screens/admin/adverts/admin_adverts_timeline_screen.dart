import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/facebook/facebook_ad_data.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../services/firebase/weekly_insights_service.dart';

/// Timeline Performance Analysis Screen
/// Shows Previous Week vs This Week comparison with results
class AdminAdvertsTimelineScreen extends StatefulWidget {
  const AdminAdvertsTimelineScreen({Key? key}) : super(key: key);

  @override
  State<AdminAdvertsTimelineScreen> createState() =>
      _AdminAdvertsTimelineScreenState();
}

class _AdminAdvertsTimelineScreenState
    extends State<AdminAdvertsTimelineScreen> {
  bool _isLoading = true;
  WeeklyAggregatedMetrics? _previousWeek;
  WeeklyAggregatedMetrics? _thisWeek;
  String? _error;

  String _timeFilter = 'thismonth';

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<PerformanceCostProvider>(
        context,
        listen: false,
      );

      // Get all ads (for metadata)
      final ads = provider.adPerformanceWithProducts.toList();

      // Calculate date range based on time filter
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime startDate;
      DateTime endDate;

      if (_timeFilter == 'last7days') {
        startDate = today.subtract(const Duration(days: 6));
        endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
      } else {
        // thismonth
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }

      print('📊 Timeline: Loading data for $_timeFilter');
      print(
        '📊 Timeline: Date range: ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
      );

      // Use optimized collection group query to fetch ALL weekly insights for the month
      // This is MUCH faster than querying each ad individually
      final weeklyDataMap =
          await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
            startDate: startDate,
            endDate: endDate,
          );

      if (!mounted) return;

      print(
        '📊 Timeline: Found ${weeklyDataMap.length} ads with weekly data for this month',
      );

      // Aggregate data by week
      final aggregated = _aggregateWeeklyData(weeklyDataMap, ads);

      if (!mounted) return;

      // Debug: Check what we got
      print(
        '📊 Timeline: Aggregated data - Previous: ${aggregated['previous'] != null}, Current: ${aggregated['current'] != null}',
      );

      setState(() {
        _previousWeek = aggregated['previous'];
        _thisWeek = aggregated['current'];
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Timeline: Error loading data: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load weekly data: $e';
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _timeFilter) {
      setState(() {
        _timeFilter = newFilter;
      });
      _loadWeeklyData();
    }
  }

  Map<String, WeeklyAggregatedMetrics?> _aggregateWeeklyData(
    Map<String, List<FacebookWeeklyInsight>> weeklyDataMap,
    List<AdPerformanceWithProduct> ads,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate proper calendar weeks (Sunday-Saturday)
    final thisWeekStart = _getWeekStart(today);
    final thisWeekEnd = _getWeekEnd(thisWeekStart);
    final previousWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final previousWeekEnd = _getWeekEnd(previousWeekStart);

    // Get all weekly insights
    final allWeeks = <FacebookWeeklyInsight>[];
    for (final weeklyList in weeklyDataMap.values) {
      allWeeks.addAll(weeklyList);
    }

    // Filter data for previous week
    final previousWeekData = allWeeks.where((week) {
      return (week.dateStart.isAfter(
                previousWeekStart.subtract(const Duration(days: 1)),
              ) ||
              week.dateStart.isAtSameMomentAs(previousWeekStart)) &&
          (week.dateStop.isBefore(
                previousWeekEnd.add(const Duration(days: 1)),
              ) ||
              week.dateStop.isAtSameMomentAs(previousWeekEnd));
    }).toList();

    // Filter data for this week
    final thisWeekData = allWeeks.where((week) {
      return (week.dateStart.isAfter(
                thisWeekStart.subtract(const Duration(days: 1)),
              ) ||
              week.dateStart.isAtSameMomentAs(thisWeekStart)) &&
          (week.dateStop.isBefore(thisWeekEnd.add(const Duration(days: 1))) ||
              week.dateStop.isAtSameMomentAs(thisWeekEnd));
    }).toList();

    return {
      'previous': previousWeekData.isNotEmpty
          ? _aggregateWeek(
              previousWeekData,
              ads,
              _getWeekRangeString(previousWeekStart),
            )
          : _createEmptyWeek(_getWeekRangeString(previousWeekStart)),
      'current': thisWeekData.isNotEmpty
          ? _aggregateWeek(
              thisWeekData,
              ads,
              _getWeekRangeString(thisWeekStart),
            )
          : _createEmptyWeek(_getWeekRangeString(thisWeekStart)),
    };
  }

  WeeklyAggregatedMetrics _aggregateWeek(
    List<FacebookWeeklyInsight> weekData,
    List<AdPerformanceWithProduct> ads,
    String dateRange,
  ) {
    double totalSpend = 0;
    int totalImpressions = 0;
    int totalClicks = 0;
    int totalLeads = 0;
    int totalBookings = 0;
    int totalDeposits = 0;
    double totalCash = 0;

    // Aggregate Facebook metrics from weekly data
    for (final week in weekData) {
      totalSpend += week.spend;
      totalImpressions += week.impressions;
      totalClicks += week.clicks;
    }

    // Get GHL metrics from ads (these are cumulative, not weekly-specific)
    // For a more accurate implementation, you'd need weekly GHL data too
    for (final ad in ads) {
      if (ad.ghlStats != null) {
        totalLeads += ad.ghlStats!.leads;
        totalBookings += ad.ghlStats!.bookings;
        totalDeposits += ad.ghlStats!.deposits;
        totalCash += ad.ghlStats!.cashAmount;
      }
    }

    // Calculate profit
    final totalProfit = totalCash - totalSpend;

    return WeeklyAggregatedMetrics(
      dateRange: dateRange,
      spend: totalSpend,
      impressions: totalImpressions,
      clicks: totalClicks,
      leads: totalLeads,
      bookings: totalBookings,
      deposits: totalDeposits,
      cash: totalCash,
      profit: totalProfit,
    );
  }

  /// Create an empty week with zero metrics
  WeeklyAggregatedMetrics _createEmptyWeek(String dateRange) {
    return WeeklyAggregatedMetrics(
      dateRange: dateRange,
      spend: 0,
      impressions: 0,
      clicks: 0,
      leads: 0,
      bookings: 0,
      deposits: 0,
      cash: 0,
      profit: 0,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Get the start of the week (Sunday) for a given date
  DateTime _getWeekStart(DateTime date) {
    // DateTime.weekday returns 1 for Monday, 7 for Sunday
    // We want Sunday as start, so we subtract (weekday % 7) days
    final daysSinceSunday = date.weekday % 7;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysSinceSunday));
  }

  /// Get the end of the week (Saturday 23:59:59) for a given date
  DateTime _getWeekEnd(DateTime weekStart) {
    return weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
  }

  /// Get date range string for a week
  String _getWeekRangeString(DateTime weekStart) {
    final weekEnd = _getWeekEnd(weekStart);
    return '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Performance Analysis'),
        actions: [
          // Time filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DropdownButton<String>(
              value: _timeFilter,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black, fontSize: 14),
              underline: Container(height: 1, color: Colors.black54),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              items: const [
                DropdownMenuItem<String>(
                  value: 'thismonth',
                  child: Text('This Month'),
                ),
                DropdownMenuItem<String>(
                  value: 'last7days',
                  child: Text('Last 7 Days'),
                ),
              ],
              onChanged: _onFilterChanged,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _previousWeek == null && _thisWeek == null
          ? _buildNoDataState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Viewing: ${_timeFilter == "thismonth" ? "This Month" : "Last 7 Days"}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Week-over-Week Comparison',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_previousWeek != null)
                        Expanded(child: _buildPreviousWeekCard(_previousWeek!)),
                      if (_previousWeek != null && _thisWeek != null)
                        const SizedBox(width: 24),
                      if (_thisWeek != null)
                        Expanded(child: _buildThisWeekCard(_thisWeek!)),
                    ],
                  ),
                  if (_previousWeek != null && _thisWeek != null) ...[
                    const SizedBox(height: 32),
                    _buildResultsGrid(_previousWeek!, _thisWeek!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadWeeklyData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No weekly data for ${_timeFilter == "thismonth" ? "This Month" : "Last 7 Days"}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different time range or ensure ads were running during this period',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadWeeklyData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  _onFilterChanged(
                    _timeFilter == 'thismonth' ? 'last7days' : 'thismonth',
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousWeekCard(WeeklyAggregatedMetrics metrics) {
    return Card(
      color: Colors.blue[50],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Previous Week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              metrics.dateRange,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            _buildMetricRow('Spend', '\$${metrics.spend.toStringAsFixed(0)}'),
            _buildMetricRow('Impressions', metrics.impressions.toString()),
            _buildMetricRow('Clicks', metrics.clicks.toString()),
            _buildMetricRow('Leads', metrics.leads.toString()),
            _buildMetricRow('Bookings', metrics.bookings.toString()),
            _buildMetricRow('Deposits', metrics.deposits.toString()),
            _buildMetricRow('Cash', '\$${metrics.cash.toStringAsFixed(0)}'),
            _buildMetricRow(
              'Profit',
              '\$${metrics.profit.toStringAsFixed(0)}',
              color: metrics.profit >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThisWeekCard(WeeklyAggregatedMetrics metrics) {
    return Card(
      color: Colors.green[50],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              metrics.dateRange,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            _buildMetricRow('Spend', '\$${metrics.spend.toStringAsFixed(0)}'),
            _buildMetricRow('Impressions', metrics.impressions.toString()),
            _buildMetricRow('Clicks', metrics.clicks.toString()),
            _buildMetricRow('Leads', metrics.leads.toString()),
            _buildMetricRow('Bookings', metrics.bookings.toString()),
            _buildMetricRow('Deposits', metrics.deposits.toString()),
            _buildMetricRow('Cash', '\$${metrics.cash.toStringAsFixed(0)}'),
            _buildMetricRow(
              'Profit',
              '\$${metrics.profit.toStringAsFixed(0)}',
              color: metrics.profit >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(
    WeeklyAggregatedMetrics previous,
    WeeklyAggregatedMetrics current,
  ) {
    final comparisons = [
      _createComparison(
        'Spend',
        previous.spend,
        current.spend,
        isGoodWhenUp: false,
      ),
      _createComparison(
        'Leads',
        previous.leads.toDouble(),
        current.leads.toDouble(),
      ),
      _createComparison('Profit', previous.profit, current.profit),
      _createComparison(
        'Impressions',
        previous.impressions.toDouble(),
        current.impressions.toDouble(),
      ),
      _createComparison(
        'Bookings',
        previous.bookings.toDouble(),
        current.bookings.toDouble(),
      ),
      _createComparison(
        'Deposits',
        previous.deposits.toDouble(),
        current.deposits.toDouble(),
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, size: 20),
                SizedBox(width: 8),
                Text(
                  '📊 Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: comparisons.length,
              itemBuilder: (context, index) =>
                  _buildComparisonCard(comparisons[index]),
            ),
          ],
        ),
      ),
    );
  }

  MetricComparison _createComparison(
    String label,
    double previousValue,
    double currentValue, {
    bool isGoodWhenUp = true,
  }) {
    final changePercent = previousValue > 0
        ? ((currentValue - previousValue) / previousValue) * 100
        : 0.0;
    final isIncrease = currentValue > previousValue;

    return MetricComparison(
      label: label,
      previousValue: previousValue,
      currentValue: currentValue,
      changePercent: changePercent,
      isIncrease: isIncrease,
      isGoodWhenUp: isGoodWhenUp,
    );
  }

  Widget _buildComparisonCard(MetricComparison comparison) {
    final isPositive = comparison.isGoodChange;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              comparison.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  comparison.isIncrease
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  '${comparison.changePercent.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPositive ? 'Good' : 'Bad',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly Aggregated Metrics Model
class WeeklyAggregatedMetrics {
  final String dateRange;
  final double spend;
  final int impressions;
  final int clicks;
  final int leads;
  final int bookings;
  final int deposits;
  final double cash;
  final double profit;

  WeeklyAggregatedMetrics({
    required this.dateRange,
    required this.spend,
    required this.impressions,
    required this.clicks,
    required this.leads,
    required this.bookings,
    required this.deposits,
    required this.cash,
    required this.profit,
  });
}

/// Metric Comparison Model
class MetricComparison {
  final String label;
  final double previousValue;
  final double currentValue;
  final double changePercent;
  final bool isIncrease;
  final bool isGoodWhenUp;

  MetricComparison({
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.changePercent,
    required this.isIncrease,
    required this.isGoodWhenUp,
  });

  bool get isGoodChange {
    if (isIncrease) {
      return isGoodWhenUp;
    } else {
      return !isGoodWhenUp;
    }
  }
}
