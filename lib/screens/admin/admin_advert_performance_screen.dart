import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Legacy screen - redirects to new Overview page
/// Kept for backward compatibility with existing routes
class AdminAdvertPerformanceScreen extends StatefulWidget {
  const AdminAdvertPerformanceScreen({super.key});

  @override
  State<AdminAdvertPerformanceScreen> createState() => _AdminAdvertPerformanceScreenState();
}

class _AdminAdvertPerformanceScreenState extends State<AdminAdvertPerformanceScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect to new Overview page only if we're at the base route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentUri = GoRouterState.of(context).uri;
        // Only redirect if we're at exactly /admin/adverts (not a sub-route)
        if (currentUri.path == '/admin/adverts') {
          context.go('/admin/adverts/overview');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while redirecting
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Keep all the old code below for reference but commented out
/*
class _AdminAdvertPerformanceScreenStateOLD extends State<AdminAdvertPerformanceScreen> {
  String _selectedTimeframe = 'Last 30 Days';
  String _selectedCountry = 'All';
  String _selectedSalesAgent = 'All';
  String? _expandedCampaignKey; // Track which campaign is expanded
  String _campaignSortBy = 'recent'; // Sort campaigns by: recent, total, booked, call, noShow, deposits, cash

  @override
  void initState() {
    super.initState();
    // Initialize GoHighLevel data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoHighLevelProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer3<AdminProvider, GoHighLevelProvider, PerformanceCostProvider>(
        builder: (context, adminProvider, ghlProvider, perfProvider, child) {
          if (adminProvider.isLoading || ghlProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error if GoHighLevel connection failed
          if (ghlProvider.error != null) {
            return _buildErrorState(ghlProvider.error!, ghlProvider);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(ghlProvider, perfProvider),
                const SizedBox(height: 32),
                
                // STANDALONE SUMMARY SECTION AT THE TOP
                _buildStandaloneSummary(perfProvider, ghlProvider),
                const SizedBox(height: 32),
                
                // Performance Cost Manager (Hierarchy View + Product Setup)
                const PerformanceCostManager(),
                const SizedBox(height: 24),
                
                // COMMENTED OUT - Campaign Performance by Stage
                // _buildCampaignPerformanceByStage(ghlProvider),
                // const SizedBox(height: 24),
                
                // Performance Metrics (keeping the stats cards)
                _buildPerformanceMetrics(),
                
                // REMOVED - Sales Agent Charts Section
                // const SizedBox(height: 24),
                // _buildSalesAgentChartsSection(ghlProvider),
                
                // REMOVED - Sales Agent Metrics Table
                // const SizedBox(height: 24),
                // _buildSalesAgentMetrics(ghlProvider),
                
                // REMOVED - Campaigns List (replaced by hierarchy)
                // const SizedBox(height: 24),
                // _buildCampaignsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GoHighLevelProvider ghlProvider, PerformanceCostProvider perfProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advertisement Performance',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
                    'Track and analyze marketing campaign performance with real-time GoHighLevel CRM data',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
              ),
            ),
            // Refresh button and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (ghlProvider.isDataStale)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Data Stale',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Manual sync button - syncs BOTH Facebook and GHL
                    ElevatedButton.icon(
                      onPressed: (ghlProvider.isSyncing || perfProvider.isFacebookDataLoading)
                          ? null 
                          : () async {
                              // Sync Facebook data first
                              await perfProvider.refreshFacebookData();
                              // Then sync GHL data (which also triggers matching)
                              await ghlProvider.syncOpportunityHistory();
                              // Finally refresh the merged view
                              if (context.mounted) {
                                await perfProvider.mergeWithCumulativeData(ghlProvider);
                              }
                            },
                      icon: (ghlProvider.isSyncing || perfProvider.isFacebookDataLoading)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text((ghlProvider.isSyncing || perfProvider.isFacebookDataLoading) 
                          ? 'Syncing...' 
                          : 'Manual Sync'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: ghlProvider.refreshData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Data',
                    ),
                  ],
                ),
                Text(
                  'Last updated: ${ghlProvider.getTimeSinceLastRefresh()}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // View mode toggle - Hidden by default, keep for development
        if (false) // Change to true to show toggle for admin testing
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Altus + Andries Pipelines Active',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // View mode toggle switch
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewModeButton(
                      ghlProvider,
                      'snapshot',
                      'Snapshot',
                      Icons.photo_camera_outlined,
                    ),
                    const SizedBox(width: 4),
                    _buildViewModeButton(
                      ghlProvider,
                      'cumulative',
                      'Cumulative',
                      Icons.stacked_line_chart,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildViewModeButton(
    GoHighLevelProvider ghlProvider,
    String mode,
    String label,
    IconData icon,
  ) {
    final isActive = ghlProvider.viewMode == mode;
    
    return InkWell(
      onTap: () => ghlProvider.setViewMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build standalone summary section at the top
  Widget _buildStandaloneSummary(
    PerformanceCostProvider perfProvider,
    GoHighLevelProvider ghlProvider,
  ) {
    // Get merged data
    final allAds = perfProvider.getMergedData(ghlProvider);
    
    if (allAds.isEmpty) {
      return const SizedBox.shrink();
    }

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SummaryView(
          ads: allAds,
          provider: perfProvider,
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Impressions',
            '2.4M',
            Icons.visibility,
            AppTheme.primaryColor,
            '+15.3%',
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Click-Through Rate',
            '3.2%',
            Icons.mouse,
            Colors.green,
            '+0.8%',
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Conversion Rate',
            '12.5%',
            Icons.trending_up,
            Colors.blue,
            '+2.1%',
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Cost per Acquisition',
            '\$45.20',
            Icons.attach_money,
            Colors.orange,
            '-5.2%',
            false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'ROAS',
            '4.2x',
            Icons.analytics,
            Colors.purple,
            '+0.3x',
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Sales Agent Charts Section (replaces old charts)
  Widget _buildSalesAgentChartsSection(GoHighLevelProvider ghlProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildSalesAgentPerformanceTrendChart(ghlProvider),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSalesAgentDistributionChart(ghlProvider),
        ),
      ],
    );
  }

  /// Build Sales Agent Performance Trend Chart (replaces Campaign Performance Trends)
  Widget _buildSalesAgentPerformanceTrendChart(GoHighLevelProvider ghlProvider) {
    // Get agents and ensure uniqueness by agent name
    final allAgents = ghlProvider.pipelineSalesAgents;
    
    // Group by agent name and aggregate their data
    final Map<String, Map<String, dynamic>> agentMap = {};
    for (final agent in allAgents) {
      final agentData = agent as Map<String, dynamic>;
      final agentName = agentData['agentName'] as String? ?? 'Unknown';
      
      if (agentMap.containsKey(agentName)) {
        // Agent already exists, aggregate the data
        final existing = agentMap[agentName]!;
        existing['totalOpportunities'] = (existing['totalOpportunities'] as int? ?? 0) + (agentData['totalOpportunities'] as int? ?? 0);
        existing['bookedAppointments'] = (existing['bookedAppointments'] as int? ?? 0) + (agentData['bookedAppointments'] as int? ?? 0);
        existing['callCompleted'] = (existing['callCompleted'] as int? ?? 0) + (agentData['callCompleted'] as int? ?? 0);
        existing['noShowCancelledDisqualified'] = (existing['noShowCancelledDisqualified'] as int? ?? 0) + (agentData['noShowCancelledDisqualified'] as int? ?? 0);
        existing['deposits'] = (existing['deposits'] as int? ?? 0) + (agentData['deposits'] as int? ?? 0);
        existing['cashCollected'] = (existing['cashCollected'] as int? ?? 0) + (agentData['cashCollected'] as int? ?? 0);
      } else {
        // New agent, add to map
        agentMap[agentName] = Map<String, dynamic>.from(agentData);
      }
    }
    
    // Convert back to list and sort by total opportunities
    final uniqueAgents = agentMap.values.toList()
      ..sort((a, b) {
        final aOpps = a['totalOpportunities'] as int? ?? 0;
        final bOpps = b['totalOpportunities'] as int? ?? 0;
        return bOpps.compareTo(aOpps); // Descending order
      });
    
    // Take top 5 agents
    final agents = uniqueAgents.take(5).toList();
    
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Sales Agent Performance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Conversion Rate (%)', AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: agents.isEmpty
                ? Center(
                    child: Text(
                      'No agent data available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, 
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}%',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < agents.length) {
                                final agentMap = agents[value.toInt()];
                                final agentName = agentMap['agentName'] as String? ?? 'Unknown';
                                return Text(
                                  agentName.length > 8 ? '${agentName.substring(0, 8)}...' : agentName,
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        // Conversion Rate Line
                        LineChartBarData(
                          spots: agents.asMap().entries.map((entry) {
                            final agentMap = entry.value;
                            final totalOpportunities = agentMap['totalOpportunities'] as int? ?? 0;
                            final bookedAppointments = agentMap['bookedAppointments'] as int? ?? 0;
                            final conversionRate = totalOpportunities > 0 
                                ? (bookedAppointments / totalOpportunities * 100) 
                                : 0.0;
                            return FlSpot(entry.key.toDouble(), conversionRate);
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 4,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build Sales Agent Distribution Chart (replaces Campaign Distribution)
  Widget _buildSalesAgentDistributionChart(GoHighLevelProvider ghlProvider) {
    final agents = ghlProvider.pipelineSalesAgents;
    
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Sales Agent Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: agents.isEmpty
                ? Center(
                    child: Text(
                      'No agent data available',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: _getSalesAgentSections(ghlProvider),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Get pie chart sections for sales agents
  List<PieChartSectionData> _getSalesAgentSections(GoHighLevelProvider ghlProvider) {
    // Get agents and ensure uniqueness by agent name
    final allAgents = ghlProvider.pipelineSalesAgents;
    
    // Group by agent name and aggregate their data
    final Map<String, Map<String, dynamic>> agentMap = {};
    for (final agent in allAgents) {
      final agentData = agent as Map<String, dynamic>;
      final agentName = agentData['agentName'] as String? ?? 'Unknown';
      
      if (agentMap.containsKey(agentName)) {
        // Agent already exists, aggregate the data
        final existing = agentMap[agentName]!;
        existing['totalOpportunities'] = (existing['totalOpportunities'] as int? ?? 0) + (agentData['totalOpportunities'] as int? ?? 0);
        existing['bookedAppointments'] = (existing['bookedAppointments'] as int? ?? 0) + (agentData['bookedAppointments'] as int? ?? 0);
        existing['callCompleted'] = (existing['callCompleted'] as int? ?? 0) + (agentData['callCompleted'] as int? ?? 0);
        existing['noShowCancelledDisqualified'] = (existing['noShowCancelledDisqualified'] as int? ?? 0) + (agentData['noShowCancelledDisqualified'] as int? ?? 0);
        existing['deposits'] = (existing['deposits'] as int? ?? 0) + (agentData['deposits'] as int? ?? 0);
        existing['cashCollected'] = (existing['cashCollected'] as int? ?? 0) + (agentData['cashCollected'] as int? ?? 0);
      } else {
        // New agent, add to map
        agentMap[agentName] = Map<String, dynamic>.from(agentData);
      }
    }
    
    // Convert back to list and sort by total opportunities
    final uniqueAgents = agentMap.values.toList()
      ..sort((a, b) {
        final aOpps = a['totalOpportunities'] as int? ?? 0;
        final bOpps = b['totalOpportunities'] as int? ?? 0;
        return bOpps.compareTo(aOpps); // Descending order
      });
    
    // Take top 5 agents
    final agents = uniqueAgents.take(5).toList();
    if (agents.isEmpty) {
      return [
        PieChartSectionData(
          value: 100,
          color: Colors.grey[300]!,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    }

    // Calculate total opportunities across all agents
    final totalOpportunities = agents.fold<int>(
      0,
      (sum, agent) {
        final agentMap = agent;
        return sum + (agentMap['totalOpportunities'] as int? ?? 0);
      },
    );

    if (totalOpportunities == 0) {
      return [
        PieChartSectionData(
          value: 100,
          color: Colors.grey[300]!,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    }

    // Define colors for agents
    final colors = [
      AppTheme.primaryColor,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    // Create pie chart sections for each agent
    return agents.asMap().entries.map((entry) {
      final index = entry.key;
      final agentMap = entry.value;
      final agentName = agentMap['agentName'] as String? ?? 'Unknown';
      final opportunities = agentMap['totalOpportunities'] as int? ?? 0;
      final percentage = (opportunities / totalOpportunities * 100).toStringAsFixed(1);

      return PieChartSectionData(
        value: opportunities.toDouble(),
        color: colors[index % colors.length],
        title: '${agentName.length > 12 ? '${agentName.substring(0, 12)}...' : agentName}\n$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildPerformanceTrendChart(GoHighLevelProvider ghlProvider) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Text(
                'Campaign Performance Trends',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildLegendItem('Leads', AppTheme.primaryColor),
              const SizedBox(width: 16),
              _buildLegendItem('Meetings', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Sales', Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final campaigns = ghlProvider.pipelineCampaigns;
                        if (value.toInt() >= 0 && value.toInt() < campaigns.length) {
                          final campaignName = campaigns[value.toInt()]['campaignName'] as String? ?? '';
                          // Show abbreviated campaign name
                          return Text(
                            campaignName.length > 10 ? '${campaignName.substring(0, 10)}...' : campaignName,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getLeadsSpots(ghlProvider),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: _getMeetingsSpots(ghlProvider),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: _getSalesSpots(ghlProvider),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelDistributionChart(GoHighLevelProvider ghlProvider) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Campaign Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _getCampaignSections(ghlProvider),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList() {
    return Consumer<GoHighLevelProvider>(
      builder: (context, ghlProvider, child) {
        final campaigns = ghlProvider.pipelineCampaigns;
        
        if (campaigns.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
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
                    'No Campaign Data Available',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Campaign performance data will appear here once loaded',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }
        
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                    Icon(Icons.campaign, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                Text(
                      'Campaign & Ad Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                    Chip(
                      label: Text('${ghlProvider.pipelineCampaigns.length} Campaigns'),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${ghlProvider.pipelineCampaigns.fold<int>(0, (sum, c) => sum + ((c['adsList'] as List?)?.length ?? 0))} Ads'),
                      backgroundColor: Colors.green.withOpacity(0.1),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: campaigns.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
                  return _buildCampaignCard(campaign);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final ads = campaign['adsList'] as List<dynamic>? ?? [];
    final totalOpportunities = campaign['totalOpportunities'] ?? 0;
    final bookedAppointments = campaign['bookedAppointments'] ?? 0;
    final cashCollected = campaign['cashCollected'] ?? 0;
    
    // Calculate conversion rate (booked appointments / total opportunities)
    final conversionRate = totalOpportunities > 0 
        ? ((bookedAppointments / totalOpportunities) * 100).toStringAsFixed(1) 
        : '0';
    
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
          Icons.campaign,
          color: AppTheme.primaryColor,
                  ),
                ),
                title: Text(
        campaign['campaignName'] ?? 'Unknown Campaign',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _buildCampaignStat(Icons.people, '${totalOpportunities} Opportunities', Colors.blue),
            _buildCampaignStat(Icons.calendar_today, '${bookedAppointments} Booked', Colors.green),
            _buildCampaignStat(Icons.phone, '${campaign['callCompleted'] ?? 0} Calls', Colors.orange),
            _buildCampaignStat(Icons.money, '\$${cashCollected} Cash', Colors.purple),
            _buildCampaignStat(Icons.ads_click, '${ads.length} Ads', Colors.amber),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$conversionRate%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const Text(
            'Conversion',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      children: [
        if (ads.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No ad data available', style: TextStyle(color: Colors.grey)),
          )
        else
          ...ads.map((ad) => _buildAdCard(ad as Map<String, dynamic>)).toList(),
      ],
    );
  }

  Widget _buildCampaignStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final totalOpportunities = ad['totalOpportunities'] ?? 0;
    final bookedAppointments = ad['bookedAppointments'] ?? 0;
    
    // Calculate conversion rate
    final conversionRate = totalOpportunities > 0 
        ? ((bookedAppointments / totalOpportunities) * 100).toStringAsFixed(1) 
        : '0';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ads_click, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'AD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ad['adName'] ?? 'Unnamed Ad',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$conversionRate% Conv.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          Row(
                  children: [
              Expanded(
                child: _buildAdMetric(
                  'Total',
                  '${totalOpportunities}',
                  Icons.people,
                  Colors.blue,
                  percentage: totalOpportunities > 0 ? '100%' : '-',
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Booked',
                  '${bookedAppointments}',
                  Icons.calendar_today,
                  Colors.green,
                  percentage: totalOpportunities > 0 
                    ? '${((bookedAppointments / totalOpportunities) * 100).toStringAsFixed(1)}%'
                    : '-',
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Calls',
                  '${ad['callCompleted'] ?? 0}',
                  Icons.phone,
                  Colors.orange,
                  percentage: totalOpportunities > 0 
                    ? '${(((ad['callCompleted'] ?? 0) / totalOpportunities) * 100).toStringAsFixed(1)}%'
                    : '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAdMetric(
                  'No Show',
                  '${ad['noShowCancelledDisqualified'] ?? 0}',
                  Icons.event_busy,
                  Colors.red,
                  percentage: totalOpportunities > 0 
                    ? '${(((ad['noShowCancelledDisqualified'] ?? 0) / totalOpportunities) * 100).toStringAsFixed(1)}%'
                    : '-',
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Deposits',
                  '${ad['deposits'] ?? 0}',
                  Icons.account_balance_wallet,
                  Colors.purple,
                  percentage: totalOpportunities > 0 
                    ? '${(((ad['deposits'] ?? 0) / totalOpportunities) * 100).toStringAsFixed(1)}%'
                    : '-',
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Cash',
                  '${ad['cashCollected'] ?? 0}',
                  Icons.attach_money,
                  Colors.green,
                  percentage: totalOpportunities > 0 
                    ? '${(((ad['cashCollected'] ?? 0) / totalOpportunities) * 100).toStringAsFixed(1)}%'
                    : '-',
                ),
                    ),
                  ],
                ),
          if ((ad['salesAgentsList'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (ad['salesAgentsList'] as List<dynamic>).map((agent) {
                return Chip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: Text(
                    'Agent: ${agent['leadCount']} leads',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdMetric(String label, String value, IconData icon, Color color, {String? percentage}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (percentage != null)
          Text(
            percentage,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.7),
            ),
          ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Real data methods using GoHighLevel campaign data
  List<FlSpot> _getLeadsSpots(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.pipelineCampaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final totalOpportunities = (campaign['totalOpportunities'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), totalOpportunities);
    }).toList();
  }

  List<FlSpot> _getMeetingsSpots(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.pipelineCampaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final booked = (campaign['bookedAppointments'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), booked);
    }).toList();
  }

  List<FlSpot> _getSalesSpots(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.pipelineCampaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final cashCollected = (campaign['cashCollected'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), cashCollected);
    }).toList();
  }

  List<PieChartSectionData> _getCampaignSections(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.pipelineCampaigns;
    if (campaigns.isEmpty) {
    return [
        PieChartSectionData(
          value: 100,
          color: Colors.grey[300]!,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    }

    // Calculate total opportunities across all campaigns
    final totalOpportunities = campaigns.fold<int>(
      0, 
      (sum, campaign) => sum + (campaign['totalOpportunities'] as int? ?? 0),
    );

    if (totalOpportunities == 0) {
    return [
      PieChartSectionData(
          value: 100,
          color: Colors.grey[300]!,
          title: 'No Data',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    }

    // Define colors for campaigns
    final colors = [
      AppTheme.primaryColor,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    // Create pie chart sections for each campaign
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final campaignName = campaign['campaignName'] as String? ?? 'Unknown';
      final opportunities = campaign['totalOpportunities'] as int? ?? 0;
      final percentage = (opportunities / totalOpportunities * 100).toStringAsFixed(1);
      
      return PieChartSectionData(
        value: opportunities.toDouble(),
        color: colors[index % colors.length],
        title: '${campaignName.length > 15 ? '${campaignName.substring(0, 15)}...' : campaignName}\n$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  String _getCountryFlag(String country) {
    switch (country) {
      case 'USA':
        return '🇺🇸';
      case 'RSA':
        return '🇿🇦';
      case 'All':
        return '🌍';
      default:
        return '🌍';
    }
  }

  // ============================================================================
  // GOHIGHLEVEL INTEGRATION METHODS
  // ============================================================================

  /// Build error state for GoHighLevel connection issues
  Widget _buildErrorState(String error, GoHighLevelProvider ghlProvider) {
    final isCorsError = error.toLowerCase().contains('cors') || 
                       error.toLowerCase().contains('failed to fetch') ||
                       error.toLowerCase().contains('cross-origin');
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCorsError ? Icons.web_asset_off : Icons.cloud_off,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              isCorsError ? 'GoHighLevel API - CORS Restriction' : 'GoHighLevel Connection Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            if (isCorsError) ...[
              Text(
                'The GoHighLevel API cannot be accessed directly from a web browser due to CORS (Cross-Origin Resource Sharing) restrictions.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solutions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Deploy the app to a server with a backend proxy\n'
                      '• Run as a mobile app (Android/iOS)\n'
                      '• Use a CORS proxy service for development',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: ghlProvider.refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: ghlProvider.clearError,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build enhanced filters section with sales agent filter
  Widget _buildFiltersSection(GoHighLevelProvider ghlProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedTimeframe,
              decoration: InputDecoration(
                labelText: 'Timeframe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'Last Year'].map((timeframe) {
                return DropdownMenuItem(value: timeframe, child: Text(timeframe));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTimeframe = value);
                  ghlProvider.setTimeframe(value);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'USA', 'RSA'].map((country) {
                return DropdownMenuItem(
                  value: country,
                  child: Row(
                    children: [
                      Text(_getCountryFlag(country)),
                      const SizedBox(width: 8),
                      Text(country),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCountry = value!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSalesAgent,
              decoration: InputDecoration(
                labelText: 'Sales Agent',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', ...ghlProvider.getPipelineSalesAgents()].map((agent) {
                return DropdownMenuItem(value: agent, child: Text(agent));
              }).toList(),
              onChanged: (value) => setState(() => _selectedSalesAgent = value!),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Pipeline Performance metrics for Altus + Andries (prominently displayed)
  Widget _buildPipelinePerformanceMetrics(GoHighLevelProvider ghlProvider) {
    // Check if we have pipeline performance data
    final hasData = ghlProvider.pipelinePerformance != null && 
                    ghlProvider.totalPipelineOpportunities > 0;

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pipeline performance data is loading or unavailable. Please check that Altus and Andries pipelines are properly configured in GoHighLevel.',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    // Determine which view to show based on selected sales agent
    final isFiltered = _selectedSalesAgent != 'All';
    
    if (isFiltered) {
      // Show filtered view for specific sales agent
      return _buildFilteredAgentView(ghlProvider, _selectedSalesAgent);
    }

    // Show overview (combined stats from both pipelines)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Pipeline Performance Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Altus: ${ghlProvider.altusOpportunities} | Andries: ${ghlProvider.andriesOpportunities}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Live Data',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 1: The 5 key metrics
        Row(
          children: [
            Expanded(
              child: _buildPipelineMetricCard(
                'Booked Appointments',
                ghlProvider.bookedAppointments.toString(),
                Icons.calendar_today,
                Colors.green,
                ghlProvider.totalPipelineOpportunities,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPipelineMetricCard(
                'Call Completed',
                ghlProvider.callCompleted.toString(),
                Icons.phone,
                Colors.blue,
                ghlProvider.totalPipelineOpportunities,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPipelineMetricCard(
                'No Show/Cancelled/Disqualified',
                ghlProvider.noShowCancelledDisqualified.toString(),
                Icons.cancel,
                Colors.orange,
                ghlProvider.totalPipelineOpportunities,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPipelineMetricCard(
                'Deposits',
                ghlProvider.deposits.toString(),
                Icons.account_balance_wallet,
                Colors.purple,
                ghlProvider.totalPipelineOpportunities,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPipelineMetricCard(
                'Cash Collected',
                '${ghlProvider.cashCollected}\n\$${ghlProvider.totalMonetaryValue.toStringAsFixed(0)}',
                Icons.payments,
                Colors.teal,
                ghlProvider.totalPipelineOpportunities,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build filtered view for a specific sales agent showing their pipeline breakdown
  Widget _buildFilteredAgentView(GoHighLevelProvider ghlProvider, String agentName) {
    final agentStats = ghlProvider.getPipelineStatsForAgent(agentName);
    
    if (agentStats == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No data found for agent: $agentName'),
      );
    }

    final pipelines = agentStats['pipelines'] as Map<String, dynamic>? ?? {};
    final altusStats = pipelines['altus'] as Map<String, dynamic>?;
    final andriesStats = pipelines['andries'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                agentName.isNotEmpty ? agentName[0].toUpperCase() : 'A',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$agentName - Pipeline Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Live Data',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Combined stats for this agent
        Text(
          'Combined Stats (Both Pipelines)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAgentMetricCard(
                'Booked Appointments',
                (agentStats['bookedAppointments'] ?? 0).toString(),
                Icons.calendar_today,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAgentMetricCard(
                'Call Completed',
                (agentStats['callCompleted'] ?? 0).toString(),
                Icons.phone,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAgentMetricCard(
                'No Show/Cancelled',
                (agentStats['noShowCancelledDisqualified'] ?? 0).toString(),
                Icons.cancel,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAgentMetricCard(
                'Deposits',
                (agentStats['deposits'] ?? 0).toString(),
                Icons.account_balance_wallet,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAgentMetricCard(
                'Cash Collected',
                '\$${((agentStats['totalMonetaryValue'] ?? 0) as num).toStringAsFixed(0)}',
                Icons.payments,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Altus Pipeline Stats
        if (altusStats != null) ...[
          Text(
            'Altus Pipeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAgentMetricCard(
                  'Booked',
                  (altusStats['bookedAppointments'] ?? 0).toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Calls',
                  (altusStats['callCompleted'] ?? 0).toString(),
                  Icons.phone,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'No Show',
                  (altusStats['noShowCancelledDisqualified'] ?? 0).toString(),
                  Icons.cancel,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Deposits',
                  (altusStats['deposits'] ?? 0).toString(),
                  Icons.account_balance_wallet,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Cash',
                  '\$${((altusStats['totalMonetaryValue'] ?? 0) as num).toStringAsFixed(0)}',
                  Icons.payments,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Andries Pipeline Stats
        if (andriesStats != null) ...[
          Text(
            'Andries Pipeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.purple[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAgentMetricCard(
                  'Booked',
                  (andriesStats['bookedAppointments'] ?? 0).toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Calls',
                  (andriesStats['callCompleted'] ?? 0).toString(),
                  Icons.phone,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'No Show',
                  (andriesStats['noShowCancelledDisqualified'] ?? 0).toString(),
                  Icons.cancel,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Deposits',
                  (andriesStats['deposits'] ?? 0).toString(),
                  Icons.account_balance_wallet,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAgentMetricCard(
                  'Cash',
                  '\$${((andriesStats['totalMonetaryValue'] ?? 0) as num).toStringAsFixed(0)}',
                  Icons.payments,
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Build sort filter chips for campaign table
  Widget _buildSortFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSortChip(
                  label: 'Recent',
                  value: 'recent',
                  icon: Icons.access_time,
                  color: Colors.purple,
                ),
                _buildSortChip(
                  label: 'Total',
                  value: 'total',
                  icon: Icons.trending_up,
                  color: Colors.grey,
                ),
                _buildSortChip(
                  label: 'Booked',
                  value: 'booked',
                  icon: Icons.calendar_today,
                  color: Colors.green,
                ),
                _buildSortChip(
                  label: 'Call',
                  value: 'call',
                  icon: Icons.phone,
                  color: Colors.blue,
                ),
                _buildSortChip(
                  label: 'No Show',
                  value: 'noShow',
                  icon: Icons.cancel,
                  color: Colors.orange,
                ),
                _buildSortChip(
                  label: 'Deposits',
                  value: 'deposits',
                  icon: Icons.payments,
                  color: Colors.purple,
                ),
                _buildSortChip(
                  label: 'Cash',
                  value: 'cash',
                  icon: Icons.attach_money,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual sort chip
  Widget _buildSortChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _campaignSortBy == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _campaignSortBy = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_downward,
                size: 12,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build Campaign Performance by Stage section
  Widget _buildCampaignPerformanceByStage(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.pipelineCampaigns;
    
    if (campaigns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No campaign data available yet. Campaigns will appear once opportunities have attribution data.',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    // Sort campaigns based on selected filter
    final sortedCampaigns = List<Map<String, dynamic>>.from(campaigns);
    switch (_campaignSortBy) {
      case 'total':
        sortedCampaigns.sort((a, b) => (b['totalOpportunities'] ?? 0).compareTo(a['totalOpportunities'] ?? 0));
        break;
      case 'booked':
        sortedCampaigns.sort((a, b) => (b['bookedAppointments'] ?? 0).compareTo(a['bookedAppointments'] ?? 0));
        break;
      case 'call':
        sortedCampaigns.sort((a, b) => (b['callCompleted'] ?? 0).compareTo(a['callCompleted'] ?? 0));
        break;
      case 'noShow':
        sortedCampaigns.sort((a, b) => (b['noShowCancelledDisqualified'] ?? 0).compareTo(a['noShowCancelledDisqualified'] ?? 0));
        break;
      case 'deposits':
        sortedCampaigns.sort((a, b) => (b['deposits'] ?? 0).compareTo(a['deposits'] ?? 0));
        break;
      case 'cash':
        sortedCampaigns.sort((a, b) => (b['cashCollected'] ?? 0).compareTo(a['cashCollected'] ?? 0));
        break;
      case 'recent':
      default:
        // Keep original sorting (by mostRecentTimestamp from API)
        break;
    }
    
    // Show top 20 campaigns
    final topCampaigns = sortedCampaigns.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ad Campaign Performance by Stage',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                topCampaigns.length >= 20 
                    ? 'Top 20 Campaigns' 
                    : 'Top ${topCampaigns.length} Campaigns',
                style: TextStyle(
                  color: Colors.purple[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Live Data',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Sort filter chips
        _buildSortFilterChips(),
        const SizedBox(height: 12),
        // Campaign performance table
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
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Campaign Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTableHeader('Total', Colors.grey),
                    const SizedBox(width: 8),
                    _buildTableHeader('Booked', Colors.green),
                    const SizedBox(width: 8),
                    _buildTableHeader('Call', Colors.blue),
                    const SizedBox(width: 8),
                    _buildTableHeader('No Show', Colors.orange),
                    const SizedBox(width: 8),
                    _buildTableHeader('Deposits', Colors.purple),
                    const SizedBox(width: 8),
                    _buildTableHeader('Cash', Colors.teal),
                  ],
                ),
              ),
              // Campaign rows
              ...topCampaigns.asMap().entries.map((entry) {
                final index = entry.key;
                final campaign = entry.value as Map<String, dynamic>;
                final isEven = index % 2 == 0;
                final campaignKey = campaign['campaignKey'] ?? '';
                final isExpanded = _expandedCampaignKey == campaignKey;
                final ads = (campaign['adsList'] as List?) ?? [];
                
                return Column(
                  children: [
                    // Campaign row (clickable)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedCampaignKey = isExpanded ? null : campaignKey;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : Colors.grey[50],
                          borderRadius: index == topCampaigns.length - 1 && !isExpanded
                              ? const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Expand/collapse icon
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          campaign['campaignName'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (ads.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${ads.length} ads',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if ((campaign['campaignSource'] ?? '').isNotEmpty)
                                    Text(
                                      campaign['campaignSource'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['totalOpportunities'] ?? 0).toString(),
                              Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['bookedAppointments'] ?? 0).toString(),
                              Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['callCompleted'] ?? 0).toString(),
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['noShowCancelledDisqualified'] ?? 0).toString(),
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['deposits'] ?? 0).toString(),
                              Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            _buildTableCell(
                              (campaign['cashCollected'] ?? 0).toString(),
                              Colors.teal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanded ads section
                    if (isExpanded && ads.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: isEven ? Colors.grey[50] : Colors.white,
                          border: Border(
                            left: BorderSide(color: AppTheme.primaryColor, width: 3),
                          ),
                        ),
                        child: Column(
                          children: ads.asMap().entries.map((adEntry) {
                            final ad = adEntry.value as Map<String, dynamic>;
                            final adIndex = adEntry.key;
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: adIndex % 2 == 0 
                                    ? (isEven ? Colors.grey[100] : Colors.grey[50])
                                    : (isEven ? Colors.grey[50] : Colors.white),
                                borderRadius: adIndex == ads.length - 1 && index == topCampaigns.length - 1
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 28), // Indent for hierarchy
                                  Icon(Icons.ads_click, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Tooltip(
                                            message: 'Ad ID: ${ad['adId'] ?? 'Unknown'}',
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ad['adName'] ?? ad['adId'] ?? 'Unknown',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[800],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (ad['adSource'] != null && ad['adSource'].toString().isNotEmpty)
                                                  Text(
                                                    '${ad['adSource']}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[500],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (ad['adUrl'] != null && ad['adUrl'].toString().isNotEmpty)
                                          Tooltip(
                                            message: 'View ad in Facebook Ads Library',
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 4),
                                              child: InkWell(
                                                onTap: () async {
                                                  final url = ad['adUrl'] as String;
                                                  final uri = Uri.parse(url);
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                  }
                                                },
                                                child: Icon(
                                                  Icons.open_in_new,
                                                  size: 14,
                                                  color: Colors.blue[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['totalOpportunities'] ?? 0).toString(), Colors.grey),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['bookedAppointments'] ?? 0).toString(), Colors.green),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['callCompleted'] ?? 0).toString(), Colors.blue),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['noShowCancelledDisqualified'] ?? 0).toString(), Colors.orange),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['deposits'] ?? 0).toString(), Colors.purple),
                                  const SizedBox(width: 8),
                                  _buildCompactCell((ad['cashCollected'] ?? 0).toString(), Colors.teal),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text, Color color) {
    return Expanded(
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCompactCell(String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build metric card for pipeline performance
  Widget _buildPipelineMetricCard(String title, String value, IconData icon, Color color, int total) {
    // Calculate percentage
    final numValue = int.tryParse(value.split('\n')[0]) ?? 0;
    final percentage = total > 0 ? (numValue / total * 100).toStringAsFixed(1) : '0.0';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build metric card for agent stats
  Widget _buildAgentMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build GoHighLevel charts section
  Widget _buildGoHighLevelChartsSection(GoHighLevelProvider ghlProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildLeadTypeDistributionChart(ghlProvider),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildConversionFunnelChart(ghlProvider),
        ),
      ],
    );
  }

  /// Build lead type distribution chart (HQL vs Ave Lead)
  Widget _buildLeadTypeDistributionChart(GoHighLevelProvider ghlProvider) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Lead Quality Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
      PieChartSectionData(
                    value: ghlProvider.erichHQLLeads.toDouble(),
                    color: Colors.amber,
                    title: 'HQL\n${ghlProvider.erichHQLLeads}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
                    value: ghlProvider.erichAveLeads.toDouble(),
                    color: Colors.blue,
                    title: 'Ave Lead\n${ghlProvider.erichAveLeads}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
                    value: (ghlProvider.erichTotalLeads - ghlProvider.erichHQLLeads - ghlProvider.erichAveLeads).toDouble(),
                    color: Colors.grey,
                    title: 'Other\n${ghlProvider.erichTotalLeads - ghlProvider.erichHQLLeads - ghlProvider.erichAveLeads}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build conversion funnel chart
  Widget _buildConversionFunnelChart(GoHighLevelProvider ghlProvider) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Conversion Funnel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                _buildFunnelStep('Leads', ghlProvider.erichTotalLeads, ghlProvider.erichTotalLeads, AppTheme.primaryColor),
                const SizedBox(height: 8),
                _buildFunnelStep('Appointments', ghlProvider.erichAppointments, ghlProvider.erichTotalLeads, Colors.green),
                const SizedBox(height: 8),
                _buildFunnelStep('Sales', ghlProvider.erichSales, ghlProvider.erichTotalLeads, Colors.purple),
                const SizedBox(height: 8),
                _buildFunnelStep('Deposits', ghlProvider.erichDeposits, ghlProvider.erichTotalLeads, Colors.orange),
                const SizedBox(height: 8),
                _buildFunnelStep('Installations', ghlProvider.erichInstallations, ghlProvider.erichTotalLeads, Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual funnel step
  Widget _buildFunnelStep(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;
    final width = total > 0 ? (count / total) : 0.0;
    
    return Container(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      '$count (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build sales agent metrics section
  Widget _buildSalesAgentMetrics(GoHighLevelProvider ghlProvider) {
    final agentMetrics = ghlProvider.pipelineSalesAgents;
    
    if (agentMetrics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
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
            Icon(Icons.person_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Sales Agent Data Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sales agent assignments will appear here once leads are assigned in GoHighLevel.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Sales Agent Performance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Agent')),
                DataColumn(label: Text('Total Opportunities')),
                DataColumn(label: Text('Booked')),
                DataColumn(label: Text('Calls')),
                DataColumn(label: Text('No Show')),
                DataColumn(label: Text('Deposits')),
                DataColumn(label: Text('Cash Collected')),
                DataColumn(label: Text('Conversion %')),
              ],
              rows: agentMetrics.map((agent) {
                final agentMap = agent as Map<String, dynamic>;
                final agentName = agentMap['agentName'] as String? ?? 'Unknown';
                final totalOpportunities = agentMap['totalOpportunities'] as int? ?? 0;
                final bookedAppointments = agentMap['bookedAppointments'] as int? ?? 0;
                final callCompleted = agentMap['callCompleted'] as int? ?? 0;
                final noShow = agentMap['noShowCancelledDisqualified'] as int? ?? 0;
                final deposits = agentMap['deposits'] as int? ?? 0;
                final cashCollected = agentMap['cashCollected'] as int? ?? 0;
                final conversionRate = totalOpportunities > 0 
                    ? (bookedAppointments / totalOpportunities * 100) 
                    : 0.0;
                
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Text(
                              agentName.isNotEmpty ? agentName[0].toUpperCase() : 'A',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(agentName),
                        ],
                      ),
                    ),
                    DataCell(Text(totalOpportunities.toString())),
                    DataCell(Text(bookedAppointments.toString())),
                    DataCell(Text(callCompleted.toString())),
                    DataCell(Text(noShow.toString())),
                    DataCell(Text(deposits.toString())),
                    DataCell(Text('\$$cashCollected')),
                    DataCell(Text('${conversionRate.toStringAsFixed(1)}%')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

}
*/
