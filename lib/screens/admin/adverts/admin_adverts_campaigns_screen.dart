import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/performance_cost_provider.dart';
import '../../../providers/gohighlevel_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin/performance_tabs/three_column_campaign_view.dart';

/// Campaigns screen showing expandable campaign list
class AdminAdvertsCampaignsScreen extends StatefulWidget {
  const AdminAdvertsCampaignsScreen({super.key});

  @override
  State<AdminAdvertsCampaignsScreen> createState() =>
      _AdminAdvertsCampaignsScreenState();
}

class _AdminAdvertsCampaignsScreenState
    extends State<AdminAdvertsCampaignsScreen> {
  String _monthFilter = 'thismonth';
  String _countryFilter = 'all'; // 'all' | 'usa' | 'sa'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
        _initializeSplitCollections();
      } else {
        _loadAvailableMonthsOnly();
      }
    });
  }

  /// Initialize for split collections
  Future<void> _initializeSplitCollections() async {
    final perfProvider = context.read<PerformanceCostProvider>();

    if (!perfProvider.isInitialized) {
      await perfProvider.initialize();
    }
  }

  /// Load only the available months list without loading ad data
  Future<void> _loadAvailableMonthsOnly() async {
    final perfProvider = context.read<PerformanceCostProvider>();

    if (!perfProvider.isInitialized) {
      // Only load months, don't fetch ad data yet
      await perfProvider.loadAvailableMonths();
    }
  }

  /// Load data with filters
  Future<void> _loadDataWithFilters() async {
    final perfProvider = context.read<PerformanceCostProvider>();
    final ghlProvider = context.read<GoHighLevelProvider>();

    if (!perfProvider.isInitialized) {
      await perfProvider.initialize();
    }

    // Calculate months to query based on month filter
    final months = _calculateMonthsToQuery(
      _monthFilter,
      perfProvider.availableMonths,
    );

    // Calculate date range based on month filter
    final dateRange = _calculateCombinedDateRange(_monthFilter, 'all', months);

    if (kDebugMode) {
      print('🔄 LOADING DATA WITH FILTERS:');
      print('   Month Filter: $_monthFilter');
      print('   Months to Query: $months');
      print(
        '   Date Range: ${dateRange['start']?.toIso8601String() ?? "any"} to ${dateRange['end']?.toIso8601String() ?? "any"}',
      );
    }

    // Load data with months and optional date range
    await perfProvider.setSelectedMonths(
      months,
      startDate: dateRange['start'],
      endDate: dateRange['end'],
      countryFilter: _countryFilter,
    );

    if (!ghlProvider.isInitialized) {
      await ghlProvider.initialize();
    }
  }

  /// Load data with filters for split collections
  Future<void> _loadDataWithFiltersNew() async {
    final perfProvider = context.read<PerformanceCostProvider>();
    final ghlProvider = context.read<GoHighLevelProvider>();

    if (!perfProvider.isInitialized) {
      await perfProvider.initialize();
    }

    // Calculate date range from month filter
    final dateRange = _calculateDateRangeForSplitCollections(_monthFilter);

    if (kDebugMode) {
      print('🔄 LOADING DATA WITH FILTERS (Split Collections):');
      print('   Month Filter: $_monthFilter');
      print(
        '   Date Range: ${dateRange['start']?.toIso8601String() ?? "any"} to ${dateRange['end']?.toIso8601String() ?? "any"}',
      );
    }

    // Load campaigns with date range query
    await perfProvider.setSelectedMonths(
      [], // Empty months list for split collections
      startDate: dateRange['start'],
      endDate: dateRange['end'],
      countryFilter: _countryFilter,
    );

    if (!ghlProvider.isInitialized) {
      await ghlProvider.initialize();
    }
  }

  /// Build dynamic month filter items
  List<DropdownMenuItem<String>> _buildMonthFilterItems() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Calculate months
    final thisMonth = DateTime(currentYear, currentMonth);
    final lastMonth = DateTime(currentYear, currentMonth - 1);
    final twoMonthsAgo = DateTime(currentYear, currentMonth - 2);

    // Format month names
    String formatMonthName(DateTime date) {
      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return monthNames[date.month - 1];
    }

    return [
      DropdownMenuItem(
        value: 'thismonth',
        child: Text('📅 This Month (${formatMonthName(thisMonth)})'),
      ),
      DropdownMenuItem(
        value: 'lastmonth',
        child: Text('📅 Last Month (${formatMonthName(lastMonth)})'),
      ),
      DropdownMenuItem(
        value: '2monthsago',
        child: Text('📅 2 Months Ago (${formatMonthName(twoMonthsAgo)})'),
      ),
      const DropdownMenuItem(value: 'last7days', child: Text('📅 Last 7 Days')),
    ];
  }

  /// Calculate date range based on filters
  Map<String, DateTime?> _calculateDateRangeForSplitCollections(
    String monthFilter,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? baseStart;
    DateTime? baseEnd;

    switch (monthFilter) {
      case 'thismonth':
        baseStart = DateTime(now.year, now.month, 1);
        baseEnd = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        break;
      case 'lastmonth':
        final lastMonth = DateTime(now.year, now.month - 1);
        baseStart = DateTime(lastMonth.year, lastMonth.month, 1);
        baseEnd = DateTime(
          lastMonth.year,
          lastMonth.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        break;
      case '2monthsago':
        final twoMonthsAgo = DateTime(now.year, now.month - 2);
        baseStart = DateTime(twoMonthsAgo.year, twoMonthsAgo.month, 1);
        baseEnd = DateTime(
          twoMonthsAgo.year,
          twoMonthsAgo.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        break;
      case 'last7days':
        baseStart = today.subtract(const Duration(days: 6));
        baseEnd = today;
        break;
      default:
        baseStart = DateTime(now.year, now.month, 1);
        baseEnd = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
    }

    return {'start': baseStart, 'end': baseEnd};
  }

  /// Calculate which months to query based on month filter selection
  List<String> _calculateMonthsToQuery(
    String filter,
    List<String> availableMonths,
  ) {
    if (availableMonths.isEmpty) return [];

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthStr =
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';
    final twoMonthsAgo = DateTime(now.year, now.month - 2);
    final twoMonthsAgoStr =
        '${twoMonthsAgo.year}-${twoMonthsAgo.month.toString().padLeft(2, '0')}';

    switch (filter) {
      case 'thismonth':
        return availableMonths.where((m) => m == currentMonth).toList();
      case 'lastmonth':
        return availableMonths.where((m) => m == lastMonthStr).toList();
      case '2monthsago':
        return availableMonths.where((m) => m == twoMonthsAgoStr).toList();
      case 'last3months':
        return availableMonths.take(3).toList();
      case 'last6months':
        return availableMonths.take(6).toList();
      case 'allmonths':
        return availableMonths;
      default:
        // Check if it's a specific month (e.g., "2025-10")
        if (availableMonths.contains(filter)) {
          return [filter];
        }
        // Default to last 3 months
        return availableMonths.take(3).toList();
    }
  }

  /// Calculate combined date range from month filter and date filter
  Map<String, DateTime?> _calculateCombinedDateRange(
    String monthFilter,
    String dateFilter,
    List<String> selectedMonths,
  ) {
    // First, get the base date range from the month filter
    DateTime? monthStart;
    DateTime? monthEnd;

    if (selectedMonths.isNotEmpty) {
      // Parse the first month (earliest)
      final firstMonth = selectedMonths.last; // List is sorted newest first
      final firstParts = firstMonth.split('-');
      if (firstParts.length == 2) {
        final year = int.tryParse(firstParts[0]);
        final month = int.tryParse(firstParts[1]);
        if (year != null && month != null) {
          monthStart = DateTime(year, month, 1);
        }
      }

      // Parse the last month (latest)
      final lastMonth = selectedMonths.first; // List is sorted newest first
      final lastParts = lastMonth.split('-');
      if (lastParts.length == 2) {
        final year = int.tryParse(lastParts[0]);
        final month = int.tryParse(lastParts[1]);
        if (year != null && month != null) {
          // End of month
          monthEnd = DateTime(
            year,
            month + 1,
            1,
          ).subtract(const Duration(seconds: 1));
        }
      }
    }

    // Then, apply the date filter on top of the month range
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (dateFilter) {
      case 'today':
        return {'start': today, 'end': now};
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return {'start': yesterday, 'end': today};
      case 'last7days':
        final last7Days = today.subtract(const Duration(days: 7));
        return {'start': last7Days, 'end': now};
      case 'last30days':
        final last30Days = today.subtract(const Duration(days: 30));
        return {'start': last30Days, 'end': now};
      case 'all':
        // Use the month range
        return {'start': monthStart, 'end': monthEnd};
      default:
        // Default to month range
        return {'start': monthStart, 'end': monthEnd};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<PerformanceCostProvider, GoHighLevelProvider>(
        builder: (context, perfProvider, ghlProvider, child) {
          // Show loading spinner only when actually loading data (not just months)
          if (perfProvider.isLoading) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildHeader(perfProvider, ghlProvider, 0),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (perfProvider.error != null) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildHeader(perfProvider, ghlProvider, 0),
                ),
                Expanded(child: _buildErrorState(perfProvider.error!)),
              ],
            );
          }

          // Determine if we have data based on which schema is being used
          final bool hasData;
          final int dataCount;

          if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
            hasData = perfProvider.campaigns.isNotEmpty;
            dataCount = perfProvider.campaigns.length;
          } else {
            final allAds = perfProvider.getMergedData(ghlProvider);
            final filteredAds = allAds
                .where((ad) => ad.facebookStats.spend > 0)
                .toList();
            hasData = filteredAds.isNotEmpty;
            dataCount = filteredAds.length;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(perfProvider, ghlProvider, dataCount),
                const SizedBox(height: 32),

                // Three-Column Campaign View or Empty State
                if (!perfProvider.isInitialized || !hasData)
                  _buildEmptyOrInstructionState(
                    perfProvider.isInitialized,
                    !hasData,
                  )
                else
                  SizedBox(
                    height: 600, // Fixed height for scrollable columns
                    child: ThreeColumnCampaignView(
                      ads: [], // Not used when USE_SPLIT_COLLECTIONS is true
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
                'Campaign Performance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Detailed campaign metrics and performance',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
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
        // Month filter (primary)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _monthFilter,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            items: _buildMonthFilterItems(),
            onChanged: (value) {
              if (value != null) {
                if (kDebugMode) {
                  print('🔄 MONTH FILTER CHANGED: $_monthFilter → $value');
                }
                setState(() {
                  _monthFilter = value;
                });

                // Call appropriate loading method based on schema
                if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
                  _loadDataWithFiltersNew();
                } else {
                  _loadDataWithFilters();
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Country filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _countryFilter,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('🌍 All'),
              ),
              DropdownMenuItem(
                value: 'sa',
                child: Text('🇿🇦 South Africa'),
              ),
              DropdownMenuItem(
                value: 'usa',
                child: Text('🇺🇸 USA'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                if (kDebugMode) {
                  print('🔄 COUNTRY FILTER CHANGED: $_countryFilter → $value');
                }
                setState(() {
                  _countryFilter = value;
                });

                // Reload with new country filter
                if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
                  _loadDataWithFiltersNew();
                } else {
                  _loadDataWithFilters();
                }
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
                  // Reload data with current filters
                  if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
                    await _loadDataWithFiltersNew();
                  } else {
                    await _loadDataWithFilters();
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

  Widget _buildEmptyOrInstructionState(bool isInitialized, bool hasNoAds) {
    if (!isInitialized) {
      // Show instruction to select a month
      return Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.calendar_month,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a Month to View Campaigns',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a month from the dropdown above to load campaign data',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Icon(Icons.arrow_upward, size: 32, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    } else if (hasNoAds) {
      // Show empty state when initialized but no ads found
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
                'Try selecting a different month or adjusting your filters',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
