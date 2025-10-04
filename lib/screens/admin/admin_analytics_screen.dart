import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
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
                _buildCountryFilter(),
                const SizedBox(height: 24),
                _buildAnalyticsCards(adminProvider),
                const SizedBox(height: 24),
                _buildChartsSection(adminProvider),
                const SizedBox(height: 24),
                _buildCountryBreakdown(adminProvider),
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
          'Analytics Dashboard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Comprehensive analytics and insights across all regions',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCountryFilter() {
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
          Text(
            'Filter by Country:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedCountry,
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
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards(AdminProvider adminProvider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildAnalyticsCard(
          'Total Practitioners',
          _getTotalPractitioners(adminProvider).toString(),
          Icons.medical_services,
          AppTheme.primaryColor,
          '+12% from last month',
        ),
        _buildAnalyticsCard(
          'Active Practitioners',
          _getActivePractitioners(adminProvider).toString(),
          Icons.person_outline,
          Colors.green,
          '+8% from last month',
        ),
        _buildAnalyticsCard(
          'Total Patients',
          _getTotalPatients(adminProvider).toString(),
          Icons.people,
          Colors.blue,
          '+15% from last month',
        ),
        _buildAnalyticsCard(
          'Avg. Healing Rate',
          '${_getAverageHealingRate(adminProvider).toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.orange,
          '+2.3% from last month',
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color, String trend) {
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
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(AdminProvider adminProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildPractitionerDistributionChart(adminProvider),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildPatientProgressChart(),
        ),
      ],
    );
  }

  Widget _buildPractitionerDistributionChart(AdminProvider adminProvider) {
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
            'Practitioners by Country',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: _getPieChartSections(adminProvider),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientProgressChart() {
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
            'Patient Progress Over Time',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                    spots: _getProgressSpots(),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
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

  Widget _buildCountryBreakdown(AdminProvider adminProvider) {
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
            'Country Performance Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...adminProvider.countryAnalytics.map((analytics) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    analytics.flagEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          analytics.countryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${analytics.totalPractitioners} practitioners • ${analytics.totalPatients} patients • ${analytics.totalSessions} sessions',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${analytics.averageWoundHealingRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Healing Rate',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections(AdminProvider adminProvider) {
    final colors = [AppTheme.primaryColor, Colors.green, Colors.orange, Colors.blue];
    return adminProvider.countryAnalytics.asMap().entries.map((entry) {
      final index = entry.key;
      final analytics = entry.value;
      return PieChartSectionData(
        value: analytics.totalPractitioners.toDouble(),
        color: colors[index % colors.length],
        title: '${analytics.id}\n${analytics.totalPractitioners}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<FlSpot> _getProgressSpots() {
    return [
      const FlSpot(0, 40),
      const FlSpot(1, 45),
      const FlSpot(2, 43),
      const FlSpot(3, 50),
      const FlSpot(4, 55),
      const FlSpot(5, 70),
      const FlSpot(6, 75),
      const FlSpot(7, 80),
      const FlSpot(8, 85),
      const FlSpot(9, 90),
    ];
  }

  int _getTotalPractitioners(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      return adminProvider.countryAnalytics.fold(0, (sum, analytics) => sum + analytics.totalPractitioners);
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.totalPractitioners ?? 0;
  }

  int _getActivePractitioners(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      return adminProvider.countryAnalytics.fold(0, (sum, analytics) => sum + analytics.activePractitioners);
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.activePractitioners ?? 0;
  }

  int _getTotalPatients(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      return adminProvider.countryAnalytics.fold(0, (sum, analytics) => sum + analytics.totalPatients);
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.totalPatients ?? 0;
  }

  double _getAverageHealingRate(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      final analytics = adminProvider.countryAnalytics;
      if (analytics.isEmpty) return 0.0;
      return analytics.fold(0.0, (sum, a) => sum + a.averageWoundHealingRate) / analytics.length;
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.averageWoundHealingRate ?? 0.0;
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
}
