import 'package:flutter/material.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../models/performance/ad_set_aggregate.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../theme/app_theme.dart';

/// Ad Set-level view grouped by campaign
class AdSetView extends StatefulWidget {
  final List<AdPerformanceWithProduct> ads;
  final PerformanceCostProvider provider;
  final Function(String adSetId)? onAdSetTap;

  const AdSetView({
    super.key,
    required this.ads,
    required this.provider,
    this.onAdSetTap,
  });

  @override
  State<AdSetView> createState() => _AdSetViewState();
}

class _AdSetViewState extends State<AdSetView> {
  String? _expandedAdSetId;
  final Set<String> _expandedCampaigns = {};

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return _buildEmptyState();
    }

    final adSets = widget.provider.getAdSetAggregates(widget.ads);
    
    // Filter to only ad sets with FB spend
    final adSetsWithSpend = adSets.where((adSet) => adSet.totalFbSpend > 0).toList();
    
    if (adSetsWithSpend.isEmpty) {
      return _buildEmptyState();
    }
    
    // Sort by profit
    adSetsWithSpend.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    // Group ad sets by campaign
    final Map<String, List<AdSetAggregate>> groupedAdSets = {};
    for (final adSet in adSetsWithSpend) {
      if (!groupedAdSets.containsKey(adSet.campaignId)) {
        groupedAdSets[adSet.campaignId] = [];
      }
      groupedAdSets[adSet.campaignId]!.add(adSet);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: groupedAdSets.length,
      itemBuilder: (context, index) {
        final campaignId = groupedAdSets.keys.elementAt(index);
        final campaignAdSets = groupedAdSets[campaignId]!;
        final campaignName = campaignAdSets.first.campaignName;
        final isExpanded = _expandedCampaigns.contains(campaignId);
        
        return _buildCampaignGroup(
          campaignId,
          campaignName,
          campaignAdSets,
          isExpanded,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No ad sets available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignGroup(
    String campaignId,
    String campaignName,
    List<AdSetAggregate> adSets,
    bool isExpanded,
  ) {
    // Calculate campaign totals
    double totalSpend = 0;
    int totalAds = 0;
    double totalProfit = 0;
    
    for (final adSet in adSets) {
      totalSpend += adSet.totalFbSpend;
      totalAds += adSet.totalAds;
      totalProfit += adSet.totalProfit;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Campaign header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCampaigns.remove(campaignId);
                } else {
                  _expandedCampaigns.add(campaignId);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaignName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${adSets.length} Ad Sets • $totalAds Ads',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildQuickMetric('Spend', '\$${totalSpend.toStringAsFixed(0)}'),
                  const SizedBox(width: 16),
                  _buildQuickMetric(
                    'Profit',
                    '\$${totalProfit.toStringAsFixed(0)}',
                    color: totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Ad sets list
          if (isExpanded)
            ...adSets.map((adSet) => _buildAdSetCard(adSet)).toList(),
        ],
      ),
    );
  }

  Widget _buildAdSetCard(AdSetAggregate adSet) {
    final isExpanded = _expandedAdSetId == adSet.adSetId;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedAdSetId = isExpanded ? null : adSet.adSetId;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adSet.adSetName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(adSet.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          adSet.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(adSet.status),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${adSet.totalAds} Ads',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Metrics row
                  _buildMetricsRow(adSet),
                ],
              ),
            ),
          ),
          
          // Expanded content (individual ads)
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.ads_click, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Ads in this Ad Set',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...adSet.ads.map((ad) => _buildAdRow(ad)).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow(AdSetAggregate adSet) {
    return Row(
      children: [
        _buildMetric('FB Spend', '\$${adSet.totalFbSpend.toStringAsFixed(0)}', Colors.blue),
        _buildMetric('Leads', adSet.totalLeads.toString(), Colors.purple),
        _buildMetric('Bookings', adSet.totalBookings.toString(), Colors.orange),
        _buildMetric('Deposits', adSet.totalDeposits.toString(), Colors.teal),
        _buildMetric('CPL', '\$${adSet.cpl.toStringAsFixed(2)}', Colors.indigo),
        _buildMetric('CPB', '\$${adSet.cpb.toStringAsFixed(2)}', Colors.pink),
        _buildMetric(
          'Profit',
          '\$${adSet.totalProfit.toStringAsFixed(0)}',
          adSet.isProfitable ? Colors.green : Colors.red,
          bold: true,
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value, Color color, {bool bold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildAdRow(AdPerformanceWithProduct ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.adName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ad ID: ${ad.adId}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildTinyMetric('Spend', '\$${ad.facebookStats.spend.toStringAsFixed(0)}'),
          const SizedBox(width: 12),
          _buildTinyMetric('Leads', ad.ghlStats?.leads.toString() ?? '0'),
          const SizedBox(width: 12),
          _buildTinyMetric('Bookings', ad.ghlStats?.bookings.toString() ?? '0'),
          const SizedBox(width: 12),
          _buildTinyMetric('CPL', '\$${ad.cpl.toStringAsFixed(2)}'),
          const SizedBox(width: 12),
          _buildTinyMetric(
            'Profit',
            '\$${ad.profit.toStringAsFixed(0)}',
            color: ad.profit >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTinyMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Recent':
        return Colors.orange;
      case 'Paused':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

