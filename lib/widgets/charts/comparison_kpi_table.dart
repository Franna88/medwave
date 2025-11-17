import 'package:flutter/material.dart';
import '../../models/comparison/comparison_models.dart';
import '../../utils/currency_formatter.dart';
import 'chart_helpers.dart';

class ComparisonKpiTable extends StatelessWidget {
  final List<MetricComparison> metricComparisons;
  final String countryFilter;

  const ComparisonKpiTable({
    Key? key,
    required this.metricComparisons,
    this.countryFilter = 'all',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeader(context),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildColumnHeaders(),
              const Divider(height: 1),
              ...metricComparisons.asMap().entries.map((entry) {
                final index = entry.key;
                final metric = entry.value;
                return _buildMetricRow(metric, index);
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.table_chart,
          size: 16,
          color: ChartColors.labelText,
        ),
        const SizedBox(width: 8),
        Text(
          'Performance Metrics',
          style: TextStyle(
            fontSize: ChartConfig.titleFontSize,
            color: ChartColors.labelText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Metric',
              style: TextStyle(
                fontSize: ChartConfig.labelFontSize,
                fontWeight: FontWeight.bold,
                color: ChartColors.labelText,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Previous',
              style: TextStyle(
                fontSize: ChartConfig.labelFontSize,
                fontWeight: FontWeight.bold,
                color: ChartColors.labelText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              'Current',
              style: TextStyle(
                fontSize: ChartConfig.labelFontSize,
                fontWeight: FontWeight.bold,
                color: ChartColors.labelText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              'Trend',
              style: TextStyle(
                fontSize: ChartConfig.labelFontSize,
                fontWeight: FontWeight.bold,
                color: ChartColors.labelText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(MetricComparison metric, int index) {
    final isEven = index % 2 == 0;
    final changePercent = metric.changePercent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              metric.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatValue(metric.label, metric.previousValue),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              _formatValue(metric.label, metric.currentValue),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildTrendIndicator(changePercent, metric.isGoodWhenUp),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(double changePercent, bool isGoodWhenUp) {
    if (changePercent.abs() < 0.1) {
      return Container(
        height: 20,
        decoration: BoxDecoration(
          color: ChartColors.neutralChange.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: 12,
            color: ChartColors.neutralChange,
          ),
        ),
      );
    }

    final isPositive = changePercent >= 0;
    final isGoodChange = (isPositive && isGoodWhenUp) || (!isPositive && !isGoodWhenUp);
    final barColor = isGoodChange ? ChartColors.positiveChange : ChartColors.negativeChange;
    
    final normalizedWidth = (changePercent.abs() / 100).clamp(0.0, 1.0);
    final barWidth = normalizedWidth * 0.8 + 0.2;

    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          if (isPositive)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: barWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: barWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(String label, double value) {
    const currencyMetrics = ['Spend', 'Cash', 'Profit', 'CPL', 'CPB'];
    
    if (currencyMetrics.contains(label)) {
      return CurrencyFormatter.formatCurrency(value, countryFilter);
    } else if (label == 'ROI') {
      return '${value.toStringAsFixed(1)}%';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

