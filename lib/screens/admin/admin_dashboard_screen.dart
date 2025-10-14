import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    // Initialize both admin and patient data (admin mode - load ALL patients)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().initializeWithMockData();
      context.read<PatientProvider>().loadPatients(isAdmin: true);
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
    // Use system-wide analytics from AdminProvider (not practitioner-filtered)
    final analytics = adminProvider.adminAnalytics;
    final practitionerStats = analytics['practitioners'] as Map<String, dynamic>? ?? {};
    
    final totalProviders = (practitionerStats['total'] as int? ?? 0);
    final approvedProviders = (practitionerStats['approved'] as int? ?? 0);
    final pendingApprovals = (practitionerStats['pending'] as int? ?? 0);
    
    // Use system-wide patient and session counts (ALL practitioners)
    final totalPatients = analytics['totalPatients'] as int? ?? 0;
    final totalSessions = analytics['totalSessions'] as int? ?? 0;
    
    // Calculate active patients (patients with sessions in last 30 days)
    final activePatients = _calculateActivePatients(patientProvider.patients);
    
    // Calculate average wound healing rate
    final avgHealingRate = _calculateAverageHealingRate(patientProvider.patients);
    
    // Calculate sessions this month
    final sessionsThisMonth = _calculateSessionsThisMonth(patientProvider.patients);

    final stats = [
      _StatCard(
        title: 'Total Providers',
        value: totalProviders.toString(),
        icon: Icons.business,
        color: AppTheme.primaryColor,
        subtitle: '$approvedProviders active',
        trend: pendingApprovals > 0 ? '+$pendingApprovals pending' : 'All approved',
        trendPositive: true,
      ),
      _StatCard(
        title: 'Total Patients',
        value: totalPatients.toString(),
        icon: Icons.people,
        color: Colors.green,
        subtitle: '$activePatients active',
        trend: totalPatients > 0 ? '${((activePatients / totalPatients) * 100).toStringAsFixed(0)}% active rate' : 'No patients',
        trendPositive: activePatients > (totalPatients * 0.5),
      ),
      _StatCard(
        title: 'Total Sessions',
        value: totalSessions.toString(),
        icon: Icons.medical_services,
        color: Colors.blue,
        subtitle: '$sessionsThisMonth this month',
        trend: totalSessions > 0 ? '${(totalSessions / (totalProviders > 0 ? totalProviders : 1)).toStringAsFixed(1)} per provider' : 'No sessions',
        trendPositive: true,
      ),
      _StatCard(
        title: 'Healing Rate',
        value: '${avgHealingRate.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        color: Colors.orange,
        subtitle: 'Avg improvement',
        trend: avgHealingRate > 50 ? 'Excellent progress' : avgHealingRate > 30 ? 'Good progress' : 'Needs attention',
        trendPositive: avgHealingRate > 50,
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
              if (stat.trend != null)
                Icon(
                  stat.trendPositive ? Icons.trending_up : Icons.trending_down,
                  color: stat.trendPositive ? Colors.green : Colors.red,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: 28,
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
          const SizedBox(height: 2),
          Text(
            stat.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (stat.trend != null) ...[
            const SizedBox(height: 4),
            Text(
              stat.trend!,
              style: TextStyle(
                fontSize: 11,
                color: stat.trendPositive ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartsSection(AdminProvider adminProvider, PatientProvider patientProvider) {
    // Display Patient Overview cards side by side (no container)
    return _buildPatientOverviewCards(patientProvider);
  }


  /// Build Patient Overview cards side by side (no container wrapper)
  Widget _buildPatientOverviewCards(PatientProvider patientProvider) {
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
    
    return Row(
      children: [
        Expanded(
          child: _buildPatientOverviewCard(
            'Total Patients',
            totalPatients.toString(),
            Icons.people,
            Colors.blue,
            '$recentlyActive recently active',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPatientOverviewCard(
            'Total Sessions',
            totalSessions.toString(),
            Icons.medical_services,
            Colors.green,
            '$avgSessions avg per patient',
          ),
        ),
      ],
    );
  }

  /// Build individual patient overview card
  Widget _buildPatientOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
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

  int _calculateActivePatients(List patients) {
    if (patients.isEmpty) return 0;
    
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      int activeCount = 0;
      for (final patient in patients) {
        try {
          final sessions = patient.sessions as List;
          if (sessions.isEmpty) continue;
          
          for (final sessionData in sessions) {
            try {
              final date = sessionData.date as DateTime;
              if (date.isAfter(thirtyDaysAgo)) {
                activeCount++;
                break; // Patient is active, count once and move to next patient
              }
            } catch (e) {
              continue;
            }
          }
        } catch (e) {
          continue;
        }
      }
      return activeCount;
    } catch (e) {
      return 0;
    }
  }

  double _calculateAverageHealingRate(List patients) {
    if (patients.isEmpty) return 0.0;
    
    try {
      double totalImprovement = 0.0;
      int count = 0;
      
      for (final patient in patients) {
        try {
          final sessions = patient.sessions as List;
          if (sessions.length < 2) continue;
          
          final firstSession = sessions.first;
          final lastSession = sessions.last;
          
          try {
            final firstWounds = firstSession.wounds as List;
            final lastWounds = lastSession.wounds as List;
            
            if (firstWounds.isEmpty || lastWounds.isEmpty) continue;
            
            double firstTotalSize = 0.0;
            for (final wound in firstWounds) {
              try {
                final length = (wound.length as num).toDouble();
                final width = (wound.width as num).toDouble();
                firstTotalSize += length * width;
              } catch (e) {
                continue;
              }
            }
            final firstAvgSize = firstTotalSize / firstWounds.length;
            
            double lastTotalSize = 0.0;
            for (final wound in lastWounds) {
              try {
                final length = (wound.length as num).toDouble();
                final width = (wound.width as num).toDouble();
                lastTotalSize += length * width;
              } catch (e) {
                continue;
              }
            }
            final lastAvgSize = lastTotalSize / lastWounds.length;
            
            if (firstAvgSize > 0) {
              final improvement = ((firstAvgSize - lastAvgSize) / firstAvgSize) * 100;
              totalImprovement += improvement.clamp(0.0, 100.0);
              count++;
            }
          } catch (e) {
            continue;
          }
        } catch (e) {
          continue;
        }
      }
      
      return count > 0 ? totalImprovement / count : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  int _calculateSessionsThisMonth(List patients) {
    if (patients.isEmpty) return 0;
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      int total = 0;
      for (final patient in patients) {
        try {
          final sessions = patient.sessions as List;
          for (final sessionData in sessions) {
            try {
              final date = sessionData.date as DateTime;
              if (date.isAfter(startOfMonth)) {
                total++;
              }
            } catch (e) {
              continue;
            }
          }
        } catch (e) {
          continue;
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}

class _StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final String? trend;
  final bool trendPositive;

  _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.trend,
    this.trendPositive = true,
  });
}
