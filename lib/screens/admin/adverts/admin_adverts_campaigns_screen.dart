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
  State<AdminAdvertsCampaignsScreen> createState() => _AdminAdvertsCampaignsScreenState();
}

class _AdminAdvertsCampaignsScreenState extends State<AdminAdvertsCampaignsScreen> {
  String _monthFilter = 'thismonth'; // Primary filter: default to current month
  String _dateFilter = 'all'; // Secondary filter: date range within selected months

  @override
  void initState() {
    super.initState();
    // Load available months only (don't load data yet - let user select month first)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableMonthsOnly();
    });
  }
  
  /// Load only the available months list without loading ad data
  Future<void> _loadAvailableMonthsOnly() async {
    final perfProvider = context.read<PerformanceCostProvider>();
    
    if (!perfProvider.isInitialized) {
      // Only load months, don't fetch ad data yet
      await perfProvider.loadAvailableMonths();
    }
  }

  /// Load data with current month and date filters
  Future<void> _loadDataWithFilters() async {
    final perfProvider = context.read<PerformanceCostProvider>();
    final ghlProvider = context.read<GoHighLevelProvider>();
    
    if (!perfProvider.isInitialized) {
      await perfProvider.initialize();
    }
    
    // Calculate months to query based on month filter
    final months = _calculateMonthsToQuery(_monthFilter, perfProvider.availableMonths);
    
    // Calculate date range based on BOTH month filter and date filter
    final dateRange = _calculateCombinedDateRange(_monthFilter, _dateFilter, months);
    
    if (kDebugMode) {
      print('🔄 LOADING DATA WITH FILTERS:');
      print('   Month Filter: $_monthFilter');
      print('   Months to Query: $months');
      print('   Date Filter: $_dateFilter');
      print('   Date Range: ${dateRange['start']?.toIso8601String() ?? "any"} to ${dateRange['end']?.toIso8601String() ?? "any"}');
    }
    
    // Load data with months and optional date range
    await perfProvider.setSelectedMonths(
      months,
      startDate: dateRange['start'],
      endDate: dateRange['end'],
    );
    
    if (!ghlProvider.isInitialized) {
      await ghlProvider.initialize();
    }
  }

  /// Calculate which months to query based on month filter selection
  List<String> _calculateMonthsToQuery(String filter, List<String> availableMonths) {
    if (availableMonths.isEmpty) return [];
    
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthStr = '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';
    
    switch (filter) {
      case 'thismonth':
        return availableMonths.where((m) => m == currentMonth).toList();
      case 'lastmonth':
        return availableMonths.where((m) => m == lastMonthStr).toList();
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
          monthEnd = DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));
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
            // NEW: Check campaigns from split collections
            hasData = perfProvider.campaigns.isNotEmpty;
            dataCount = perfProvider.campaigns.length;
          } else {
            // OLD: Check ads from advertData
            final allAds = perfProvider.getMergedData(ghlProvider);
            final filteredAds = allAds.where((ad) => ad.facebookStats.spend > 0).toList();
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
                  _buildEmptyOrInstructionState(perfProvider.isInitialized, !hasData)
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
            items: [
              const DropdownMenuItem(value: 'thismonth', child: Text('📅 This Month')),
              const DropdownMenuItem(value: 'lastmonth', child: Text('📅 Last Month')),
              const DropdownMenuItem(value: 'last3months', child: Text('📅 Last 3 Months')),
              const DropdownMenuItem(value: 'last6months', child: Text('📅 Last 6 Months')),
              const DropdownMenuItem(value: 'allmonths', child: Text('📅 All Months')),
              // Add individual months dynamically
              if (!PerformanceCostProvider.USE_SPLIT_COLLECTIONS)
                ...perfProvider.availableMonths.take(6).map((month) {
                  return DropdownMenuItem(
                    value: month,
                    child: Text('📅 ${_formatMonthLabel(month)}'),
                  );
                })
              else
                // For split collections, show last 12 months
                ...List.generate(12, (index) {
                  final date = DateTime.now().subtract(Duration(days: 30 * index));
                  final monthStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                  return DropdownMenuItem(
                    value: monthStr,
                    child: Text('📅 ${_formatMonthLabel(monthStr)}'),
                  );
                }),
            ],
            onChanged: (value) {
              if (value != null) {
                if (kDebugMode) {
                  print('🔄 MONTH FILTER CHANGED: $_monthFilter → $value');
                }
                setState(() {
                  _monthFilter = value;
                  _dateFilter = 'all'; // Reset date filter when month changes
                });
                _loadDataWithFilters();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Date filter (secondary - filters within selected months)
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
              DropdownMenuItem(value: 'all', child: Text('🔍 All Dates')),
              DropdownMenuItem(value: 'today', child: Text('🔍 Today')),
              DropdownMenuItem(value: 'yesterday', child: Text('🔍 Yesterday')),
              DropdownMenuItem(value: 'last7days', child: Text('🔍 Last 7 Days')),
              DropdownMenuItem(value: 'last30days', child: Text('🔍 Last 30 Days')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _dateFilter = value);
                // Reload data with new date filter
                _loadDataWithFilters();
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
                  await _loadDataWithFilters();
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
              Icon(Icons.calendar_month, size: 64, color: AppTheme.primaryColor.withOpacity(0.5)),
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

  /// Format month string for display (e.g., "2025-10" -> "October 2025")
  String _formatMonthLabel(String month) {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final monthNum = int.parse(parts[1]);
        const monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        if (monthNum >= 1 && monthNum <= 12) {
          return '${monthNames[monthNum - 1]} $year';
        }
      }
    } catch (e) {
      // Return original if parsing fails
    }
    return month;
  }
}

