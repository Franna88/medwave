import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/performance/ad_performance_data.dart';
import '../../providers/performance_cost_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import '../../theme/app_theme.dart';
import 'performance_tabs/ad_set_view.dart';
import 'performance_tabs/ads_view.dart';

/// Widget displaying the Add Performance Cost with 2-level hierarchy tabs
class AddPerformanceCostTable extends StatefulWidget {
  const AddPerformanceCostTable({super.key});

  @override
  State<AddPerformanceCostTable> createState() => _AddPerformanceCostTableState();
}

class _AddPerformanceCostTableState extends State<AddPerformanceCostTable>
    with SingleTickerProviderStateMixin {
  String _dateFilter = 'all'; // 'all', 'today', 'yesterday', 'last7days', 'last30days'
  String _sortBy = 'leads'; // 'leads', 'bookings', 'fbSpend', 'cpl', 'cpb', 'profit'
  String _filterBy = 'all'; // 'all', 'hasSpend', 'noSpend', 'profitable', 'unprofitable'
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
      builder: (context, perfProvider, ghlProvider, child) {
        // Merge data
        final allAds = perfProvider.getMergedData(ghlProvider);
        
        // Filter out ads with no FB spend
        final adsWithSpend = allAds.where((ad) {
          return ad.facebookStats.spend > 0;
        }).toList();
        
        // Apply date filter
        final filteredAds = _filterAdsByDate(adsWithSpend);

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
              // Compact Filter & Sort Row (moved to top)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.03),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                          Text(
                      'Filter & Sort (applies to Ads tab):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Date Filter dropdown - compact
                            Text(
                      'Date:',
                              style: TextStyle(
                                fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                      ),
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      child: DropdownButton<String>(
                        value: _dateFilter,
                        underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                        items: const [
                          DropdownMenuItem(value: 'today', child: Text('📅 Today')),
                          DropdownMenuItem(value: 'yesterday', child: Text('📅 Yesterday')),
                          DropdownMenuItem(value: 'last7days', child: Text('📅 Last 7 Days')),
                          DropdownMenuItem(value: 'last30days', child: Text('📅 Last 30 Days')),
                          DropdownMenuItem(value: 'all', child: Text('📅 All Time')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _dateFilter = value);
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Sort By dropdown - compact
                    Text(
                      'Sort By:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                                  ),
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                    items: const [
                                      DropdownMenuItem(value: 'leads', child: Text('📊 Leads (High → Low)')),
                                      DropdownMenuItem(value: 'bookings', child: Text('📅 Bookings (High → Low)')),
                                      DropdownMenuItem(value: 'fbSpend', child: Text('💰 FB Spend (High → Low)')),
                                      DropdownMenuItem(value: 'cpl', child: Text('📉 CPL (Low → High)')),
                                      DropdownMenuItem(value: 'cpb', child: Text('📉 CPB (Low → High)')),
                                      DropdownMenuItem(value: 'profit', child: Text('💵 Profit (High → Low)')),
                                    ],
                                    onChanged: (value) {
                          if (value != null) setState(() => _sortBy = value);
                                    },
                                  ),
                                ),
                    
                    const SizedBox(width: 24),
                    
                    // Filter By dropdown - compact
                                Text(
                      'Filter:',
                                  style: TextStyle(
                                    fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                                  ),
                                ),
                    const SizedBox(width: 8),
                                Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButton<String>(
                                    value: _filterBy,
                                    underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('🔍 All Ads')),
                                      DropdownMenuItem(value: 'hasSpend', child: Text('💵 Has FB Spend')),
                                      DropdownMenuItem(value: 'noSpend', child: Text('⚪ No FB Spend')),
                                      DropdownMenuItem(value: 'profitable', child: Text('✅ Profitable')),
                                      DropdownMenuItem(value: 'unprofitable', child: Text('❌ Unprofitable')),
                                    ],
                                    onChanged: (value) {
                          if (value != null) setState(() => _filterBy = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
              ),
              
              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.folder, size: 20),
                      text: 'Ad Sets',
                    ),
                    Tab(
                      icon: Icon(Icons.ads_click, size: 20),
                      text: 'Ads',
                    ),
                  ],
                ),
              ),
              
              // Tab Views
              SizedBox(
                height: 600, // Fixed height for tab content
                child: filteredAds.isEmpty
                    ? _buildEmptyState(ghlProvider, perfProvider)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Ad Sets Tab
                          AdSetView(
                            ads: filteredAds,
                            provider: perfProvider,
                          ),
                          // Ads Tab
                          AdsView(
                            ads: filteredAds,
                            perfProvider: perfProvider,
                            ghlProvider: ghlProvider,
                            sortBy: _sortBy,
                            filterBy: _filterBy,
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildEmptyState(GoHighLevelProvider ghlProvider, PerformanceCostProvider perfProvider) {
    if (ghlProvider.pipelineCampaigns.isEmpty) {
      return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
                        children: [
              Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
      );
    } else if (perfProvider.hasFacebookData) {
      return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
                        children: [
              Icon(Icons.link_off, size: 48, color: Colors.orange[400]),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_alt_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No ads match the selected date filter',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  List<AdPerformanceWithProduct> _filterAdsByDate(List<AdPerformanceWithProduct> ads) {
    if (_dateFilter == 'all') {
      return ads;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final last30Days = today.subtract(const Duration(days: 30));

    return ads.where((ad) {
      // Use Facebook's dateStop (end date of ad run) for filtering
      // This shows ads that were running during the selected time period
      try {
        if (ad.facebookStats.dateStop.isEmpty) {
          // If no date info, include the ad
          return true;
        }
        
        final adStopDate = DateTime.parse(ad.facebookStats.dateStop);
        final adStopDay = DateTime(adStopDate.year, adStopDate.month, adStopDate.day);

        switch (_dateFilter) {
          case 'today':
            // Show ads that are still running or ended today
            return adStopDay.isAtSameMomentAs(today) || adStopDay.isAfter(today);
          case 'yesterday':
            // Show ads that ended yesterday or are still running
            return adStopDay.isAtSameMomentAs(yesterday) || adStopDay.isAfter(yesterday);
          case 'last7days':
            // Show ads that were active in the last 7 days
            return adStopDay.isAfter(last7Days) || adStopDay.isAtSameMomentAs(last7Days);
          case 'last30days':
            // Show ads that were active in the last 30 days
            return adStopDay.isAfter(last30Days) || adStopDay.isAtSameMomentAs(last30Days);
          default:
            return true;
        }
      } catch (e) {
        // If date parsing fails, include the ad
        return true;
      }
    }).toList();
  }
}
