import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
              items: [
                {'code': 'All', 'name': 'All Countries'},
                {'code': 'US', 'name': 'United States'},
                {'code': 'ZA', 'name': 'South Africa'},
              ].map((country) {
                return DropdownMenuItem(
                  value: country['code'],
                  child: Row(
                    children: [
                      Text(_getCountryFlag(country['code']!)),
                      const SizedBox(width: 8),
                      Text(country['name']!),
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


  int _getTotalPractitioners(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      // Use system-wide analytics
      final analytics = adminProvider.adminAnalytics;
      final practitionerStats = analytics['practitioners'] as Map<String, dynamic>? ?? {};
      return (practitionerStats['total'] as int? ?? 0);
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.totalPractitioners ?? 0;
  }

  int _getActivePractitioners(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      // Use system-wide analytics (approved practitioners)
      final analytics = adminProvider.adminAnalytics;
      final practitionerStats = analytics['practitioners'] as Map<String, dynamic>? ?? {};
      return (practitionerStats['approved'] as int? ?? 0);
    }
    final analytics = adminProvider.getCountryAnalytics(_selectedCountry);
    return analytics?.activePractitioners ?? 0;
  }

  int _getTotalPatients(AdminProvider adminProvider) {
    if (_selectedCountry == 'All') {
      // Use system-wide analytics
      final analytics = adminProvider.adminAnalytics;
      return analytics['totalPatients'] as int? ?? 0;
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
      case 'US':
      case 'USA':
        return '🇺🇸';
      case 'ZA':
      case 'RSA':
        return '🇿🇦';
      case 'All':
        return '🌍';
      default:
        return '🌍';
    }
  }
}
