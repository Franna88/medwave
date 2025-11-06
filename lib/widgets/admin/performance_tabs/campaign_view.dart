import 'package:flutter/material.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../models/performance/campaign_aggregate.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../theme/app_theme.dart';

/// Campaign-level view with expandable campaign cards
class CampaignView extends StatefulWidget {
  final List<AdPerformanceWithProduct> ads;
  final PerformanceCostProvider provider;
  final Function(String campaignId)? onCampaignTap;

  const CampaignView({
    super.key,
    required this.ads,
    required this.provider,
    this.onCampaignTap,
  });

  @override
  State<CampaignView> createState() => _CampaignViewState();
}

class _CampaignViewState extends State<CampaignView> {
  String? _expandedCampaignId;

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return _buildEmptyState();
    }

    final campaigns = widget.provider.getCampaignAggregates(widget.ads);
    
    // Filter to only campaigns with FB spend
    final campaignsWithSpend = campaigns.where((c) => c.totalFbSpend > 0).toList();
    
    if (campaignsWithSpend.isEmpty) {
      return _buildEmptyState();
    }
    
    // Sort by profit by default
    campaignsWithSpend.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: campaignsWithSpend.length,
      itemBuilder: (context, index) {
        final campaign = campaignsWithSpend[index];
        final isExpanded = _expandedCampaignId == campaign.campaignId;
        
        return _buildCampaignCard(campaign, isExpanded);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No campaigns available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(CampaignAggregate campaign, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: campaign.isProfitable
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
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
          // Campaign Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedCampaignId = isExpanded ? null : campaign.campaignId;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: campaign.isProfitable
                    ? Colors.green.withOpacity(0.05)
                    : Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    campaign.campaignName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(campaign.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    campaign.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(campaign.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${campaign.totalAds} Ads • ${campaign.totalAdSets} Ad Sets',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Metrics row
                  _buildMetricsRow(campaign),
                ],
              ),
            ),
          ),
          
          // Expanded content (ad sets)
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildExpandedContent(campaign),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow(CampaignAggregate campaign) {
    return Row(
      children: [
        _buildMetric('FB Spend', '\$${campaign.totalFbSpend.toStringAsFixed(0)}', Colors.blue),
        _buildMetric('Leads', campaign.totalLeads.toString(), Colors.purple),
        _buildMetric('Bookings', campaign.totalBookings.toString(), Colors.orange),
        _buildMetric('Deposits', campaign.totalDeposits.toString(), Colors.teal),
        _buildMetric('Cash', '\$${campaign.totalCashAmount.toStringAsFixed(0)}', Colors.green),
        _buildMetric('CPL', '\$${campaign.cpl.toStringAsFixed(2)}', Colors.indigo),
        _buildMetric('CPB', '\$${campaign.cpb.toStringAsFixed(2)}', Colors.pink),
        _buildMetric(
          'Profit',
          '\$${campaign.totalProfit.toStringAsFixed(0)}',
          campaign.isProfitable ? Colors.green : Colors.red,
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
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(CampaignAggregate campaign) {
    // Get ad sets within this campaign
    final adSets = widget.provider
        .getAdSetAggregates(campaign.ads)
        .where((adSet) => adSet.campaignId == campaign.campaignId)
        .toList();
    
    adSets.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Ad Sets in this Campaign',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (adSets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No ad sets found',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ...adSets.map((adSet) => _buildAdSetRow(adSet)).toList(),
          
          // Show ads without ad set
          if (campaign.ads.any((ad) => ad.adSetId == null || ad.adSetId!.isEmpty)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.ads_click, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Ads without Ad Set',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...campaign.ads
                .where((ad) => ad.adSetId == null || ad.adSetId!.isEmpty)
                .map((ad) => _buildAdRow(ad))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildAdSetRow(adSet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adSet.adSetName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${adSet.totalAds} Ads',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSmallMetric('Spend', '\$${adSet.totalFbSpend.toStringAsFixed(0)}'),
              _buildSmallMetric('Leads', adSet.totalLeads.toString()),
              _buildSmallMetric('Bookings', adSet.totalBookings.toString()),
              _buildSmallMetric('CPL', '\$${adSet.cpl.toStringAsFixed(2)}'),
              _buildSmallMetric(
                'Profit',
                '\$${adSet.totalProfit.toStringAsFixed(0)}',
                color: adSet.isProfitable ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdRow(AdPerformanceWithProduct ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ad.adName,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          _buildTinyMetric('Leads', ad.ghlStats?.leads.toString() ?? '0'),
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

  Widget _buildSmallMetric(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
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
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyMetric(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
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

