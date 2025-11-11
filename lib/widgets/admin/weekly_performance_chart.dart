import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/facebook/facebook_ad_data.dart';

/// Weekly Performance Chart Widget
/// Displays a line chart showing ad performance metrics over time
class WeeklyPerformanceChart extends StatefulWidget {
  final List<FacebookWeeklyInsight> weeklyData;
  final String metric; // 'spend', 'impressions', 'clicks', 'cpm', 'cpc', 'ctr'
  final String title;
  final Color? lineColor;
  final double? height;

  const WeeklyPerformanceChart({
    Key? key,
    required this.weeklyData,
    this.metric = 'spend',
    this.title = 'Weekly Performance',
    this.lineColor,
    this.height,
  }) : super(key: key);

  @override
  State<WeeklyPerformanceChart> createState() => _WeeklyPerformanceChartState();
}

class _WeeklyPerformanceChartState extends State<WeeklyPerformanceChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.weeklyData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            SizedBox(
              height: widget.height ?? 300,
              child: LineChart(
                _buildLineChartData(),
              ),
            ),
            const SizedBox(height: 10),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildMetricBadge(),
      ],
    );
  }

  Widget _buildMetricBadge() {
    final metricInfo = _getMetricInfo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: metricInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: metricInfo['color'], width: 1),
      ),
      child: Text(
        metricInfo['label'],
        style: TextStyle(
          color: metricInfo['color'],
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    if (_hoveredIndex == null || _hoveredIndex! >= widget.weeklyData.length) {
      return const SizedBox.shrink();
    }

    final week = widget.weeklyData[_hoveredIndex!];
    final metricValue = _getMetricValue(week);
    final metricInfo = _getMetricInfo();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                week.weekLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                week.dateRangeString,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            metricInfo['formatter'](metricValue),
            style: TextStyle(
              color: metricInfo['color'],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      child: Container(
        height: widget.height ?? 300,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No weekly data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Run the backfill script to populate historical data',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final spots = widget.weeklyData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _getMetricValue(entry.value),
      );
    }).toList();

    final metricInfo = _getMetricInfo();
    final lineColor = widget.lineColor ?? metricInfo['color'];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: _calculateInterval(),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[300],
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey[300],
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= widget.weeklyData.length) {
                return const Text('');
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'W${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: _calculateInterval(),
            getTitlesWidget: (value, meta) {
              return Text(
                metricInfo['axisFormatter'](value),
                style: const TextStyle(
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      minX: 0,
      maxX: (widget.weeklyData.length - 1).toDouble(),
      minY: _getMinY(),
      maxY: _getMaxY(),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: _hoveredIndex == index ? 6 : 4,
                color: lineColor,
                strokeWidth: _hoveredIndex == index ? 2 : 1,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: lineColor.withOpacity(0.1),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          setState(() {
            if (response == null || response.lineBarSpots == null) {
              _hoveredIndex = null;
            } else {
              _hoveredIndex = response.lineBarSpots!.first.spotIndex;
            }
          });
        },
        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: (widget.lineColor ?? Colors.blue).withOpacity(0.5),
                strokeWidth: 2,
              ),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: widget.lineColor ?? Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            );
          }).toList();
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => Colors.black87,
          tooltipRoundedRadius: 8,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final week = widget.weeklyData[touchedSpot.spotIndex];
              final metricInfo = _getMetricInfo();
              return LineTooltipItem(
                '${week.weekLabel}\n${metricInfo['formatter'](touchedSpot.y)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  double _getMetricValue(FacebookWeeklyInsight week) {
    switch (widget.metric.toLowerCase()) {
      case 'spend':
        return week.spend;
      case 'impressions':
        return week.impressions.toDouble();
      case 'reach':
        return week.reach.toDouble();
      case 'clicks':
        return week.clicks.toDouble();
      case 'cpm':
        return week.cpm;
      case 'cpc':
        return week.cpc;
      case 'ctr':
        return week.ctr;
      default:
        return week.spend;
    }
  }

  Map<String, dynamic> _getMetricInfo() {
    switch (widget.metric.toLowerCase()) {
      case 'spend':
        return {
          'label': 'Spend',
          'color': Colors.blue[700]!,
          'formatter': (double value) => '\$${value.toStringAsFixed(2)}',
          'axisFormatter': (double value) => '\$${value.toStringAsFixed(0)}',
        };
      case 'impressions':
        return {
          'label': 'Impressions',
          'color': Colors.purple[700]!,
          'formatter': (double value) => value.toStringAsFixed(0),
          'axisFormatter': (double value) => _formatLargeNumber(value),
        };
      case 'reach':
        return {
          'label': 'Reach',
          'color': Colors.orange[700]!,
          'formatter': (double value) => value.toStringAsFixed(0),
          'axisFormatter': (double value) => _formatLargeNumber(value),
        };
      case 'clicks':
        return {
          'label': 'Clicks',
          'color': Colors.green[700]!,
          'formatter': (double value) => value.toStringAsFixed(0),
          'axisFormatter': (double value) => _formatLargeNumber(value),
        };
      case 'cpm':
        return {
          'label': 'CPM',
          'color': Colors.teal[700]!,
          'formatter': (double value) => '\$${value.toStringAsFixed(2)}',
          'axisFormatter': (double value) => '\$${value.toStringAsFixed(0)}',
        };
      case 'cpc':
        return {
          'label': 'CPC',
          'color': Colors.indigo[700]!,
          'formatter': (double value) => '\$${value.toStringAsFixed(2)}',
          'axisFormatter': (double value) => '\$${value.toStringAsFixed(2)}',
        };
      case 'ctr':
        return {
          'label': 'CTR',
          'color': Colors.pink[700]!,
          'formatter': (double value) => '${value.toStringAsFixed(2)}%',
          'axisFormatter': (double value) => '${value.toStringAsFixed(1)}%',
        };
      default:
        return {
          'label': 'Spend',
          'color': Colors.blue[700]!,
          'formatter': (double value) => '\$${value.toStringAsFixed(2)}',
          'axisFormatter': (double value) => '\$${value.toStringAsFixed(0)}',
        };
    }
  }

  String _formatLargeNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  double _getMinY() {
    if (widget.weeklyData.isEmpty) return 0;
    final values = widget.weeklyData.map(_getMetricValue).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    return (min * 0.9).floorToDouble();
  }

  double _getMaxY() {
    if (widget.weeklyData.isEmpty) return 100;
    final values = widget.weeklyData.map(_getMetricValue).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    return (max * 1.1).ceilToDouble();
  }

  double _calculateInterval() {
    final range = _getMaxY() - _getMinY();
    if (range <= 0) return 1;
    
    final targetIntervals = 5;
    final rawInterval = range / targetIntervals;
    
    // Round to nice numbers
    final magnitude = (rawInterval).floor().toString().length - 1;
    final power = 10.0;
    final base = power;
    
    return (rawInterval / base).ceilToDouble() * base;
  }
}

