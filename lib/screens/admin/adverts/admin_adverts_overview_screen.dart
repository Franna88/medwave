import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../providers/gohighlevel_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin/performance_tabs/summary_view.dart';

/// Overview page showing KPIs and top performer analytics
class AdminAdvertsOverviewScreen extends StatefulWidget {
  const AdminAdvertsOverviewScreen({super.key});

  @override
  State<AdminAdvertsOverviewScreen> createState() => _AdminAdvertsOverviewScreenState();
}

class _AdminAdvertsOverviewScreenState extends State<AdminAdvertsOverviewScreen> {
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
                
                // Summary Content
                if (filteredAds.isEmpty)
                  _buildEmptyState()
                else
                  Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SummaryView(
                        ads: filteredAds.cast(),
                        provider: perfProvider,
                      ),
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
                'Advertisement Performance Overview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'High-level insights and top performer analytics',
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
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync your Facebook and GHL data to see performance overview',
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
      final lastUpdated = ad.lastUpdated as DateTime?;
      if (lastUpdated == null) return false;

      final updateDate = DateTime(
        lastUpdated.year,
        lastUpdated.month,
        lastUpdated.day,
      );

      switch (_dateFilter) {
        case 'today':
          return updateDate.isAtSameMomentAs(today);
        case 'yesterday':
          return updateDate.isAtSameMomentAs(yesterday);
        case 'last7days':
          return updateDate.isAfter(last7Days) || updateDate.isAtSameMomentAs(last7Days);
        case 'last30days':
          return updateDate.isAfter(last30Days) || updateDate.isAtSameMomentAs(last30Days);
        default:
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

