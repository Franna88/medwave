import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_cost_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import '../../models/performance/ad_performance_cost.dart';
import '../../theme/app_theme.dart';

/// Widget displaying the detailed Add Performance Cost table
class AddPerformanceCostTable extends StatefulWidget {
  const AddPerformanceCostTable({super.key});

  @override
  State<AddPerformanceCostTable> createState() => _AddPerformanceCostTableState();
}

class _AddPerformanceCostTableState extends State<AddPerformanceCostTable> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
      builder: (context, perfProvider, ghlProvider, child) {
        // Merge data
        final mergedData = perfProvider.getMergedData(ghlProvider);

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
                      Icon(Icons.analytics, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Add Performance Cost (Detailed View)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text('${ghlProvider.pipelineCampaigns.fold<int>(0, (sum, c) => sum + ((c['adsList'] as List?)?.length ?? 0))} Ads Available'),
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
                // Always show available campaigns/ads
                if (ghlProvider.pipelineCampaigns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.analytics_outlined, 
                            size: 48, 
                            color: Colors.grey[400]
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No campaign data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Switch to Cumulative mode and sync data to see campaigns',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildCampaignAdsList(context, perfProvider, ghlProvider, mergedData),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build list of all campaigns/ads with "Add Budget" buttons
  Widget _buildCampaignAdsList(
    BuildContext context,
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
    List<AdPerformanceCostWithMetrics> mergedData,
  ) {
    // Create a map of existing budget entries for quick lookup
    final Map<String, AdPerformanceCost> existingBudgets = {
      for (var cost in perfProvider.adCosts)
        '${cost.campaignName}|${cost.adId}': cost
    };

    // Build list of all ads from cumulative data
    final List<Map<String, dynamic>> allAds = [];
    for (final campaign in ghlProvider.pipelineCampaigns) {
      final campaignName = campaign['campaignName'] ?? '';
      final campaignKey = campaign['campaignKey'] ?? '';
      final adsList = campaign['adsList'] as List<dynamic>? ?? [];
      
      for (final ad in adsList) {
        final adId = ad['adId'] ?? '';
        final adName = ad['adName'] ?? adId;
        final key = '$campaignName|$adId';
        
        allAds.add({
          'campaignName': campaignName,
          'campaignKey': campaignKey,
          'adId': adId,
          'adName': adName,
          'leads': ad['totalOpportunities'] ?? 0,
          'bookings': ad['bookedAppointments'] ?? 0,
          'deposits': ad['deposits'] ?? 0,
          'cashAmount': (ad['totalMonetaryValue'] ?? 0).toDouble(),
          'hasBudget': existingBudgets.containsKey(key),
          'budgetEntry': existingBudgets[key],
        });
      }
    }

    // Sort by leads descending
    allAds.sort((a, b) => (b['leads'] as int).compareTo(a['leads'] as int));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DataTable(
            headingRowColor: MaterialStateProperty.all(
              Colors.grey[100],
            ),
            columnSpacing: 16,
            horizontalMargin: 0,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columns: const [
            DataColumn(
              label: Text('Campaign / Ad', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            DataColumn(
              label: Text('Leads', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Book', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
              tooltip: 'Bookings',
            ),
            DataColumn(
              label: Text('Dep', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
              tooltip: 'Deposits',
            ),
            DataColumn(
              label: Text('Budget', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
            ),
            DataColumn(
              label: Text('CPL', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
              tooltip: 'Cost Per Lead',
            ),
            DataColumn(
              label: Text('CPB', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
              tooltip: 'Cost Per Booking',
            ),
            DataColumn(
              label: Text('CPA', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
              tooltip: 'Cost Per Acquisition',
            ),
            DataColumn(
              label: Text('Profit', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Actions', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
          rows: allAds.map((ad) {
            final hasBudget = ad['hasBudget'] as bool;
            final budgetEntry = ad['budgetEntry'] as AdPerformanceCost?;
            
            // Find merged data if budget exists
            AdPerformanceCostWithMetrics? mergedMetrics;
            if (hasBudget && budgetEntry != null) {
              try {
                mergedMetrics = mergedData.firstWhere(
                  (m) => m.cost.id == budgetEntry.id,
                );
              } catch (e) {
                // Not found in merged data
              }
            }

            final leads = ad['leads'] as int;
            final bookings = ad['bookings'] as int;
            final deposits = ad['deposits'] as int;
            
            return DataRow(
              color: MaterialStateProperty.all(
                hasBudget 
                  ? Colors.green.withOpacity(0.05) 
                  : null
              ),
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad['adName'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        ad['campaignName'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                DataCell(Text('$leads', style: const TextStyle(fontSize: 13))),
                DataCell(Text('$bookings', style: const TextStyle(fontSize: 13))),
                DataCell(Text('$deposits', style: const TextStyle(fontSize: 13))),
                DataCell(
                  hasBudget && mergedMetrics != null
                    ? Text('R${mergedMetrics.budget.toStringAsFixed(0)}', 
                        style: const TextStyle(fontSize: 13))
                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                DataCell(
                  hasBudget && mergedMetrics != null
                    ? Text('R${mergedMetrics.cpl.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13))
                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                DataCell(
                  hasBudget && mergedMetrics != null
                    ? Text('R${mergedMetrics.cpb.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13))
                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                DataCell(
                  hasBudget && mergedMetrics != null
                    ? Text('R${mergedMetrics.cpa.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13))
                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                DataCell(
                  hasBudget && mergedMetrics != null
                    ? Text(
                        'R${mergedMetrics.actualProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: mergedMetrics.actualProfit >= 0 
                            ? Colors.green 
                            : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                DataCell(
                  hasBudget && budgetEntry != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () => _showEditBudgetDialog(
                              context,
                              perfProvider,
                              ghlProvider,
                              budgetEntry,
                            ),
                            tooltip: 'Edit',
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () => _confirmDelete(
                              context,
                              perfProvider,
                              budgetEntry,
                            ),
                            tooltip: 'Delete',
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: () => _showAddBudgetDialog(
                          context,
                          perfProvider,
                          ghlProvider,
                          ad,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(60, 28),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('+ Budget'),
                      ),
                ),
              ],
            );
          }).toList(),
        );
        },
      ),
    );
  }


  /// Show simplified dialog to add budget for a specific ad
  void _showAddBudgetDialog(
    BuildContext context,
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
    Map<String, dynamic> ad,
  ) {
    String? selectedProductId;
    final budgetController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) {
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Budget'),
                const SizedBox(height: 8),
                Text(
                  ad['adName'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show performance data
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Data:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Leads: ${ad['leads']}'),
                              Text('Bookings: ${ad['bookings']}'),
                              Text('Deposits: ${ad['deposits']}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Budget input
                    TextFormField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Budget Amount (R)',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                        prefixText: 'R ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter budget amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount < 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Product dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Linked Product (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedProductId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...perfProvider.products.map((product) {
                          return DropdownMenuItem(
                            value: product.id,
                            child: Text('${product.name} (Expense: R${product.expenseCost.toStringAsFixed(0)})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedProductId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await perfProvider.createAdPerformanceCost(
                        campaignName: ad['campaignName'] as String,
                        campaignKey: ad['campaignKey'] as String,
                        adId: ad['adId'] as String,
                        adName: ad['adName'] as String,
                        budget: double.parse(budgetController.text),
                        linkedProductId: selectedProductId,
                      );
                      
                      // Refresh merged data
                      await perfProvider.mergeWithCumulativeData(ghlProvider);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Budget added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Budget'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show dialog to edit existing budget
  void _showEditBudgetDialog(
    BuildContext context,
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
    AdPerformanceCost cost,
  ) {
    String? selectedProductId = cost.linkedProductId;
    final budgetController = TextEditingController(
      text: cost.budget.toStringAsFixed(2)
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) {
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Budget'),
                const SizedBox(height: 8),
                Text(
                  cost.adName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Budget input
                    TextFormField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Budget Amount (R)',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                        prefixText: 'R ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter budget amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount < 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Product dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Linked Product (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedProductId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...perfProvider.products.map((product) {
                          return DropdownMenuItem(
                            value: product.id,
                            child: Text('${product.name} (Expense: R${product.expenseCost.toStringAsFixed(0)})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedProductId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await perfProvider.updateAdPerformanceCost(
                        cost.copyWith(
                          budget: double.parse(budgetController.text),
                          linkedProductId: selectedProductId,
                        ),
                      );
                      
                      // Refresh merged data
                      await perfProvider.mergeWithCumulativeData(ghlProvider);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Budget updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PerformanceCostProvider provider,
    AdPerformanceCost cost,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Ad Cost Entry'),
        content: Text(
          'Are you sure you want to delete the budget entry for "${cost.adName}"? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteAdPerformanceCost(cost.id);
                
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ad cost entry deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

