import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_cost_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import '../../models/performance/ad_performance_cost.dart';
import '../../theme/app_theme.dart';

/// Widget displaying the simplified Add Performance Cost summary
class AddPerformanceSummary extends StatefulWidget {
  const AddPerformanceSummary({super.key});

  @override
  State<AddPerformanceSummary> createState() => _AddPerformanceSummaryState();
}

class _AddPerformanceSummaryState extends State<AddPerformanceSummary> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
      builder: (context, perfProvider, ghlProvider, child) {
        // Merge data
        final mergedData = perfProvider.getMergedData(ghlProvider);
        
        // Sort by profit descending
        final sortedData = List<AdPerformanceCostWithMetrics>.from(mergedData)
          ..sort((a, b) => b.actualProfit.compareTo(a.actualProfit));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.summarize, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Add Performance Cost (Summary)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text('${mergedData.length} Ads'),
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              if (_isExpanded) ...[
                const Divider(height: 1),
                if (mergedData.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.summarize_outlined, 
                            size: 48, 
                            color: Colors.grey[400]
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No performance data to summarize',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey[100],
                      ),
                      columnSpacing: 16,
                      columns: const [
                          DataColumn(
                            label: Text('Ad Name', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('Budget', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('CPL', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                            tooltip: 'Cost Per Lead',
                          ),
                          DataColumn(
                            label: Text('CPB', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                            tooltip: 'Cost Per Booking',
                          ),
                          DataColumn(
                            label: Text('CPA', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                            tooltip: 'Cost Per Acquisition',
                          ),
                          DataColumn(
                            label: Text('Actual Profit', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                          ),
                        ],
                        rows: sortedData.map((data) {
                          final profitColor = data.actualProfit >= 0 
                            ? Colors.green 
                            : Colors.red;
                          
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.adName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      data.campaignName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  'R${data.budget.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCPLColor(data.cpl).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'R${data.cpl.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: _getCPLColor(data.cpl),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCPBColor(data.cpb).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'R${data.cpb.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: _getCPBColor(data.cpb),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCPAColor(data.cpa).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'R${data.cpa.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: _getCPAColor(data.cpa),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: profitColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: profitColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'R${data.actualProfit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: profitColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Color-code CPL based on value (lower is better)
  Color _getCPLColor(double cpl) {
    if (cpl == 0) return Colors.grey;
    if (cpl < 50) return Colors.green;
    if (cpl < 100) return Colors.orange;
    return Colors.red;
  }

  /// Color-code CPB based on value (lower is better)
  Color _getCPBColor(double cpb) {
    if (cpb == 0) return Colors.grey;
    if (cpb < 100) return Colors.green;
    if (cpb < 200) return Colors.orange;
    return Colors.red;
  }

  /// Color-code CPA based on value (lower is better)
  Color _getCPAColor(double cpa) {
    if (cpa == 0) return Colors.grey;
    if (cpa < 300) return Colors.green;
    if (cpa < 500) return Colors.orange;
    return Colors.red;
  }
}

