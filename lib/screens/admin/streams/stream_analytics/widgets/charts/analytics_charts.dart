import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medwave_app/theme/app_theme.dart';

import 'chart_styling.dart';
import '../../utils/analytics_helpers.dart';

/// Consolidated file containing all chart widgets for Stream Analytics

class AnalyticsCharts {
  // Opt-Ins Chart
  static Widget buildOptInsChart(List<Map<String, dynamic>> data) {
    const lineColor = AppTheme.primaryColor;
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            minX: -0.5,
            maxX: (data.length - 1).toDouble() + 0.5,
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withOpacity(0.35),
                      lineColor.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Deposits Chart
  static Widget buildDepositsChart(List<Map<String, dynamic>> data) {
    const barColor = AppTheme.successColor;
    final maxVal = data.fold<double>(0, (m, e) => (e['value'] as num) > m ? (e['value'] as num).toDouble() : m);
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (value, meta) => Text(
                    AnalyticsHelpers.formatCurrency(value),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.15,
            barGroups: data.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (e.value['value'] as num).toDouble(),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        barColor.withOpacity(0.85),
                        barColor,
                      ],
                    ),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal * 1.02,
                      color: AppTheme.borderColor.withOpacity(0.15),
                    ),
                  ),
                ],
                showingTooltipIndicators: [],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Sales Chart
  static Widget buildSalesChart(List<Map<String, dynamic>> data) {
    const barColor = AppTheme.successColor;
    final maxVal = data.fold<double>(0, (m, e) => (e['count'] as num) > m ? (e['count'] as num).toDouble() : m);
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxVal * 1.15).clamp(1, double.infinity),
            barGroups: data.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (e.value['count'] as num).toDouble(),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        barColor.withOpacity(0.85),
                        barColor,
                      ],
                    ),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal * 1.02,
                      color: AppTheme.borderColor.withOpacity(0.15),
                    ),
                  ),
                ],
                showingTooltipIndicators: [],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Late Payments Chart
  static Widget buildLatePaymentsChart(List<Map<String, dynamic>> data) {
    const lineColor = AppTheme.errorColor;
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            minX: -0.5,
            maxX: (data.length - 1).toDouble() + 0.5,
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withOpacity(0.3),
                      lineColor.withOpacity(0.06),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Revenue Chart
  static Widget buildRevenueChart(List<Map<String, dynamic>> data) {
    const lineColor = AppTheme.successColor;
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (value, meta) => Text(
                    AnalyticsHelpers.formatCurrency(value),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            minX: -0.5,
            maxX: (data.length - 1).toDouble() + 0.5,
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withOpacity(0.35),
                      lineColor.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Margin Chart
  static Widget buildMarginChart(List<Map<String, dynamic>> data) {
    const lineColor = AppTheme.successColor;
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}%',
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            minX: -0.5,
            maxX: (data.length - 1).toDouble() + 0.5,
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withOpacity(0.35),
                      lineColor.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Stock Levels Chart
  static Widget buildStockLevelsChart(List<Map<String, dynamic>> data) {
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 48,
            sections: data.map((item) {
              final color = item['color'] as Color;
              return PieChartSectionData(
                value: (item['value'] as num).toDouble(),
                title: '${item['value']}',
                titleStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
                color: color,
                radius: 72,
                borderSide: const BorderSide(color: Colors.white, width: 2.5),
                badgePositionPercentageOffset: 1.1,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Forecast Chart
  static Widget buildForecastChart(List<Map<String, dynamic>> data) {
    const currentColor = AppTheme.primaryColor;
    const forecastColor = AppTheme.warningColor;
    return ChartStyling.chartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: ChartStyling.gridData(),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: ChartStyling.axisStyle,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index]['label'],
                          style: ChartStyling.axisStyle,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: ChartStyling.borderData(),
            minX: -0.5,
            maxX: (data.length - 1).toDouble() + 0.5,
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['current'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: currentColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3,
                    color: currentColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      currentColor.withOpacity(0.2),
                      currentColor.withOpacity(0.04),
                    ],
                  ),
                ),
              ),
              LineChartBarData(
                spots: data.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['forecast'] as num).toDouble());
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: forecastColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3,
                    color: forecastColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                dashArray: const [6, 4],
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
