import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/comparison/comparison_models.dart';
import 'chart_helpers.dart';

class ComparisonWaterfallChart extends StatefulWidget {
  final List<MetricComparison> metricComparisons;
  final String countryFilter;

  const ComparisonWaterfallChart({
    Key? key,
    required this.metricComparisons,
    this.countryFilter = 'all',
  }) : super(key: key);

  @override
  State<ComparisonWaterfallChart> createState() =>
      _ComparisonWaterfallChartState();
}

class _ComparisonWaterfallChartState extends State<ComparisonWaterfallChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final metrics = ChartMetricData.fromMetricComparisons(
      widget.metricComparisons,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChartTitle(),
        const SizedBox(height: 16),
        SizedBox(
          height: ChartConfig.chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _calculateChartWidth(metrics.length),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: ChartConfig.horizontalPadding,
                      top: ChartConfig.verticalPadding + 30,
                      bottom: ChartConfig.verticalPadding + 30,
                    ),
                    child: BarChart(
                      _buildWaterfallChartData(metrics),
                      swapAnimationDuration: const Duration(milliseconds: 350),
                      swapAnimationCurve: Curves.easeInOut,
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 50,
                        right: ChartConfig.horizontalPadding,
                        top: ChartConfig.verticalPadding,
                        bottom: ChartConfig.verticalPadding + 42,
                      ),
                      child: _buildPercentageLabels(metrics),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPercentageLabels(List<ChartMetricData> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final changes = metrics.map((m) => m.changePercent).toList();
        final minChange = changes.reduce((a, b) => a < b ? a : b);
        final maxChange = changes.reduce((a, b) => a > b ? a : b);
        final absMax = [
          minChange.abs(),
          maxChange.abs(),
        ].reduce((a, b) => a > b ? a : b);
        final yMax = absMax * 1.3;
        final yMin = -yMax;
        final yRange = yMax - yMin;

        final barGroupWidth = constraints.maxWidth / metrics.length;

        return Stack(
          children: metrics.asMap().entries.map((entry) {
            final index = entry.key;
            final metric = entry.value;
            final changePercent = metric.changePercent;

            final xPosition = (index + 0.5) * barGroupWidth;

            final normalizedValue = (changePercent - yMin) / yRange;
            final yPosition = constraints.maxHeight * (1 - normalizedValue);

            final isPositive = changePercent >= 0;
            final offsetY = isPositive ? -25.0 : 25.0;

            return Positioned(
              left: xPosition - 40,
              top: yPosition + offsetY,
              child: Container(
                width: 80,
                alignment: Alignment.center,
                child: Text(
                  MetricFormatter.formatPercentageWithArrow(changePercent),
                  style: TextStyle(
                    fontSize: ChartConfig.percentageLabelFontSize,
                    fontWeight: FontWeight.bold,
                    color: _getBarColor(changePercent),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChartTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.waterfall_chart, size: 16, color: ChartColors.labelText),
        const SizedBox(width: 8),
        Text(
          'Performance Change Impact (%)',
          style: TextStyle(
            fontSize: ChartConfig.titleFontSize,
            color: ChartColors.labelText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  double _calculateChartWidth(int metricCount) {
    const barWidth = 80.0;
    const minWidth = 900.0;
    final calculatedWidth = metricCount * barWidth;
    return calculatedWidth > minWidth ? calculatedWidth : minWidth;
  }

  BarChartData _buildWaterfallChartData(List<ChartMetricData> metrics) {
    final changes = metrics.map((m) => m.changePercent).toList();
    final minChange = changes.reduce((a, b) => a < b ? a : b);
    final maxChange = changes.reduce((a, b) => a > b ? a : b);

    final absMax = [
      minChange.abs(),
      maxChange.abs(),
    ].reduce((a, b) => a > b ? a : b);
    final yMax = absMax * 1.3;
    final yMin = -yMax;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: yMax,
      minY: yMin,
      groupsSpace: 30,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: _buildTooltipData(metrics),
        touchCallback: (FlTouchEvent event, barTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                barTouchResponse == null ||
                barTouchResponse.spot == null) {
              touchedIndex = null;
              return;
            }
            touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) =>
                _buildBottomTitle(value.toInt(), metrics),
            reservedSize: 42,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) => _buildLeftTitle(value),
            reservedSize: 50,
            interval: _calculateInterval(yMax),
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calculateInterval(yMax),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: value == 0 ? Colors.black54 : ChartColors.gridLine,
            strokeWidth: value == 0 ? 1.5 : 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: ChartColors.gridLine, width: 1),
          bottom: BorderSide(color: ChartColors.gridLine, width: 1),
        ),
      ),
      barGroups: _buildWaterfallBars(metrics),
    );
  }

  BarTouchTooltipData _buildTooltipData(List<ChartMetricData> metrics) {
    return BarTouchTooltipData(
      getTooltipColor: (_) => Colors.black87,
      tooltipPadding: const EdgeInsets.all(8),
      tooltipMargin: 8,
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        if (groupIndex >= metrics.length) return null;

        final metric = metrics[groupIndex];

        return BarTooltipItem(
          '${metric.label}\n',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: ChartConfig.tooltipFontSize,
          ),
          children: [
            TextSpan(
              text:
                  '${MetricFormatter.formatMetricValue(metric.label, metric.previousValue, widget.countryFilter)} → '
                  '${MetricFormatter.formatMetricValue(metric.label, metric.currentValue, widget.countryFilter)}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  List<BarChartGroupData> _buildWaterfallBars(List<ChartMetricData> metrics) {
    return List.generate(metrics.length, (index) {
      final metric = metrics[index];
      final changePercent = metric.changePercent;
      final isTouched = index == touchedIndex;
      final barWidth = isTouched
          ? ChartConfig.barWidth + 6
          : ChartConfig.barWidth + 2;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: changePercent,
            color: _getBarColor(changePercent),
            width: barWidth,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  Color _getBarColor(double changePercent) {
    if (changePercent.abs() < 0.1) {
      return ChartColors.neutralChange;
    }
    return changePercent >= 0
        ? ChartColors.positiveChange
        : ChartColors.negativeChange;
  }

  Widget _buildBottomTitle(int index, List<ChartMetricData> metrics) {
    if (index < 0 || index >= metrics.length) {
      return const SizedBox.shrink();
    }

    final metric = metrics[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        metric.label,
        style: TextStyle(
          color: ChartColors.labelText,
          fontSize: ChartConfig.labelFontSize,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLeftTitle(double value) {
    return Text(
      '${value.toStringAsFixed(0)}%',
      style: TextStyle(
        color: ChartColors.labelText,
        fontSize: ChartConfig.labelFontSize,
      ),
      textAlign: TextAlign.right,
    );
  }

  double _calculateInterval(double maxValue) {
    if (maxValue <= 10) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    if (maxValue <= 200) return 50;
    return 100;
  }
}
