import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_cost_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import 'product_setup_widget.dart';
import 'add_performance_cost_table.dart';
import 'add_performance_summary.dart';

/// Container component managing the entire Performance Cost section
class PerformanceCostManager extends StatefulWidget {
  const PerformanceCostManager({super.key});

  @override
  State<PerformanceCostManager> createState() => _PerformanceCostManagerState();
}

class _PerformanceCostManagerState extends State<PerformanceCostManager> {
  String _viewMode = 'detailed'; // 'detailed' or 'summary'

  @override
  void initState() {
    super.initState();
    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perfProvider = context.read<PerformanceCostProvider>();
      final ghlProvider = context.read<GoHighLevelProvider>();
      
      if (!perfProvider.isInitialized) {
        perfProvider.initialize().then((_) {
          // Merge data after initialization
          perfProvider.mergeWithCumulativeData(ghlProvider);
        });
      } else {
        // Just merge data if already initialized
        perfProvider.mergeWithCumulativeData(ghlProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
      builder: (context, perfProvider, ghlProvider, child) {
        // Show loading state
        if (perfProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(40),
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
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading performance cost data...'),
                ],
              ),
            ),
          );
        }

        // Show error state
        if (perfProvider.error != null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Error loading performance cost data',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        perfProvider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => perfProvider.refreshData(),
                  tooltip: 'Retry',
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Setup Section
            const ProductSetupWidget(),
            const SizedBox(height: 24),
            
            // View Mode Toggle
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  const Text(
                    'Performance View:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'detailed',
                        label: Text('Detailed'),
                        icon: Icon(Icons.table_chart, size: 18),
                      ),
                      ButtonSegment(
                        value: 'summary',
                        label: Text('Summary'),
                        icon: Icon(Icons.summarize, size: 18),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _viewMode = newSelection.first;
                      });
                    },
                  ),
                  const Spacer(),
                  
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await perfProvider.refreshData();
                      if (context.mounted) {
                        await perfProvider.mergeWithCumulativeData(ghlProvider);
                      }
                    },
                    tooltip: 'Refresh Data',
                  ),
                  
                  // Info button
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showInfoDialog(context),
                    tooltip: 'About Performance Costs',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Performance Table (Detailed or Summary based on toggle)
            if (_viewMode == 'detailed')
              const AddPerformanceCostTable()
            else
              const AddPerformanceSummary(),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 12),
            Text('About Add Performance Cost'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This section helps you track the profitability of your ad campaigns by combining budget data with performance metrics.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'How it works:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildStep('1', 'Set up products with their deposit amounts and expense costs'),
                _buildStep('2', 'Add budget entries for your ad campaigns'),
                _buildStep('3', 'The system automatically merges your budget data with cumulative campaign performance'),
                _buildStep('4', 'View calculated metrics like CPL, CPB, CPA, and actual profit'),
                
                const SizedBox(height: 16),
                const Text(
                  'Key Metrics:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildMetric('CPL', 'Cost Per Lead', 'Budget ÷ Leads'),
                _buildMetric('CPB', 'Cost Per Booking', 'Budget ÷ Bookings'),
                _buildMetric('CPA', 'Cost Per Acquisition', 'Budget ÷ Deposits'),
                _buildMetric('Profit', 'Actual Profit', 'Cash Deposits - (Budget + Product Expense)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String abbr, String name, String formula) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              abbr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  formula,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

