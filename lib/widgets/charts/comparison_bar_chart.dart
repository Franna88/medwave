import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/comparison/comparison_models.dart';
import 'chart_helpers.dart';

class ComparisonBarChart extends StatefulWidget {
  final List<MetricComparison> metricComparisons;
  final String countryFilter;

  const ComparisonBarChart({
    Key? key,
    required this.metricComparisons,
    this.countryFilter = 'all',
  }) : super(key: key);

  @override
  State<ComparisonBarChart> createState() => _ComparisonBarChartState();
}

class _ComparisonBarChartState extends State<ComparisonBarChart> {
  int? touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final metrics = ChartMetricData.fromMetricComparisons(
      widget.metricComparisons,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(),
        const SizedBox(height: 16),
        SizedBox(
          height: ChartConfig.chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _calculateChartWidth(metrics.length),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: ChartConfig.horizontalPadding,
                  top: ChartConfig.verticalPadding,
                  bottom: ChartConfig.verticalPadding,
                ),
                child: BarChart(
                  _buildBarChartData(metrics),
                  swapAnimationDuration: const Duration(milliseconds: 350),
                  swapAnimationCurve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem('Previous', ChartColors.previousPeriod),
        _buildLegendItem('Current', ChartColors.currentPeriod),
        _buildLegendItem(
          'Previous (Negative)',
          ChartColors.previousPeriodNegative,
        ),
        _buildLegendItem(
          'Current (Negative)',
          ChartColors.currentPeriodNegative,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: ChartConfig.titleFontSize,
            color: ChartColors.labelText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  double _calculateChartWidth(int metricCount) {
    const barGroupWidth = 100.0;
    const minWidth = 1000.0;
    final calculatedWidth = metricCount * barGroupWidth;
    return calculatedWidth > minWidth ? calculatedWidth : minWidth;
  }

  BarChartData _buildBarChartData(List<ChartMetricData> metrics) {
    final maxY = _getMaxYValue(metrics);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      minY: 0,
      groupsSpace: 40,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: _buildTooltipData(metrics),
        touchCallback: (FlTouchEvent event, barTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                barTouchResponse == null ||
                barTouchResponse.spot == null) {
              touchedGroupIndex = null;
              return;
            }
            touchedGroupIndex = barTouchResponse.spot!.touchedBarGroupIndex;
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
            interval: _getYInterval(metrics),
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _getYInterval(metrics),
        getDrawingHorizontalLine: (value) {
          return FlLine(color: ChartColors.gridLine, strokeWidth: 1);
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: ChartColors.gridLine, width: 1),
          bottom: BorderSide(color: ChartColors.gridLine, width: 1),
        ),
      ),
      barGroups: _buildBarGroups(metrics),
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
        final isCurrentPeriod = rodIndex == 1;
        final label = isCurrentPeriod ? 'Current' : 'Previous';
        final value = isCurrentPeriod
            ? metric.currentValue
            : metric.previousValue;

        return BarTooltipItem(
          '${metric.label}\n',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: ChartConfig.tooltipFontSize,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.normal,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: MetricFormatter.formatMetricValue(
                metric.label,
                value,
                widget.countryFilter,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<ChartMetricData> metrics) {
    return List.generate(metrics.length, (index) {
      final metric = metrics[index];
      final isTouched = index == touchedGroupIndex;

      final previousIsNegative = metric.previousValue < 0;
      final currentIsNegative = metric.currentValue < 0;

      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: metric.previousValue.abs(),
            color: previousIsNegative
                ? ChartColors.previousPeriodNegative
                : ChartColors.previousPeriod,
            width: isTouched ? ChartConfig.barWidth + 4 : ChartConfig.barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          BarChartRodData(
            fromY: 0,
            toY: metric.currentValue.abs(),
            color: currentIsNegative
                ? ChartColors.currentPeriodNegative
                : ChartColors.currentPeriod,
            width: isTouched ? ChartConfig.barWidth + 4 : ChartConfig.barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
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
      MetricFormatter.formatAxisLabel(value, ''),
      style: TextStyle(
        color: ChartColors.labelText,
        fontSize: ChartConfig.labelFontSize,
      ),
      textAlign: TextAlign.right,
    );
  }

  double _getMaxYValue(List<ChartMetricData> metrics) {
    double maxValue = 0;
    for (var metric in metrics) {
      final prevAbs = metric.previousValue.abs();
      final currAbs = metric.currentValue.abs();
      if (prevAbs > maxValue) maxValue = prevAbs;
      if (currAbs > maxValue) maxValue = currAbs;
    }
    return maxValue == 0 ? 10 : maxValue * 1.15;
  }

  double _getYInterval(List<ChartMetricData> metrics) {
    final maxValue = _getMaxYValue(metrics);
    return calculateYInterval(maxValue);
  }
}
