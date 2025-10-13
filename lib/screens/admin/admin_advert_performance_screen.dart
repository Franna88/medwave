import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../providers/gohighlevel_provider.dart';
import '../../theme/app_theme.dart';

class AdminAdvertPerformanceScreen extends StatefulWidget {
  const AdminAdvertPerformanceScreen({super.key});

  @override
  State<AdminAdvertPerformanceScreen> createState() => _AdminAdvertPerformanceScreenState();
}

class _AdminAdvertPerformanceScreenState extends State<AdminAdvertPerformanceScreen> {
  String _selectedTimeframe = 'Last 30 Days';
  String _selectedCountry = 'All';
  String _selectedSalesAgent = 'All';

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
      body: Consumer2<AdminProvider, GoHighLevelProvider>(
        builder: (context, adminProvider, ghlProvider, child) {
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
                _buildHeader(ghlProvider),
                const SizedBox(height: 24),
                _buildFiltersSection(ghlProvider),
                const SizedBox(height: 24),
                _buildErichPipelineMetrics(ghlProvider),
                const SizedBox(height: 24),
                _buildPerformanceMetrics(),
                const SizedBox(height: 24),
                _buildGoHighLevelChartsSection(ghlProvider),
                const SizedBox(height: 24),
                _buildChartsSection(ghlProvider),
                const SizedBox(height: 24),
                _buildSalesAgentMetrics(ghlProvider),
                const SizedBox(height: 24),
                _buildCampaignsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GoHighLevelProvider ghlProvider) {
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
        if (ghlProvider.hasErichPipeline) ...[
          const SizedBox(height: 12),
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
                  'Erich Pipeline Active',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
          ),
        ],
      ],
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

