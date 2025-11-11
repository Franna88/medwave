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
  State<AdminAdvertsTimelineScreen> createState() => _AdminAdvertsTimelineScreenState();
}

class _AdminAdvertsTimelineScreenState extends State<AdminAdvertsTimelineScreen> {
  bool _isLoading = true;
  WeeklyAggregatedMetrics? _previousWeek;
  WeeklyAggregatedMetrics? _thisWeek;
  String? _error;
  
  // Month filter state
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    _loadWeeklyData();
  }

  void _initializeMonths() {
    // Generate last 6 months
    final now = DateTime.now();
    _availableMonths = List.generate(6, (index) {
      return DateTime(now.year, now.month - index, 1);
    });
    // Default to previous month (more likely to have complete data)
    _selectedMonth = _availableMonths.length > 1 ? _availableMonths[1] : _availableMonths.first;
  }

  Future<void> _loadWeeklyData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<PerformanceCostProvider>(context, listen: false);
      
      // Get all ads (for metadata)
      final ads = provider.adPerformanceWithProducts.toList();

      // Calculate date range for selected month
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      print('📊 Timeline: Loading data for ${_formatMonthYear(_selectedMonth)}');
      print('📊 Timeline: Date range: ${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}');

      // Use optimized collection group query to fetch ALL weekly insights for the month
      // This is MUCH faster than querying each ad individually
      final weeklyDataMap = await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      print('📊 Timeline: Found ${weeklyDataMap.length} ads with weekly data for this month');

      // Aggregate data by week
      final aggregated = _aggregateWeeklyData(weeklyDataMap, ads);

      if (!mounted) return;
      
      // Debug: Check what we got
      print('📊 Timeline: Aggregated data - Previous: ${aggregated['previous'] != null}, Current: ${aggregated['current'] != null}');
      
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

  void _onMonthChanged(DateTime? newMonth) {
    if (newMonth != null && newMonth != _selectedMonth) {
      setState(() {
        _selectedMonth = newMonth;
      });
      _loadWeeklyData();
    }
  }

  Map<String, WeeklyAggregatedMetrics?> _aggregateWeeklyData(
    Map<String, List<FacebookWeeklyInsight>> weeklyDataMap,
    List<AdPerformanceWithProduct> ads,
  ) {
    // Get all weeks from all ads
    final allWeeks = <FacebookWeeklyInsight>[];
    for (final weeklyList in weeklyDataMap.values) {
      allWeeks.addAll(weeklyList);
    }

    if (allWeeks.isEmpty) {
      return {'previous': null, 'current': null};
    }

    // Sort by date
    allWeeks.sort((a, b) => a.dateStart.compareTo(b.dateStart));

    // Get unique weeks by date range
    final weeksByDateRange = <String, List<FacebookWeeklyInsight>>{};
    for (final week in allWeeks) {
      final key = '${week.dateStart.toIso8601String().split('T')[0]}_${week.dateStop.toIso8601String().split('T')[0]}';
      weeksByDateRange.putIfAbsent(key, () => []).add(week);
    }

    final uniqueWeeks = weeksByDateRange.keys.toList()..sort();

    if (uniqueWeeks.length < 2) {
      // Not enough weeks
      if (uniqueWeeks.length == 1) {
        final currentWeekData = weeksByDateRange[uniqueWeeks[0]]!;
        return {
          'previous': null,
          'current': _aggregateWeek(currentWeekData, ads),
        };
      }
      return {'previous': null, 'current': null};
    }

    // Get last two weeks
    final previousWeekKey = uniqueWeeks[uniqueWeeks.length - 2];
    final currentWeekKey = uniqueWeeks[uniqueWeeks.length - 1];

    final previousWeekData = weeksByDateRange[previousWeekKey]!;
    final currentWeekData = weeksByDateRange[currentWeekKey]!;

    return {
      'previous': _aggregateWeek(previousWeekData, ads),
      'current': _aggregateWeek(currentWeekData, ads),
    };
  }

  WeeklyAggregatedMetrics _aggregateWeek(
    List<FacebookWeeklyInsight> weekData,
    List<AdPerformanceWithProduct> ads,
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

    // Get date range from first week in the list
    final dateRange = weekData.isNotEmpty
        ? '${_formatDate(weekData.first.dateStart)} - ${_formatDate(weekData.first.dateStop)}'
        : 'Unknown';

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

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatMonthYear(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Performance Analysis'),
        actions: [
          // Month filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DropdownButton<DateTime>(
              value: _selectedMonth,
              dropdownColor: Colors.blue[700],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: Container(height: 1, color: Colors.white70),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: _availableMonths.map((month) {
                return DropdownMenuItem<DateTime>(
                  value: month,
                  child: Text(_formatMonthYear(month)),
                );
              }).toList(),
              onChanged: _onMonthChanged,
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
                                Icon(Icons.calendar_month, color: Colors.blue[700], size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Viewing: ${_formatMonthYear(_selectedMonth)}',
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
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
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
            'No weekly data for ${_formatMonthYear(_selectedMonth)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different month or ensure ads were running during this period',
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
                  if (_availableMonths.length > 1) {
                    _onMonthChanged(_availableMonths[1]);
                  }
                },
                icon: const Icon(Icons.navigate_before),
                label: const Text('Previous Month'),
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
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
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
      _createComparison('Spend', previous.spend, current.spend, isGoodWhenUp: false),
      _createComparison('Leads', previous.leads.toDouble(), current.leads.toDouble()),
      _createComparison('Profit', previous.profit, current.profit),
      _createComparison('Impressions', previous.impressions.toDouble(), current.impressions.toDouble()),
      _createComparison('Bookings', previous.bookings.toDouble(), current.bookings.toDouble()),
      _createComparison('Deposits', previous.deposits.toDouble(), current.deposits.toDouble()),
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
              itemBuilder: (context, index) => _buildComparisonCard(comparisons[index]),
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
                  comparison.isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
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

