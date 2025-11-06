import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../providers/gohighlevel_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin/add_performance_cost_table.dart';

/// Ads page with 3-level hierarchy (Campaigns, Ad Sets, Ads)
class AdminAdvertsAdsScreen extends StatefulWidget {
  const AdminAdvertsAdsScreen({super.key});

  @override
  State<AdminAdvertsAdsScreen> createState() => _AdminAdvertsAdsScreenState();
}

class _AdminAdvertsAdsScreenState extends State<AdminAdvertsAdsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perfProvider = context.read<PerformanceCostProvider>();
      final ghlProvider = context.read<GoHighLevelProvider>();
      
      if (!perfProvider.isInitialized) {
        perfProvider.initialize().then((_) {
          perfProvider.mergeWithCumulativeData(ghlProvider);
        });
      }
      
      if (!ghlProvider.isInitialized) {
        ghlProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
        builder: (context, perfProvider, ghlProvider, child) {
          if (perfProvider.isLoading || ghlProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (perfProvider.error != null) {
            return _buildErrorState(perfProvider.error!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 32),
                
                // Hierarchy View (3 tabs)
                const AddPerformanceCostTable(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advertisement Hierarchy',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drill down through ad sets and individual ads',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error loading data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

