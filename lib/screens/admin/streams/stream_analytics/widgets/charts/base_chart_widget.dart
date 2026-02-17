import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'chart_styling.dart';

mixin BaseChartWidget {
  Widget Function(double, TitleMeta) buildBottomTitles(List<Map<String, dynamic>> data) {
    return (value, meta) {
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
    };
  }
}
