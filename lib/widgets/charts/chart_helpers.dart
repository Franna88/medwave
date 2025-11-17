import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/comparison/comparison_models.dart';
import '../../utils/currency_formatter.dart';

class ChartColors {
  static const Color previousPeriod = Color(0xFF2196F3);
  static const Color currentPeriod = Color(0xFF4CAF50);
  static const Color previousPeriodNegative = Color(0xFFFF9800);
  static const Color currentPeriodNegative = Color(0xFFFF6F00);
  static const Color positiveChange = Color(0xFF4CAF50);
  static const Color negativeChange = Color(0xFFE53935);
  static const Color neutralChange = Color(0xFF9E9E9E);
  static const Color gridLine = Color(0xFFE0E0E0);
  static const Color labelText = Color(0xFF666666);
}

class ChartConfig {
  static const double barWidth = 24.0;
  static const double chartHeight = 500.0;
  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 24.0;
  static const double labelFontSize = 11.0;
  static const double titleFontSize = 13.0;
  static const double tooltipFontSize = 13.0;
  static const double percentageLabelFontSize = 12.0;
  static const double minBarHeight = 40.0;
}

class MetricFormatter {
  static String formatMetricValue(
    String label,
    double value,
    String countryFilter,
  ) {
    const currencyMetrics = ['Spend', 'Cash', 'Profit', 'CPL', 'CPB'];

    if (currencyMetrics.contains(label)) {
      return CurrencyFormatter.formatCurrency(value, countryFilter);
    } else if (label == 'ROI') {
      return '${value.toStringAsFixed(1)}%';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static String formatPercentageWithArrow(double value) {
    if (value.abs() < 0.1) return '0.0%';
    final arrow = value >= 0 ? '↑' : '↓';
    return '$arrow${value.abs().toStringAsFixed(1)}%';
  }

  static String formatAxisLabel(double value, String label) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class ChartMetricData {
  final String label;
  final double previousValue;
  final double currentValue;
  final double changePercent;
  final bool isGoodWhenUp;

  ChartMetricData({
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.changePercent,
    required this.isGoodWhenUp,
  });

  Color get changeColor {
    if (changePercent.abs() < 0.1) return ChartColors.neutralChange;

    final isPositive = changePercent >= 0;
    final isGoodChange =
        (isPositive && isGoodWhenUp) || (!isPositive && !isGoodWhenUp);

    return isGoodChange
        ? ChartColors.positiveChange
        : ChartColors.negativeChange;
  }

  static List<ChartMetricData> fromMetricComparisons(
    List<MetricComparison> comparisons,
  ) {
    return comparisons
        .map(
          (mc) => ChartMetricData(
            label: mc.label,
            previousValue: mc.previousValue,
            currentValue: mc.currentValue,
            changePercent: mc.changePercent,
            isGoodWhenUp: mc.isGoodWhenUp,
          ),
        )
        .toList();
  }
}

class ChartTouchTooltip {
  static BarTouchTooltipData buildBarTooltip(String countryFilter) {
    return BarTouchTooltipData(
      getTooltipColor: (_) => Colors.black87,
      tooltipPadding: const EdgeInsets.all(8),
      tooltipMargin: 8,
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        final isCurrentPeriod = rodIndex == 1;
        final label = isCurrentPeriod ? 'Current' : 'Previous';
        final value = rod.toY;

        return BarTooltipItem(
          '$label\n',
          const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: ChartConfig.tooltipFontSize,
          ),
          children: [
            TextSpan(
              text: value.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        );
      },
    );
  }
}

double calculateMaxYValue(List<ChartMetricData> metrics) {
  double maxValue = 0;
  for (var metric in metrics) {
    if (metric.previousValue > maxValue) maxValue = metric.previousValue;
    if (metric.currentValue > maxValue) maxValue = metric.currentValue;
  }
  return maxValue * 1.2;
}

double calculateMinYValue(List<ChartMetricData> metrics) {
  double minValue = 0;
  for (var metric in metrics) {
    if (metric.previousValue < minValue) minValue = metric.previousValue;
    if (metric.currentValue < minValue) minValue = metric.currentValue;
  }
  return minValue * 1.2;
}

double calculateYInterval(double maxValue) {
  final absMax = maxValue.abs();
  if (absMax <= 10) return 2;
  if (absMax <= 100) return 20;
  if (absMax <= 1000) return 200;
  if (absMax <= 10000) return 2000;
  return absMax / 5;
}
