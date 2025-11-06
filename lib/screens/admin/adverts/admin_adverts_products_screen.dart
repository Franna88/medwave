import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin/product_setup_widget.dart';

/// Products page for managing product configurations
class AdminAdvertsProductsScreen extends StatefulWidget {
  const AdminAdvertsProductsScreen({super.key});

  @override
  State<AdminAdvertsProductsScreen> createState() => _AdminAdvertsProductsScreenState();
}

class _AdminAdvertsProductsScreenState extends State<AdminAdvertsProductsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perfProvider = context.read<PerformanceCostProvider>();
      
      if (!perfProvider.isInitialized) {
        perfProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<PerformanceCostProvider>(
        builder: (context, perfProvider, child) {
          if (perfProvider.isLoading) {
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
                _buildHeader(perfProvider),
                const SizedBox(height: 32),
                
                // Product Setup Widget
                const ProductSetupWidget(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(PerformanceCostProvider perfProvider) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Setup',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure products with deposit amounts and expense costs for profit calculations',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Chip(
          label: Text('${perfProvider.products.length} Products'),
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
              'Error loading products',
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