  Widget _buildChartsSection(GoHighLevelProvider ghlProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildPerformanceTrendChart(ghlProvider),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChannelDistributionChart(ghlProvider),
        ),
      ],
    );
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
                        final campaigns = ghlProvider.campaigns;
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
        final campaigns = ghlProvider.campaigns;
        
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
                      label: Text('${ghlProvider.totalCampaigns} Campaigns'),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${ghlProvider.totalAds} Ads'),
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
    final ads = campaign['ads'] as List<dynamic>? ?? [];
    final conversionRates = campaign['conversionRates'] as Map<String, dynamic>? ?? {};
    
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
            _buildCampaignStat(Icons.people, '${campaign['totalLeads']} Leads', Colors.blue),
            _buildCampaignStat(Icons.star, '${campaign['hqlLeads']} HQL', Colors.amber),
            _buildCampaignStat(Icons.calendar_today, '${campaign['appointments']?['booked'] ?? 0} Meetings', Colors.green),
            _buildCampaignStat(Icons.shopping_cart, '${campaign['sales']?['sold'] ?? 0} Sales', Colors.purple),
            _buildCampaignStat(Icons.ads_click, '${ads.length} Ads', Colors.orange),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${conversionRates['appointmentRate'] ?? '0'}%',
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
    final conversionRates = ad['conversionRates'] as Map<String, dynamic>? ?? {};
    final appointments = ad['appointments'] as Map<String, dynamic>? ?? {};
    final sales = ad['sales'] as Map<String, dynamic>? ?? {};
    
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
                  '${conversionRates['appointmentRate'] ?? '0'}% Conv.',
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
                  'Total Leads',
                  '${ad['totalLeads'] ?? 0}',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'HQL',
                  '${ad['hqlLeads'] ?? 0}',
                  Icons.star,
                  Colors.amber,
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Ave',
                  '${ad['aveLeads'] ?? 0}',
                  Icons.trending_down,
                  Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAdMetric(
                  'Meetings',
                  '${appointments['booked'] ?? 0}',
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'No Show',
                  '${appointments['rescheduled'] ?? 0}',
                  Icons.event_busy,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildAdMetric(
                  'Sales',
                  '${sales['sold'] ?? 0}',
                  Icons.shopping_cart,
                  Colors.purple,
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

  Widget _buildAdMetric(String label, String value, IconData icon, Color color) {
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
    final campaigns = ghlProvider.campaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final totalLeads = (campaign['totalLeads'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), totalLeads);
    }).toList();
  }

  List<FlSpot> _getMeetingsSpots(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.campaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final appointments = campaign['appointments'] as Map<String, dynamic>? ?? {};
      final booked = (appointments['booked'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), booked);
    }).toList();
  }

  List<FlSpot> _getSalesSpots(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.campaigns;
    if (campaigns.isEmpty) {
      return [const FlSpot(0, 0)];
    }
    return campaigns.asMap().entries.map((entry) {
      final index = entry.key;
      final campaign = entry.value;
      final sales = campaign['sales'] as Map<String, dynamic>? ?? {};
      final sold = (sales['sold'] as int? ?? 0).toDouble();
      return FlSpot(index.toDouble(), sold);
    }).toList();
  }

  List<PieChartSectionData> _getCampaignSections(GoHighLevelProvider ghlProvider) {
    final campaigns = ghlProvider.campaigns;
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

    // Calculate total leads across all campaigns
    final totalLeads = campaigns.fold<int>(
      0, 
      (sum, campaign) => sum + (campaign['totalLeads'] as int? ?? 0),
    );

    if (totalLeads == 0) {
    return [
      PieChartSectionData(
          value: 100,
          color: Colors.grey[300]!,
          title: 'No Leads',
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
      final leads = campaign['totalLeads'] as int? ?? 0;
      final percentage = (leads / totalLeads * 100).toStringAsFixed(1);
      
      return PieChartSectionData(
        value: leads.toDouble(),
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
              onChanged: (value) => setState(() => _selectedTimeframe = value!),
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
              items: ['All', ...ghlProvider.getUniqueSalesAgents()].map((agent) {
                return DropdownMenuItem(value: agent, child: Text(agent));
              }).toList(),
              onChanged: (value) => setState(() => _selectedSalesAgent = value!),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Erich Pipeline specific metrics (prominently displayed)
  Widget _buildErichPipelineMetrics(GoHighLevelProvider ghlProvider) {
    if (!ghlProvider.hasErichPipeline) {
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
                'Erich Pipeline not found in GoHighLevel. Please ensure the pipeline is properly configured.',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Erich Pipeline Performance',
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
        Row(
          children: [
            Expanded(
              child: _buildErichMetricCard(
                'Total Leads',
                ghlProvider.erichTotalLeads.toString(),
                Icons.people,
                AppTheme.primaryColor,
                _calculateChange(ghlProvider.erichTotalLeads, 45), // Mock previous value
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'HQL Leads',
                ghlProvider.erichHQLLeads.toString(),
                Icons.star,
                Colors.amber,
                _calculateChange(ghlProvider.erichHQLLeads, 28),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Ave Leads',
                ghlProvider.erichAveLeads.toString(),
                Icons.trending_up,
                Colors.blue,
                _calculateChange(ghlProvider.erichAveLeads, 17),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Appointments',
                '${ghlProvider.erichAppointments} (${ghlProvider.erichAppointmentRate.toStringAsFixed(1)}%)',
                Icons.calendar_today,
                Colors.green,
                _calculateChange(ghlProvider.erichAppointments, 32),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Sales',
                '${ghlProvider.erichSales} (${ghlProvider.erichSaleConversionRate.toStringAsFixed(1)}%)',
                Icons.attach_money,
                Colors.purple,
                _calculateChange(ghlProvider.erichSales, 18),
                true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildErichMetricCard(
                'Deposits',
                '${ghlProvider.erichDeposits}',
                Icons.account_balance_wallet,
                Colors.orange,
                _calculateChange(ghlProvider.erichDeposits, 15),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Installations',
                '${ghlProvider.erichInstallations} (${ghlProvider.erichInstallationRate.toStringAsFixed(1)}%)',
                Icons.build,
                Colors.teal,
                _calculateChange(ghlProvider.erichInstallations, 12),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Total Deposits',
                '\$${ghlProvider.erichTotalDeposits.toStringAsFixed(0)}',
                Icons.savings,
                Colors.indigo,
                _calculateChange(ghlProvider.erichTotalDeposits.toInt(), 45000),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildErichMetricCard(
                'Cash Collected',
                '\$${ghlProvider.erichTotalCashCollected.toStringAsFixed(0)}',
                Icons.payments,
                Colors.red,
                _calculateChange(ghlProvider.erichTotalCashCollected.toInt(), 67000),
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(), // Empty space for alignment
            ),
          ],
        ),
      ],
    );
  }

  /// Build metric card for Erich Pipeline
  Widget _buildErichMetricCard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
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
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? Colors.green[700] : Colors.red[700],
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
    final agentMetrics = ghlProvider.getSalesAgentMetrics();
    
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
                DataColumn(label: Text('Total Leads')),
                DataColumn(label: Text('HQL')),
                DataColumn(label: Text('Ave Lead')),
                DataColumn(label: Text('Appointments')),
                DataColumn(label: Text('Sales')),
                DataColumn(label: Text('Conversion %')),
                DataColumn(label: Text('Deposits')),
                DataColumn(label: Text('Cash Collected')),
                DataColumn(label: Text('Installations')),
              ],
              rows: agentMetrics.map((agent) {
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
                              agent.agentName.isNotEmpty ? agent.agentName[0].toUpperCase() : 'A',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(agent.agentName),
                        ],
                      ),
                    ),
                    DataCell(Text(agent.totalLeads.toString())),
                    DataCell(Text(agent.hqlLeads.toString())),
                    DataCell(Text(agent.aveLeads.toString())),
                    DataCell(Text(agent.appointments.toString())),
                    DataCell(Text(agent.sales.toString())),
                    DataCell(Text('${agent.saleConversionRate.toStringAsFixed(1)}%')),
                    DataCell(Text('\$${agent.totalDeposits.toStringAsFixed(0)}')),
                    DataCell(Text('\$${agent.totalCashCollected.toStringAsFixed(0)}')),
                    DataCell(Text(agent.installations.toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to calculate percentage change
  String _calculateChange(int current, int previous) {
    if (previous == 0) return '+0%';
    final change = ((current - previous) / previous) * 100;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }
}
