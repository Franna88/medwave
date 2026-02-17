import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medwave_app/theme/app_theme.dart';


class ChartStyling {
  static const TextStyle axisStyle = TextStyle(
    fontSize: 11,
    color: AppTheme.secondaryColor,
    fontWeight: FontWeight.w500,
  );

  static Widget chartCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }

  static FlGridData gridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => FlLine(
        color: AppTheme.borderColor.withOpacity(0.4),
        strokeWidth: 1,
      ),
      drawHorizontalLine: true,
    );
  }

  static FlBorderData borderData() {
    return FlBorderData(
      show: true,
      border: Border(
        left: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
        bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
    );
  }
}
