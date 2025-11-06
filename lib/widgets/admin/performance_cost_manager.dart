import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_cost_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import 'product_setup_widget.dart';
import 'add_performance_cost_table.dart';

/// Container component managing the entire Performance Cost section
class PerformanceCostManager extends StatefulWidget {
  const PerformanceCostManager({super.key});

  @override
  State<PerformanceCostManager> createState() => _PerformanceCostManagerState();
}

class _PerformanceCostManagerState extends State<PerformanceCostManager> {
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
            // Performance Hierarchy View (Main Content)
            const AddPerformanceCostTable(),
            const SizedBox(height: 32),
            
            // Product Setup Section (Moved to Bottom)
            const ProductSetupWidget(),
          ],
        );
      },
    );
  }
}

