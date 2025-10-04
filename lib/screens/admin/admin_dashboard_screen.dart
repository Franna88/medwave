import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/role_manager.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize both admin and patient data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().initializeWithMockData();
      context.read<PatientProvider>().loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer3<AdminProvider, AuthProvider, PatientProvider>(
        builder: (context, adminProvider, authProvider, patientProvider, child) {
          if (adminProvider.isLoading || patientProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(authProvider),
                const SizedBox(height: 32),
                _buildStatsCards(adminProvider, patientProvider),
                const SizedBox(height: 32),
                _buildChartsSection(adminProvider, patientProvider),
                const SizedBox(height: 32),
                _buildRecentActivity(adminProvider, patientProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Dashboard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back, ${RoleManager.getRoleDisplayName(authProvider.userRole)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(AdminProvider adminProvider, PatientProvider patientProvider) {
    // Calculate real statistics from actual data
    final totalProviders = adminProvider.totalProviders + adminProvider.totalPendingApprovals;
    final pendingApprovals = adminProvider.totalPendingApprovals;
    final approvalRate = adminProvider.approvalRate;
    
    // Use real patient data
    final totalPatients = patientProvider.patients.length;
    final totalSessions = patientProvider.totalSessionCount;
    
    // Calculate active patients (patients with recent sessions)
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final activePatients = patientProvider.patients.where((patient) {
      if (patient.sessions.isEmpty) return false;
      final lastSession = patient.sessions.last;
      return lastSession.date.isAfter(thirtyDaysAgo);
    }).length;

    final stats = [
      _StatCard(
        title: 'Total Providers',
        value: totalProviders.toString(),
        icon: Icons.business,
        color: AppTheme.primaryColor,
        subtitle: '${adminProvider.totalApprovedProviders} approved',
      ),
      _StatCard(
        title: 'Total Patients',
        value: totalPatients.toString(),
        icon: Icons.people,
        color: Colors.green,
        subtitle: '$activePatients active',
      ),
      _StatCard(
        title: 'Total Sessions',
        value: totalSessions.toString(),
        icon: Icons.medical_services,
        color: Colors.blue,
        subtitle: 'All providers',
      ),
      _StatCard(
        title: 'Approval Rate',
        value: '${approvalRate.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        color: Colors.orange,
        subtitle: '$pendingApprovals pending',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildStatCard(stats[index]),
    );
  }

  Widget _buildStatCard(_StatCard stat) {
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
                  color: stat.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            stat.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(AdminProvider adminProvider, PatientProvider patientProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildProviderDistributionChart(adminProvider),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildPatientProgressChart(patientProvider),
        ),
      ],
    );
  }

  Widget _buildProviderDistributionChart(AdminProvider adminProvider) {
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
            'Provider Status',
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
                    value: adminProvider.totalApprovedProviders.toDouble(),
                    color: Colors.green,
                    title: 'Approved\n${adminProvider.totalApprovedProviders}',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: adminProvider.totalPendingApprovals.toDouble(),
                    color: Colors.orange,
                    title: 'Pending\n${adminProvider.totalPendingApprovals}',
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

  Widget _buildPatientProgressChart(PatientProvider patientProvider) {
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
            'Patient Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildPatientStatsGrid(patientProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientStatsGrid(PatientProvider patientProvider) {
    final patients = patientProvider.patients;
    final totalPatients = patients.length;
    final totalSessions = patientProvider.totalSessionCount;
    
    // Calculate patients with recent activity
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentlyActive = patients.where((patient) {
      if (patient.sessions.isEmpty) return false;
      final lastSession = patient.sessions.last;
      return lastSession.date.isAfter(thirtyDaysAgo);
    }).length;
    
    // Calculate average sessions per patient
    final avgSessions = totalPatients > 0 ? (totalSessions / totalPatients).toStringAsFixed(1) : '0';
    
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMiniStatCard('Total Patients', totalPatients.toString(), Icons.people, Colors.blue),
        _buildMiniStatCard('Total Sessions', totalSessions.toString(), Icons.medical_services, Colors.green),
        _buildMiniStatCard('Recently Active', recentlyActive.toString(), Icons.trending_up, Colors.orange),
        _buildMiniStatCard('Avg Sessions/Patient', avgSessions, Icons.analytics, Colors.purple),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AdminProvider adminProvider, PatientProvider patientProvider) {
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
            'Recent Provider Applications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...adminProvider.pendingApprovals.take(3).map((provider) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  color: Colors.orange,
                ),
              ),
              title: Text(provider.fullName),
              subtitle: Text(provider.fullCompanyName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${provider.daysSinceRegistration} days ago',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}
