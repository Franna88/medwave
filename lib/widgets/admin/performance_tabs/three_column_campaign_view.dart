import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../models/performance/campaign_aggregate.dart';
import '../../../models/performance/ad_set_aggregate.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../theme/app_theme.dart';

/// Three-column view: Campaigns → Ad Sets → Ads
class ThreeColumnCampaignView extends StatefulWidget {
  final List<AdPerformanceWithProduct> ads;
  final PerformanceCostProvider provider;

  const ThreeColumnCampaignView({
    super.key,
    required this.ads,
    required this.provider,
  });

  @override
  State<ThreeColumnCampaignView> createState() => _ThreeColumnCampaignViewState();
}

class _ThreeColumnCampaignViewState extends State<ThreeColumnCampaignView> {
  String? _selectedCampaignId;
  String? _selectedAdSetId;
  List<CampaignAggregate> _campaigns = [];
  List<AdSetAggregate> _adSets = [];
  List<AdPerformanceWithProduct> _ads = [];
  
  // Loading states for split collections
  bool _isLoadingAdSets = false;
  bool _isLoadingAds = false;
  
  // Filter states
  String _campaignFilter = 'profit'; // profit, spend, leads, bookings, deposits, cash
  String _adSetFilter = 'profit';
  String _adsFilter = 'profit';

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  @override
  void didUpdateWidget(ThreeColumnCampaignView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
      // For split collections, reload if provider's filter dates changed
      if (oldWidget.provider.filterStartDate != widget.provider.filterStartDate ||
          oldWidget.provider.filterEndDate != widget.provider.filterEndDate) {
        _loadCampaigns();
      }
    } else {
      // For old schema, reload if ads changed
      if (oldWidget.ads != widget.ads) {
        _loadCampaigns();
      }
    }
  }

  void _loadCampaigns() {
    if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
      // NEW: Load from split collections with client-side filtering
      // Get filtered campaigns based on the provider's date filter
      final filteredCampaigns = widget.provider.getFilteredCampaigns(
        startDate: widget.provider.filterStartDate,
        endDate: widget.provider.filterEndDate,
      );
      
      final campaigns = filteredCampaigns
          .map((c) => widget.provider.campaignToCampaignAggregate(c))
          .where((c) => c.totalFbSpend > 0)
          .toList();
      
      _sortCampaigns(campaigns);
      
      setState(() {
        _campaigns = campaigns;
        _selectedCampaignId = null;
        _selectedAdSetId = null;
        _adSets = [];
        _ads = [];
      });
    } else {
      // OLD: Aggregate from ads in memory
      if (widget.ads.isEmpty) {
        setState(() {
          _campaigns = [];
          _adSets = [];
          _ads = [];
          _selectedCampaignId = null;
          _selectedAdSetId = null;
        });
        return;
      }

      final campaigns = widget.provider.getCampaignAggregates(widget.ads);
      final campaignsWithSpend = campaigns.where((c) => c.totalFbSpend > 0).toList();
      _sortCampaigns(campaignsWithSpend);

      setState(() {
        _campaigns = campaignsWithSpend;
        // Don't auto-select on load - user must click a campaign
        if (_selectedCampaignId != null && 
            !campaignsWithSpend.any((c) => c.campaignId == _selectedCampaignId)) {
          _selectedCampaignId = null;
          _selectedAdSetId = null;
          _adSets = [];
          _ads = [];
        }
      });
    }
  }

  Future<void> _onCampaignSelected(String campaignId) async {
    if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
      // NEW: Load ad sets from Firebase on-demand
      setState(() {
        _selectedCampaignId = campaignId;
        _selectedAdSetId = null;
        _adSets = [];
        _ads = [];
        _isLoadingAdSets = true;
      });
      
      try {
        await widget.provider.loadAdSetsForCampaign(campaignId);
        
        // Apply date filtering to ad sets
        final filteredAdSets = widget.provider.getFilteredAdSets(
          startDate: widget.provider.filterStartDate,
          endDate: widget.provider.filterEndDate,
        );
        
        // Show all ad sets with activity in the date range, even $0 spend
        final adSets = filteredAdSets
            .map((as) => widget.provider.adSetToAdSetAggregate(as))
            .toList();
        
        _sortAdSets(adSets);
        
        setState(() {
          _adSets = adSets;
          _isLoadingAdSets = false;
          
          // Auto-select first ad set
          if (_adSets.isNotEmpty) {
            _selectedAdSetId = _adSets.first.adSetId;
            _onAdSetSelected(_adSets.first.adSetId);
          }
        });
      } catch (e) {
        setState(() {
          _isLoadingAdSets = false;
        });
        if (kDebugMode) {
          print('❌ Error loading ad sets: $e');
        }
      }
    } else {
      // OLD: Get from in-memory aggregates
      setState(() {
        _selectedCampaignId = campaignId;
        _selectedAdSetId = null;
        
        // Load ad sets for selected campaign
        final campaign = _campaigns.firstWhere((c) => c.campaignId == campaignId);
        // Show all ad sets with activity, even $0 spend
        _adSets = widget.provider
            .getAdSetAggregates(campaign.ads)
            .where((adSet) => adSet.campaignId == campaignId)
            .toList();
        _sortAdSets(_adSets);
        
        // Auto-select first ad set
        if (_adSets.isNotEmpty) {
          _selectedAdSetId = _adSets.first.adSetId;
          _loadAdsForAdSet(_adSets.first.adSetId);
        } else {
          _ads = [];
        }
      });
    }
  }

  Future<void> _onAdSetSelected(String adSetId) async {
    if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
      // NEW: Load ads from Firebase on-demand
      setState(() {
        _selectedAdSetId = adSetId;
        _ads = [];
        _isLoadingAds = true;
      });
      
      try {
        // Pass the selected campaign ID to load date-filtered ads
        await widget.provider.loadAdsForAdSet(_selectedCampaignId!, adSetId);
        
        // Apply date filtering to ads
        final filteredAds = widget.provider.getFilteredAds(
          startDate: widget.provider.filterStartDate,
          endDate: widget.provider.filterEndDate,
        );
        
        final ads = filteredAds
            .map((a) => widget.provider.adToAdPerformanceWithProduct(a))
            .toList();
        
        _sortAds(ads);
        
        setState(() {
          _ads = ads;
          _isLoadingAds = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingAds = false;
        });
        if (kDebugMode) {
          print('❌ Error loading ads: $e');
        }
      }
    } else {
      // OLD: Get from in-memory data
      setState(() {
        _selectedAdSetId = adSetId;
        _loadAdsForAdSet(adSetId);
      });
    }
  }

  void _loadAdsForAdSet(String adSetId) {
    final adSet = _adSets.firstWhere((a) => a.adSetId == adSetId);
    _ads = adSet.ads;
    _sortAds(_ads);
  }

  void _sortCampaigns(List<CampaignAggregate> campaigns) {
    switch (_campaignFilter) {
      case 'profit':
        campaigns.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
        break;
      case 'spend':
        campaigns.sort((a, b) => b.totalFbSpend.compareTo(a.totalFbSpend));
        break;
      case 'leads':
        campaigns.sort((a, b) => b.totalLeads.compareTo(a.totalLeads));
        break;
      case 'bookings':
        campaigns.sort((a, b) => b.totalBookings.compareTo(a.totalBookings));
        break;
      case 'deposits':
        campaigns.sort((a, b) => b.totalDeposits.compareTo(a.totalDeposits));
        break;
      case 'cash':
        campaigns.sort((a, b) => b.totalCashAmount.compareTo(a.totalCashAmount));
        break;
    }
  }

  void _sortAdSets(List<AdSetAggregate> adSets) {
    switch (_adSetFilter) {
      case 'profit':
        adSets.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
        break;
      case 'spend':
        adSets.sort((a, b) => b.totalFbSpend.compareTo(a.totalFbSpend));
        break;
      case 'leads':
        adSets.sort((a, b) => b.totalLeads.compareTo(a.totalLeads));
        break;
      case 'bookings':
        adSets.sort((a, b) => b.totalBookings.compareTo(a.totalBookings));
        break;
      case 'deposits':
        adSets.sort((a, b) => b.totalDeposits.compareTo(a.totalDeposits));
        break;
      case 'cash':
        adSets.sort((a, b) => b.totalCashAmount.compareTo(a.totalCashAmount));
        break;
    }
  }

  void _sortAds(List<AdPerformanceWithProduct> ads) {
    switch (_adsFilter) {
      case 'profit':
        ads.sort((a, b) => b.profit.compareTo(a.profit));
        break;
      case 'spend':
        ads.sort((a, b) => b.facebookStats.spend.compareTo(a.facebookStats.spend));
        break;
      case 'leads':
        ads.sort((a, b) => (b.ghlStats?.leads ?? 0).compareTo(a.ghlStats?.leads ?? 0));
        break;
      case 'bookings':
        ads.sort((a, b) => (b.ghlStats?.bookings ?? 0).compareTo(a.ghlStats?.bookings ?? 0));
        break;
      case 'deposits':
        ads.sort((a, b) => (b.ghlStats?.deposits ?? 0).compareTo(a.ghlStats?.deposits ?? 0));
        break;
      case 'cash':
        ads.sort((a, b) => (b.ghlStats?.cashAmount ?? 0).compareTo(a.ghlStats?.cashAmount ?? 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_campaigns.isEmpty) {
      return _buildEmptyState();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Campaigns
        Expanded(
          flex: 35,
          child: _buildCampaignsColumn(),
        ),
        const SizedBox(width: 16),
        
        // Middle Column - Ad Sets
        Expanded(
          flex: 32,
          child: _buildAdSetsColumn(),
        ),
        const SizedBox(width: 16),
        
        // Right Column - Ads
        Expanded(
          flex: 33,
          child: _buildAdsColumn(),
        ),
      ],
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
          const SizedBox(height: 8),
          Text(
            'Campaigns with Facebook spend will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsColumn() {
    // Calculate totals for all campaigns
    final totalSpend = _campaigns.fold<double>(0, (sum, c) => sum + c.totalFbSpend);
    final totalProfit = _campaigns.fold<double>(0, (sum, c) => sum + c.totalProfit);
    
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
          // Column header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Campaigns',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    _buildFilterDropdown(
                      value: _campaignFilter,
                      onChanged: (value) {
                        setState(() {
                          _campaignFilter = value!;
                          _sortCampaigns(_campaigns);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_campaigns.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderMetric('Total Spend', '\$${totalSpend.toStringAsFixed(0)}', Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderMetric('Total Profit', '\$${totalProfit.toStringAsFixed(0)}', 
                          totalProfit >= 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Campaigns list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _campaigns.length,
              itemBuilder: (context, index) {
                final campaign = _campaigns[index];
                final isSelected = _selectedCampaignId == campaign.campaignId;
                return _buildCampaignCard(campaign, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSetsColumn() {
    // Calculate totals for selected campaign's ad sets
    final totalSpend = _adSets.fold<double>(0, (sum, a) => sum + a.totalFbSpend);
    final totalProfit = _adSets.fold<double>(0, (sum, a) => sum + a.totalProfit);
    
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
          // Column header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Ad Sets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    const Spacer(),
                    if (_adSets.isNotEmpty) ...[
                      _buildFilterDropdown(
                        value: _adSetFilter,
                        onChanged: (value) {
                          setState(() {
                            _adSetFilter = value!;
                            _sortAdSets(_adSets);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_adSets.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (_adSets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric('Total Spend', '\$${totalSpend.toStringAsFixed(0)}', Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildHeaderMetric('Total Profit', '\$${totalProfit.toStringAsFixed(0)}', 
                            totalProfit >= 0 ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Ad Sets list
          Expanded(
            child: _selectedCampaignId == null
                ? _buildColumnEmptyState('Select a campaign to view ad sets')
                : _isLoadingAdSets
                    ? _buildLoadingIndicator()
                    : _adSets.isEmpty
                        ? _buildColumnEmptyState('No ad sets found')
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _adSets.length,
                            itemBuilder: (context, index) {
                              final adSet = _adSets[index];
                              final isSelected = _selectedAdSetId == adSet.adSetId;
                              return _buildAdSetCard(adSet, isSelected);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsColumn() {
    // Calculate totals for selected ad set's ads
    final totalSpend = _ads.fold<double>(0, (sum, a) => sum + a.facebookStats.spend);
    final totalProfit = _ads.fold<double>(0, (sum, a) => sum + a.profit);
    
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
          // Column header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.ads_click, size: 20, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Ads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                    const Spacer(),
                    if (_ads.isNotEmpty) ...[
                      _buildFilterDropdown(
                        value: _adsFilter,
                        onChanged: (value) {
                          setState(() {
                            _adsFilter = value!;
                            _sortAds(_ads);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_ads.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (_ads.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric('Total Spend', '\$${totalSpend.toStringAsFixed(0)}', Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildHeaderMetric('Total Profit', '\$${totalProfit.toStringAsFixed(0)}', 
                            totalProfit >= 0 ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Ads list
          Expanded(
            child: _selectedAdSetId == null
                ? _buildColumnEmptyState('Select an ad set to view ads')
                : _isLoadingAds
                    ? _buildLoadingIndicator()
                    : _ads.isEmpty
                        ? _buildColumnEmptyState('No ads found')
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _ads.length,
                            itemBuilder: (context, index) {
                              final ad = _ads[index];
                              return _buildAdCard(ad);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildCampaignCard(CampaignAggregate campaign, bool isSelected) {
    return GestureDetector(
      onTap: () => _onCampaignSelected(campaign.campaignId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : campaign.isProfitable
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campaign name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.campaignName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(campaign.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      campaign.status,
                      style: TextStyle(
                        fontSize: 9,
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
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              // Stats - 8 metrics in 2 rows
              _buildMetricsGrid([
                _MetricData('FB Spend', '\$${campaign.totalFbSpend.toStringAsFixed(0)}', Colors.blue),
                _MetricData('Leads', campaign.totalLeads.toString(), Colors.purple),
                _MetricData('Bookings', campaign.totalBookings.toString(), Colors.orange),
                _MetricData('Deposits', campaign.totalDeposits.toString(), Colors.teal),
              ]),
              const SizedBox(height: 8),
              _buildMetricsGrid([
                _MetricData('Cash', '\$${campaign.totalCashAmount.toStringAsFixed(0)}', Colors.green),
                _MetricData('CPL', '\$${campaign.cpl.toStringAsFixed(2)}', Colors.indigo),
                _MetricData('CPB', '\$${campaign.cpb.toStringAsFixed(2)}', Colors.pink),
                _MetricData('Profit', '\$${campaign.totalProfit.toStringAsFixed(0)}', 
                    campaign.isProfitable ? Colors.green : Colors.red, bold: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdSetCard(AdSetAggregate adSet, bool isSelected) {
    return GestureDetector(
      onTap: () => _onAdSetSelected(adSet.adSetId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.orange.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.orange
                : adSet.isProfitable
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ad Set name
              Row(
                children: [
                  Expanded(
                    child: Text(
                      adSet.adSetName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${adSet.totalAds} Ads',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              // Stats - 8 metrics in 2 rows
              _buildMetricsGrid([
                _MetricData('FB Spend', '\$${adSet.totalFbSpend.toStringAsFixed(0)}', Colors.blue),
                _MetricData('Leads', adSet.totalLeads.toString(), Colors.purple),
                _MetricData('Bookings', adSet.totalBookings.toString(), Colors.orange),
                _MetricData('Deposits', adSet.totalDeposits.toString(), Colors.teal),
              ]),
              const SizedBox(height: 8),
              _buildMetricsGrid([
                _MetricData('Cash', '\$${adSet.totalCashAmount.toStringAsFixed(0)}', Colors.green),
                _MetricData('CPL', '\$${adSet.cpl.toStringAsFixed(2)}', Colors.indigo),
                _MetricData('CPB', '\$${adSet.cpb.toStringAsFixed(2)}', Colors.pink),
                _MetricData('Profit', '\$${adSet.totalProfit.toStringAsFixed(0)}', 
                    adSet.isProfitable ? Colors.green : Colors.red, bold: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdCard(AdPerformanceWithProduct ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ad.profit >= 0
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ad name
            Text(
              ad.adName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Stats - 8 metrics in 2 rows
            _buildMetricsGrid([
              _MetricData('FB Spend', '\$${ad.facebookStats.spend.toStringAsFixed(0)}', Colors.blue),
              _MetricData('Leads', (ad.ghlStats?.leads ?? 0).toString(), Colors.purple),
              _MetricData('Bookings', (ad.ghlStats?.bookings ?? 0).toString(), Colors.orange),
              _MetricData('Deposits', (ad.ghlStats?.deposits ?? 0).toString(), Colors.teal),
            ]),
            const SizedBox(height: 8),
            _buildMetricsGrid([
              _MetricData('Cash', '\$${(ad.ghlStats?.cashAmount ?? 0).toStringAsFixed(0)}', Colors.green),
              _MetricData('CPL', '\$${ad.cpl.toStringAsFixed(2)}', Colors.indigo),
              _MetricData('CPB', '\$${ad.cpb.toStringAsFixed(2)}', Colors.pink),
              _MetricData('Profit', '\$${ad.profit.toStringAsFixed(0)}', 
                  ad.profit >= 0 ? Colors.green : Colors.red, bold: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(List<_MetricData> metrics) {
    return Row(
      children: metrics.map((metric) => Expanded(
        child: _buildMetric(metric.label, metric.value, metric.color, bold: metric.bold),
      )).toList(),
    );
  }

  Widget _buildMetric(String label, String value, Color color, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 11 : 10,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 16),
        style: TextStyle(fontSize: 11, color: Colors.grey[800]),
        items: const [
          DropdownMenuItem(value: 'profit', child: Text('Profit')),
          DropdownMenuItem(value: 'spend', child: Text('Spend')),
          DropdownMenuItem(value: 'leads', child: Text('Leads')),
          DropdownMenuItem(value: 'bookings', child: Text('Bookings')),
          DropdownMenuItem(value: 'deposits', child: Text('Deposits')),
          DropdownMenuItem(value: 'cash', child: Text('Cash')),
        ],
        onChanged: onChanged,
      ),
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

class _MetricData {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  _MetricData(this.label, this.value, this.color, {this.bold = false});
}

