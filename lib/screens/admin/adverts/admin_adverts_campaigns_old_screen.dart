import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../providers/gohighlevel_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin/performance_tabs/three_column_campaign_view.dart';

/// Campaigns screen showing expandable campaign list (OLD VERSION - BACKUP)
class AdminAdvertsCampaignsOldScreen extends StatefulWidget {
  const AdminAdvertsCampaignsOldScreen({super.key});

  @override
  State<AdminAdvertsCampaignsOldScreen> createState() => _AdminAdvertsCampaignsOldScreenState();
}

class _AdminAdvertsCampaignsOldScreenState extends State<AdminAdvertsCampaignsOldScreen> {
  String _dateFilter = 'all';

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

          final allAds = perfProvider.getMergedData(ghlProvider);
          final filteredAds = _filterAdsByDate(allAds);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(perfProvider, ghlProvider, filteredAds.length),
                const SizedBox(height: 32),
                
                // Three-Column Campaign View
                if (filteredAds.isEmpty)
                  _buildEmptyState()
                else
                  SizedBox(
                    height: 600, // Fixed height for scrollable columns
                    child: ThreeColumnCampaignView(
                      ads: filteredAds.cast(),
                      provider: perfProvider,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
    int adsCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campaign Performance (Old)',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Detailed campaign metrics and performance - Using adPerformance collection',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
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
        // Date filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _dateFilter,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            items: const [
              DropdownMenuItem(value: 'today', child: Text('📅 Today')),
              DropdownMenuItem(value: 'yesterday', child: Text('📅 Yesterday')),
              DropdownMenuItem(value: 'last7days', child: Text('📅 Last 7 Days')),
              DropdownMenuItem(value: 'last30days', child: Text('📅 Last 30 Days')),
              DropdownMenuItem(value: 'all', child: Text('📅 All Time')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _dateFilter = value);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // Refresh button
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
        IconButton(
          onPressed: perfProvider.isFacebookDataLoading
              ? null
              : () async {
                  await perfProvider.refreshFacebookData();
                  if (context.mounted) {
                    await perfProvider.mergeWithCumulativeData(ghlProvider);
                  }
                },
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Data',
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text('$adsCount Ads'),
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No campaigns available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Campaigns with Facebook spend will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
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

  List<dynamic> _filterAdsByDate(List<dynamic> ads) {
    // Filter by FB Spend > 0 first
    final adsWithSpend = ads.where((ad) {
      return ad.facebookStats.spend > 0;
    }).toList();
    
    if (_dateFilter == 'all') return adsWithSpend;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final last30Days = today.subtract(const Duration(days: 30));

    return adsWithSpend.where((ad) {
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

