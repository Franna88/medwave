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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            'Add Performance Cost (Detailed View)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Facebook sync status
                    if (perfProvider.hasFacebookData) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(
                              perfProvider.lastFacebookSync != null
                                  ? 'FB synced ${_getTimeAgo(perfProvider.lastFacebookSync!)}'
                                  : 'FB connected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (perfProvider.isFacebookDataLoading)
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    // Manual refresh button
                    IconButton(
                      onPressed: perfProvider.isFacebookDataLoading 
                          ? null 
                          : () async {
                              await perfProvider.refreshFacebookData();
                              await perfProvider.mergeWithCumulativeData(ghlProvider);
                            },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Facebook data',
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${ghlProvider.pipelineCampaigns.fold<int>(0, (sum, c) => sum + ((c['adsList'] as List?)?.length ?? 0))} Ads Available'),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
              
              // Content
              if (_isExpanded) ...[
                const Divider(height: 1),
                // Show Facebook campaigns available for matching
                if (perfProvider.facebookCampaigns.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.facebook, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Facebook Campaigns Available (${perfProvider.facebookCampaigns.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'To link ads, use the Campaign ID as the "campaignKey" in Firebase:',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        ...perfProvider.facebookCampaigns.take(5).map((campaign) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${campaign.name} (ID: ${campaign.id}) - \$${campaign.spend.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        }).toList(),
                        if (perfProvider.facebookCampaigns.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '... and ${perfProvider.facebookCampaigns.length - 5} more',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                // Show filter status banner
                if (perfProvider.facebookCampaigns.isNotEmpty && ghlProvider.pipelineCampaigns.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing only GHL campaigns that match Facebook campaigns (non-matching campaigns are hidden)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                else if (mergedData.isEmpty && perfProvider.hasFacebookData)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.link_off, 
                            size: 48, 
                            color: Colors.orange[400]
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ads matched with Facebook campaigns',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Update the "campaignKey" field in Firebase to match a Facebook Campaign ID',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'See the blue box above for available Facebook Campaign IDs',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontStyle: FontStyle.italic,
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
    // ONLY include ads that can potentially match with Facebook campaigns
    final List<Map<String, dynamic>> allAds = [];
    
    // Create a helper function to check if a campaign can match Facebook
    bool canMatchFacebook(String campaignName) {
      if (perfProvider.facebookCampaigns.isEmpty) return false;
      
      // Extract campaign prefix for matching
      final parts = campaignName.split(' - ');
      String prefix = campaignName;
      if (parts.length >= 3) {
        final thirdPart = parts[2].split(' ')[0].replaceAll(RegExp(r'\(.*?\)'), '').trim();
        prefix = '${parts[0]} - ${parts[1]} - $thirdPart';
      }
      
      // Check if any Facebook campaign matches this prefix
      for (final fbCampaign in perfProvider.facebookCampaigns) {
        if (fbCampaign.name.contains(prefix) || prefix.contains(fbCampaign.name)) {
          return true;
        }
      }
      
      return false;
    }
    
    for (final campaign in ghlProvider.pipelineCampaigns) {
      final campaignName = campaign['campaignName'] ?? '';
      final campaignKey = campaign['campaignKey'] ?? '';
      
      // Skip campaigns that cannot match with Facebook
      if (!canMatchFacebook(campaignName)) {
        continue;
      }
      
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

    // Calculate total budget for percentage calculations
    final totalBudget = mergedData.fold<double>(
      0,
      (sum, metrics) => sum + metrics.budget,
    );

    // Show message if no ads match Facebook campaigns
    if (allAds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                perfProvider.facebookCampaigns.isEmpty
                    ? 'No Facebook Campaigns Available'
                    : 'No GHL Campaigns Match Facebook',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                perfProvider.facebookCampaigns.isEmpty
                    ? 'Waiting for Facebook Ads data to load...'
                    : 'Only campaigns with matching Facebook ads are shown.\nYour GHL campaigns don\'t match any Facebook campaign names.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (perfProvider.facebookCampaigns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Available Facebook campaigns: ${perfProvider.facebookCampaigns.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: allAds.map((ad) {
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

          return _buildAdCard(
            context,
            ad,
            mergedMetrics,
            totalBudget,
            perfProvider,
            ghlProvider,
          );
        }).toList(),
      ),
    );
  }

  /// Build individual ad card with metrics and percentages
  Widget _buildAdCard(
    BuildContext context,
    Map<String, dynamic> ad,
    AdPerformanceCostWithMetrics? mergedMetrics,
    double totalBudget,
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
  ) {
    final hasBudget = ad['hasBudget'] as bool;
    final budgetEntry = ad['budgetEntry'] as AdPerformanceCost?;
    final leads = ad['leads'] as int;
    final bookings = ad['bookings'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: hasBudget ? Colors.green.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBudget 
            ? Colors.green.withOpacity(0.3) 
            : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with ad name and actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasBudget 
                ? Colors.green.withOpacity(0.05) 
                : Colors.grey.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad['adName'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad['campaignName'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      // Show Campaign Key (Facebook Campaign ID) for matching
                      if ((ad['campaignKey'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.key, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Campaign Key: ${ad['campaignKey']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Show Facebook sync status
                      if (mergedMetrics?.cost.facebookSpend != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.facebook, size: 12, color: Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Live FB Data',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasBudget && budgetEntry != null) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditBudgetDialog(
                      context,
                      perfProvider,
                      ghlProvider,
                      budgetEntry,
                    ),
                    tooltip: 'Edit Budget',
                    color: Colors.blue,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _confirmDelete(
                      context,
                      perfProvider,
                      budgetEntry,
                    ),
                    tooltip: 'Delete Budget',
                    color: Colors.red,
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: () => _showAddBudgetDialog(
                      context,
                      perfProvider,
                      ghlProvider,
                      ad,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Budget'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          
          // Metrics section - All in one row with Facebook data
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // First row: GHL Movement data + FB Spend
                Row(
                  children: [
                    _buildMetricColumn('Leads', leads.toString(), '-'),
                    _buildMetricColumn(
                      'Bookings',
                      bookings.toString(),
                      mergedMetrics != null 
                        ? '${mergedMetrics.bookingRate.toStringAsFixed(1)}%'
                        : '-',
                    ),
                    // FB Spend replaces Deposits
                    _buildMetricColumn(
                      'FB Spend',
                      mergedMetrics?.cost.facebookSpend != null 
                        ? 'R${mergedMetrics!.cost.facebookSpend!.toStringAsFixed(0)}'
                        : (mergedMetrics != null ? 'R${mergedMetrics.budget.toStringAsFixed(0)}' : '-'),
                      mergedMetrics?.cost.facebookSpend != null 
                        ? '${mergedMetrics!.budgetPercentage(totalBudget).toStringAsFixed(1)}%'
                        : '-',
                      valueColor: mergedMetrics?.cost.facebookSpend != null ? Colors.blue[700] : Colors.grey[600],
                    ),
                    _buildMetricColumn(
                      'CPL',
                      mergedMetrics != null 
                        ? 'R${mergedMetrics.cpl.toStringAsFixed(0)}'
                        : '-',
                      mergedMetrics != null 
                        ? '${mergedMetrics.cplPercentage.toStringAsFixed(1)}%'
                        : '-',
                    ),
                    _buildMetricColumn(
                      'CPB',
                      mergedMetrics != null 
                        ? 'R${mergedMetrics.cpb.toStringAsFixed(0)}'
                        : '-',
                      mergedMetrics != null 
                        ? '${mergedMetrics.cpbPercentage.toStringAsFixed(1)}%'
                        : '-',
                    ),
                    _buildMetricColumn(
                      'CPA',
                      mergedMetrics != null 
                        ? 'R${mergedMetrics.cpa.toStringAsFixed(0)}'
                        : '-',
                      mergedMetrics != null 
                        ? '${mergedMetrics.cpaPercentage.toStringAsFixed(1)}%'
                        : '-',
                    ),
                    _buildMetricColumn(
                      'Profit',
                      mergedMetrics != null 
                        ? 'R${mergedMetrics.actualProfit.toStringAsFixed(0)}'
                        : '-',
                      mergedMetrics != null 
                        ? '${mergedMetrics.profitMargin.toStringAsFixed(1)}%'
                        : '-',
                      valueColor: mergedMetrics != null
                        ? (mergedMetrics.actualProfit >= 0 ? Colors.green : Colors.red)
                        : null,
                    ),
                  ],
                ),
                // Second row: Facebook Ad Metrics (if available)
                if (mergedMetrics?.cost.facebookSpend != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.facebook, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Facebook Metrics:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildSmallMetric(
                          'Impressions',
                          mergedMetrics!.cost.impressions?.toString() ?? '-',
                        ),
                        _buildSmallMetric(
                          'Reach',
                          mergedMetrics.cost.reach?.toString() ?? '-',
                        ),
                        _buildSmallMetric(
                          'Clicks',
                          mergedMetrics.cost.clicks?.toString() ?? '-',
                        ),
                        _buildSmallMetric(
                          'CPM',
                          mergedMetrics.cost.cpm != null 
                              ? '\$${mergedMetrics.cost.cpm!.toStringAsFixed(2)}'
                              : '-',
                        ),
                        _buildSmallMetric(
                          'CPC',
                          mergedMetrics.cost.cpc != null 
                              ? '\$${mergedMetrics.cost.cpc!.toStringAsFixed(2)}'
                              : '-',
                        ),
                        _buildSmallMetric(
                          'CTR',
                          mergedMetrics.cost.ctr != null 
                              ? '${mergedMetrics.cost.ctr!.toStringAsFixed(2)}%'
                              : '-',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single metric column with value and percentage
  Widget _buildMetricColumn(
    String label,
    String value,
    String percentage, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
    final facebookCampaignIdController = TextEditingController();
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
                              Text('Campaign Key: ${ad['campaignKey']}', 
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
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
                    const SizedBox(height: 16),
                    
                    // Facebook Campaign ID input
                    TextFormField(
                      controller: facebookCampaignIdController,
                      decoration: InputDecoration(
                        labelText: 'Facebook Campaign ID (Optional)',
                        hintText: 'e.g., 120234497185340335',
                        border: const OutlineInputBorder(),
                        helperText: 'For exact matching with Facebook data',
                        helperMaxLines: 2,
                        suffixIcon: perfProvider.facebookCampaigns.isNotEmpty
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.list, size: 20),
                                tooltip: 'Select from available campaigns',
                                itemBuilder: (context) {
                                  return perfProvider.facebookCampaigns.map((campaign) {
                                    return PopupMenuItem<String>(
                                      value: campaign.id,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            campaign.name,
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'ID: ${campaign.id}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                                onSelected: (value) {
                                  setDialogState(() {
                                    facebookCampaignIdController.text = value;
                                  });
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
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
                        facebookCampaignId: facebookCampaignIdController.text.trim().isNotEmpty
                            ? facebookCampaignIdController.text.trim()
                            : null,
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

  /// Build a small metric display for Facebook data
  Widget _buildSmallMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

