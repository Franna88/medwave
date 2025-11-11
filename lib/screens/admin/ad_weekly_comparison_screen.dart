import 'package:flutter/material.dart';
import '../../models/facebook/facebook_ad_data.dart';
import '../../services/firebase/weekly_insights_service.dart';
import '../../widgets/admin/weekly_performance_chart.dart';

/// Ad Weekly Comparison Screen
/// Displays week-by-week performance analysis with comparison tools
class AdWeeklyComparisonScreen extends StatefulWidget {
  final String adId;
  final String adName;

  const AdWeeklyComparisonScreen({
    Key? key,
    required this.adId,
    required this.adName,
  }) : super(key: key);

  @override
  State<AdWeeklyComparisonScreen> createState() => _AdWeeklyComparisonScreenState();
}

class _AdWeeklyComparisonScreenState extends State<AdWeeklyComparisonScreen> {
  List<FacebookWeeklyInsight> _weeklyData = [];
  bool _isLoading = true;
  String _selectedMetric = 'spend';
  int? _selectedWeek1;
  int? _selectedWeek2;
  String _dateRange = '6months';

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);

    final endDate = DateTime.now();
    DateTime startDate;

    switch (_dateRange) {
      case '4weeks':
        startDate = endDate.subtract(const Duration(days: 28));
        break;
      case '12weeks':
        startDate = endDate.subtract(const Duration(days: 84));
        break;
      case '6months':
      default:
        startDate = endDate.subtract(const Duration(days: 180));
        break;
    }

    final data = await WeeklyInsightsService.fetchWeeklyInsightsForAd(
      widget.adId,
      startDate: startDate,
      endDate: endDate,
    );

    setState(() {
      _weeklyData = data;
      _isLoading = false;
      
      // Auto-select last two weeks for comparison
      if (_weeklyData.length >= 2) {
        _selectedWeek1 = _weeklyData.length - 2;
        _selectedWeek2 = _weeklyData.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Performance Analysis'),
            Text(
              widget.adName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          _buildDateRangeSelector(),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _weeklyData.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricSelector(),
                      const SizedBox(height: 20),
                      WeeklyPerformanceChart(
                        weeklyData: _weeklyData,
                        metric: _selectedMetric,
                        title: 'Performance Timeline',
                        height: 350,
                      ),
                      const SizedBox(height: 30),
                      _buildComparisonSection(),
                      const SizedBox(height: 30),
                      _buildWeeklyDataTable(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateRangeSelector() {
    return PopupMenuButton<String>(
      initialValue: _dateRange,
      onSelected: (value) {
        setState(() => _dateRange = value);
        _loadWeeklyData();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: '4weeks', child: Text('Last 4 Weeks')),
        const PopupMenuItem(value: '12weeks', child: Text('Last 12 Weeks')),
        const PopupMenuItem(value: '6months', child: Text('Last 6 Months')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(_getDateRangeLabel()),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  String _getDateRangeLabel() {
    switch (_dateRange) {
      case '4weeks':
        return 'Last 4 Weeks';
      case '12weeks':
        return 'Last 12 Weeks';
      case '6months':
      default:
        return 'Last 6 Months';
    }
  }

  Widget _buildMetricSelector() {
    final metrics = [
      {'value': 'spend', 'label': 'Spend', 'icon': Icons.attach_money},
      {'value': 'impressions', 'label': 'Impressions', 'icon': Icons.visibility},
      {'value': 'clicks', 'label': 'Clicks', 'icon': Icons.touch_app},
      {'value': 'cpm', 'label': 'CPM', 'icon': Icons.trending_up},
      {'value': 'cpc', 'label': 'CPC', 'icon': Icons.money},
      {'value': 'ctr', 'label': 'CTR', 'icon': Icons.percent},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Metric',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics.map((metric) {
                final isSelected = _selectedMetric == metric['value'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        metric['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(metric['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMetric = metric['value'] as String);
                    }
                  },
                  selectedColor: Colors.blue[700],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonSection() {
    if (_weeklyData.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('Need at least 2 weeks of data for comparison'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Week Comparison',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildWeekSelector(1)),
            const SizedBox(width: 16),
            const Icon(Icons.compare_arrows, size: 32, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(child: _buildWeekSelector(2)),
          ],
        ),
        if (_selectedWeek1 != null && _selectedWeek2 != null) ...[
          const SizedBox(height: 20),
          _buildComparisonCards(),
        ],
      ],
    );
  }

  Widget _buildWeekSelector(int weekNumber) {
    final selectedWeek = weekNumber == 1 ? _selectedWeek1 : _selectedWeek2;

    return Card(
      color: weekNumber == 1 ? Colors.blue[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week $weekNumber',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: weekNumber == 1 ? Colors.blue[900] : Colors.green[900],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: selectedWeek,
              isExpanded: true,
              hint: const Text('Select week'),
              items: _weeklyData.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(
                    '${entry.value.weekLabel} (${entry.value.dateRangeString})',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  if (weekNumber == 1) {
                    _selectedWeek1 = value;
                  } else {
                    _selectedWeek2 = value;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCards() {
    final week1 = _weeklyData[_selectedWeek1!];
    final week2 = _weeklyData[_selectedWeek2!];

    final metrics = [
      {'key': 'spend', 'label': 'Spend', 'format': '\$%.2f'},
      {'key': 'impressions', 'label': 'Impressions', 'format': '%.0f'},
      {'key': 'clicks', 'label': 'Clicks', 'format': '%.0f'},
      {'key': 'cpm', 'label': 'CPM', 'format': '\$%.2f'},
      {'key': 'cpc', 'label': 'CPC', 'format': '\$%.2f'},
      {'key': 'ctr', 'label': 'CTR', 'format': '%.2f%%'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _buildComparisonCard(
          metric['label'] as String,
          metric['key'] as String,
          week1,
          week2,
        );
      },
    );
  }

  Widget _buildComparisonCard(
    String label,
    String metricKey,
    FacebookWeeklyInsight week1,
    FacebookWeeklyInsight week2,
  ) {
    final changePercent = week2.calculateChangePercent(week1, metricKey);
    final isIncrease = changePercent > 0;
    final isDecrease = changePercent < 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (changePercent != 0)
                  Icon(
                    isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isIncrease ? Colors.green : Colors.red,
                    size: 20,
                  ),
                Text(
                  '${changePercent.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: changePercent == 0
                        ? Colors.grey
                        : (isIncrease ? Colors.green : Colors.red),
                  ),
                ),
              ],
            ),
            Text(
              changePercent == 0
                  ? 'No change'
                  : (isIncrease ? 'Increase' : 'Decrease'),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyDataTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Data Table',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Week')),
                  DataColumn(label: Text('Date Range')),
                  DataColumn(label: Text('Spend')),
                  DataColumn(label: Text('Impressions')),
                  DataColumn(label: Text('Clicks')),
                  DataColumn(label: Text('CPM')),
                  DataColumn(label: Text('CPC')),
                  DataColumn(label: Text('CTR')),
                ],
                rows: _weeklyData.map((week) {
                  return DataRow(
                    cells: [
                      DataCell(Text(week.weekLabel)),
                      DataCell(Text(week.dateRangeString)),
                      DataCell(Text('\$${week.spend.toStringAsFixed(2)}')),
                      DataCell(Text(week.impressions.toString())),
                      DataCell(Text(week.clicks.toString())),
                      DataCell(Text('\$${week.cpm.toStringAsFixed(2)}')),
                      DataCell(Text('\$${week.cpc.toStringAsFixed(2)}')),
                      DataCell(Text('${week.ctr.toStringAsFixed(2)}%')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No weekly data available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Run the backfill script to populate historical data',
            style: TextStyle(color: Colors.grey[600]),
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
}

