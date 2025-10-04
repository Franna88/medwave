import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';

class AdminAdvertPerformanceScreen extends StatefulWidget {
  const AdminAdvertPerformanceScreen({super.key});

  @override
  State<AdminAdvertPerformanceScreen> createState() => _AdminAdvertPerformanceScreenState();
}

class _AdminAdvertPerformanceScreenState extends State<AdminAdvertPerformanceScreen> {
  String _selectedTimeframe = 'Last 30 Days';
  String _selectedCountry = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildPerformanceMetrics(),
                const SizedBox(height: 24),
                _buildChartsSection(),
                const SizedBox(height: 24),
                _buildCampaignsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
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
          'Track and analyze marketing campaign performance across all channels',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
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
                      Text(country == 'All' ? 'All Countries' : country),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCountry = value!),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _createNewCampaign,
            icon: const Icon(Icons.add),
            label: const Text('New Campaign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
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

  Widget _buildChartsSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildPerformanceTrendChart(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChannelDistributionChart(),
        ),
      ],
    );
  }

  Widget _buildPerformanceTrendChart() {
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
                'Performance Trends',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildLegendItem('Impressions', AppTheme.primaryColor),
              const SizedBox(width: 16),
              _buildLegendItem('Clicks', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Conversions', Colors.blue),
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
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
                    spots: _getImpressionsSpots(),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: _getClicksSpots(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: _getConversionsSpots(),
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

  Widget _buildChannelDistributionChart() {
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
            'Channel Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _getChannelSections(),
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
    final campaigns = _getMockCampaigns();
    
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
                Text(
                  'Active Campaigns',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: campaigns.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: campaign['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    campaign['icon'],
                    color: campaign['color'],
                  ),
                ),
                title: Text(
                  campaign['name'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${campaign['channel']} • ${campaign['status']}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Budget: ${campaign['budget']}'),
                        const SizedBox(width: 16),
                        Text('Spent: ${campaign['spent']}'),
                        const SizedBox(width: 16),
                        Text('CTR: ${campaign['ctr']}'),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editCampaign(campaign),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bar_chart),
                      onPressed: () => _viewCampaignAnalytics(campaign),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleCampaignAction(value, campaign),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'pause', child: Text('Pause')),
                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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

  List<FlSpot> _getImpressionsSpots() {
    return [
      const FlSpot(0, 1000),
      const FlSpot(1, 1200),
      const FlSpot(2, 1100),
      const FlSpot(3, 1400),
      const FlSpot(4, 1600),
      const FlSpot(5, 1800),
      const FlSpot(6, 2000),
    ];
  }

  List<FlSpot> _getClicksSpots() {
    return [
      const FlSpot(0, 32),
      const FlSpot(1, 38),
      const FlSpot(2, 35),
      const FlSpot(3, 45),
      const FlSpot(4, 52),
      const FlSpot(5, 58),
      const FlSpot(6, 64),
    ];
  }

  List<FlSpot> _getConversionsSpots() {
    return [
      const FlSpot(0, 4),
      const FlSpot(1, 5),
      const FlSpot(2, 4),
      const FlSpot(3, 6),
      const FlSpot(4, 7),
      const FlSpot(5, 8),
      const FlSpot(6, 8),
    ];
  }

  List<PieChartSectionData> _getChannelSections() {
    return [
      PieChartSectionData(
        value: 35,
        color: AppTheme.primaryColor,
        title: 'Google Ads\n35%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 25,
        color: Colors.blue,
        title: 'Facebook\n25%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 20,
        color: Colors.green,
        title: 'LinkedIn\n20%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 20,
        color: Colors.orange,
        title: 'Other\n20%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<Map<String, dynamic>> _getMockCampaigns() {
    return [
      {
        'name': 'Healthcare Professionals Q4',
        'channel': 'Google Ads',
        'status': 'Active',
        'budget': '\$5,000',
        'spent': '\$3,240',
        'ctr': '3.2%',
        'icon': Icons.search,
        'color': AppTheme.primaryColor,
      },
      {
        'name': 'Wound Care Specialists',
        'channel': 'Facebook',
        'status': 'Active',
        'budget': '\$3,000',
        'spent': '\$1,890',
        'ctr': '2.8%',
        'icon': Icons.facebook,
        'color': Colors.blue,
      },
      {
        'name': 'Medical Device Promotion',
        'channel': 'LinkedIn',
        'status': 'Paused',
        'budget': '\$2,500',
        'spent': '\$2,100',
        'ctr': '4.1%',
        'icon': Icons.business,
        'color': Colors.green,
      },
    ];
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

  void _createNewCampaign() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating new advertising campaign...')),
    );
  }

  void _editCampaign(Map<String, dynamic> campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing campaign: ${campaign['name']}')),
    );
  }

  void _viewCampaignAnalytics(Map<String, dynamic> campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing analytics for: ${campaign['name']}')),
    );
  }

  void _handleCampaignAction(String action, Map<String, dynamic> campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${action.toUpperCase()} campaign: ${campaign['name']}')),
    );
  }
}
