import 'package:flutter/material.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../providers/gohighlevel_provider.dart';

/// Individual ads view with filters
class AdsView extends StatefulWidget {
  final List<AdPerformanceWithProduct> ads;
  final PerformanceCostProvider perfProvider;
  final GoHighLevelProvider ghlProvider;
  final String sortBy;
  final String filterBy;

  const AdsView({
    super.key,
    required this.ads,
    required this.perfProvider,
    required this.ghlProvider,
    required this.sortBy,
    required this.filterBy,
  });

  @override
  State<AdsView> createState() => _AdsViewState();
}

class _AdsViewState extends State<AdsView> {
  String? _selectedCampaignId;
  String? _selectedAdSetId;

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return _buildEmptyState();
    }

    // Get unique campaigns and ad sets for filters
    final campaigns = widget.perfProvider.getCampaignAggregates(widget.ads);
    final adSets = widget.perfProvider.getAdSetAggregates(widget.ads);

    // Apply campaign/ad set filters
    var filteredAds = widget.ads;
    if (_selectedCampaignId != null) {
      filteredAds = filteredAds
          .where((ad) => ad.campaignId == _selectedCampaignId)
          .toList();
    }
    if (_selectedAdSetId != null) {
      filteredAds = filteredAds
          .where((ad) => ad.adSetId == _selectedAdSetId)
          .toList();
    }

    // Apply additional filters
    filteredAds = _applyFilters(filteredAds);
    
    // Apply sorting
    _applySorting(filteredAds);

    return Column(
      children: [
        // Filter dropdowns
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.withOpacity(0.05),
          child: Row(
            children: [
              // Campaign filter
              Expanded(
                child: _buildFilterDropdown(
                  'Filter by Campaign',
                  _selectedCampaignId,
                  campaigns.map((c) => {'id': c.campaignId, 'name': c.campaignName}).toList(),
                  (value) {
                    setState(() {
                      _selectedCampaignId = value;
                      // Reset ad set filter when campaign changes
                      if (_selectedAdSetId != null) {
                        final adSetCampaign = widget.ads
                            .firstWhere(
                              (ad) => ad.adSetId == _selectedAdSetId,
                              orElse: () => widget.ads.first,
                            )
                            .campaignId;
                        if (adSetCampaign != value) {
                          _selectedAdSetId = null;
                        }
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Ad Set filter
              Expanded(
                child: _buildFilterDropdown(
                  'Filter by Ad Set',
                  _selectedAdSetId,
                  adSets
                      .where((as) =>
                          _selectedCampaignId == null ||
                          as.campaignId == _selectedCampaignId)
                      .map((as) => {'id': as.adSetId, 'name': as.adSetName})
                      .toList(),
                  (value) {
                    setState(() => _selectedAdSetId = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Clear filters button
              if (_selectedCampaignId != null || _selectedAdSetId != null)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCampaignId = null;
                      _selectedAdSetId = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Ads list
        Expanded(
          child: filteredAds.isEmpty
              ? _buildNoResultsState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredAds.length,
                  itemBuilder: (context, index) {
                    final ad = filteredAds[index];
                    return _buildAdCard(ad);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No ads available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No ads match the selected filters',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String hint,
    String? value,
    List<Map<String, String>> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontSize: 13)),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('All ${hint.split(' ').last}'),
          ),
          ...items.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'],
              child: Text(
                item['name'] ?? 'Unknown',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAdCard(AdPerformanceWithProduct ad) {
    final leads = ad.ghlStats?.leads ?? 0;
    final bookings = ad.ghlStats?.bookings ?? 0;
    final deposits = ad.ghlStats?.deposits ?? 0;
    final cashCollected = ad.ghlStats?.cashCollected ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ad.profit >= 0
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
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
          // Header with ad name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ad.profit >= 0
                  ? Colors.green.withOpacity(0.05)
                  : Colors.red.withOpacity(0.05),
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
                        ad.adName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.campaignName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (ad.adSetName != null && ad.adSetName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ad Set: ${ad.adSetName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                      // Show ad run date range from Facebook
                      if (ad.facebookStats.dateStart.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateRange(
                                ad.facebookStats.dateStart,
                                ad.facebookStats.dateStop,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.facebook, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'FB Managed',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          
          // Metrics section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // First row: FB Spend, funnel metrics, calculated metrics
                Row(
                  children: [
                    _buildMetricColumn(
                      'FB Spend',
                      ad.facebookStats.spend > 0
                          ? '\$${ad.facebookStats.spend.toStringAsFixed(0)}'
                          : '-',
                      '-',
                      valueColor: ad.facebookStats.spend > 0 ? Colors.blue[700] : Colors.grey[600],
                    ),
                    _buildMetricColumn('Leads', leads.toString(), '-'),
                    _buildMetricColumn(
                      'Bookings',
                      bookings.toString(),
                      ad.ghlStats != null && ad.ghlStats!.leads > 0
                          ? '${((ad.ghlStats!.bookings / ad.ghlStats!.leads) * 100).toStringAsFixed(1)}%'
                          : '-',
                    ),
                    _buildMetricColumn(
                      'Deposits',
                      deposits.toString(),
                      ad.ghlStats != null && ad.ghlStats!.bookings > 0
                          ? '${((ad.ghlStats!.deposits / ad.ghlStats!.bookings) * 100).toStringAsFixed(1)}%'
                          : '-',
                      valueColor: deposits > 0 ? Colors.purple[700] : Colors.grey[600],
                    ),
                    _buildMetricColumn(
                      'Cash',
                      cashCollected.toString(),
                      ad.ghlStats != null && ad.ghlStats!.deposits > 0
                          ? '${((ad.ghlStats!.cashCollected / ad.ghlStats!.deposits) * 100).toStringAsFixed(1)}%'
                          : '-',
                      valueColor: cashCollected > 0 ? Colors.teal[700] : Colors.grey[600],
                    ),
                    _buildMetricColumn(
                      'CPL',
                      ad.cpl > 0 ? '\$${ad.cpl.toStringAsFixed(0)}' : '-',
                      '-',
                    ),
                    _buildMetricColumn(
                      'CPB',
                      ad.cpb > 0 ? '\$${ad.cpb.toStringAsFixed(0)}' : '-',
                      '-',
                    ),
                    _buildMetricColumn(
                      'CPA',
                      ad.cpa > 0 ? '\$${ad.cpa.toStringAsFixed(0)}' : '-',
                      '-',
                    ),
                    _buildMetricColumn(
                      'Profit',
                      '\$${ad.profit.toStringAsFixed(0)}',
                      '-',
                      valueColor: ad.profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                
                // Second row: Facebook Ad Metrics (if available)
                if (ad.facebookStats.spend > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                              'Facebook Metrics:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildMetricColumn(
                              'Impressions',
                              ad.facebookStats.impressions.toString(),
                              '-',
                              valueColor: Colors.blue[700],
                            ),
                            _buildMetricColumn(
                              'Clicks',
                              ad.facebookStats.clicks.toString(),
                              '-',
                              valueColor: Colors.blue[700],
                            ),
                            _buildMetricColumn(
                              'CPM',
                              ad.facebookStats.cpm > 0
                                  ? '\$${ad.facebookStats.cpm.toStringAsFixed(2)}'
                                  : '-',
                              '-',
                              valueColor: Colors.blue[700],
                            ),
                            _buildMetricColumn(
                              'CPC',
                              ad.facebookStats.cpc > 0
                                  ? '\$${ad.facebookStats.cpc.toStringAsFixed(2)}'
                                  : '-',
                              '-',
                              valueColor: Colors.blue[700],
                            ),
                            _buildMetricColumn(
                              'CTR',
                              ad.facebookStats.ctr > 0
                                  ? '${ad.facebookStats.ctr.toStringAsFixed(2)}%'
                                  : '-',
                              '-',
                              valueColor: Colors.blue[700],
                            ),
                          ],
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

  Widget _buildMetricColumn(
    String label,
    String value,
    String percentage, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
          if (percentage != '-') ...[
            const SizedBox(height: 2),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateRange(String dateStart, String dateStop) {
    try {
      final start = DateTime.parse(dateStart);
      final stop = DateTime.parse(dateStop);
      final now = DateTime.now();
      
      final startStr = '${_getMonthAbbr(start.month)} ${start.day}';
      final isLive = stop.isAfter(now) || stop.isAtSameMomentAs(DateTime(now.year, now.month, now.day));
      
      if (isLive) {
        return '$startStr - Current Live';
      } else {
        final stopStr = '${_getMonthAbbr(stop.month)} ${stop.day}';
        return '$startStr - $stopStr';
      }
    } catch (e) {
      return 'Date unavailable';
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  List<AdPerformanceWithProduct> _applyFilters(List<AdPerformanceWithProduct> ads) {
    // Always filter to only ads with FB spend > 0
    var filtered = ads.where((ad) => ad.facebookStats.spend > 0).toList();
    
    if (widget.filterBy == 'all') {
      return filtered;
    }

    return filtered.where((ad) {
      final profit = ad.profit;

      switch (widget.filterBy) {
        case 'hasSpend':
          // Redundant since we already filter for spend > 0, but kept for compatibility
          return true;
        case 'noSpend':
          // This will return empty since we already filter for spend > 0
          // Kept for compatibility but effectively shows nothing
          return false;
        case 'profitable':
          return profit > 0;
        case 'unprofitable':
          return profit < 0;
        default:
          return true;
      }
    }).toList();
  }

  void _applySorting(List<AdPerformanceWithProduct> ads) {
    switch (widget.sortBy) {
      case 'leads':
        ads.sort((a, b) => (b.ghlStats?.leads ?? 0).compareTo(a.ghlStats?.leads ?? 0));
        break;
      case 'bookings':
        ads.sort((a, b) => (b.ghlStats?.bookings ?? 0).compareTo(a.ghlStats?.bookings ?? 0));
        break;
      case 'fbSpend':
        ads.sort((a, b) => b.facebookStats.spend.compareTo(a.facebookStats.spend));
        break;
      case 'cpl':
        ads.sort((a, b) => a.cpl.compareTo(b.cpl)); // Low to high
        break;
      case 'cpb':
        ads.sort((a, b) => a.cpb.compareTo(b.cpb)); // Low to high
        break;
      case 'profit':
        ads.sort((a, b) => b.profit.compareTo(a.profit)); // High to low
        break;
    }
  }
}

