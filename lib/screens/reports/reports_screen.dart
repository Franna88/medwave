import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../models/progress_metrics.dart';
import '../../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  String _selectedPeriod = '30'; // days

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );
    _fadeAnimationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildModernHeader(),
          Expanded(
            child: Consumer<PatientProvider>(
              builder: (context, patientProvider, child) {
                if (patientProvider.isLoading || _isLoading) {
                  return _buildLoadingState();
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildModernOverviewTab(patientProvider),
                      _buildModernProgressTab(patientProvider),
                      _buildModernPatientsTab(patientProvider),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header content with title and buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reports & Analytics',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPeriodDescription(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Period filter button
                  _buildPeriodFilterButton(),
                ],
              ),
            ),
            // Tab bar
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.secondaryColor,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 20)),
                  Tab(text: 'Progress', icon: Icon(Icons.trending_up, size: 20)),
                  Tab(text: 'Patients', icon: Icon(Icons.people_outline, size: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilterButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.tune, color: AppTheme.textColor, size: 20),
      ),
      onSelected: (value) {
        setState(() {
          _isLoading = true;
          _selectedPeriod = value;
        });
        
        HapticFeedback.lightImpact();
        
        // Simulate loading delay for smooth transition
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '7',
          child: Row(
            children: [
              Icon(
                Icons.calendar_view_week,
                color: _selectedPeriod == '7' ? AppTheme.primaryColor : AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Last 7 days',
                style: TextStyle(
                  color: _selectedPeriod == '7' ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: '30',
          child: Row(
            children: [
              Icon(
                Icons.calendar_view_month,
                color: _selectedPeriod == '30' ? AppTheme.primaryColor : AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Last 30 days',
                style: TextStyle(
                  color: _selectedPeriod == '30' ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: '90',
          child: Row(
            children: [
              Icon(
                Icons.date_range,
                color: _selectedPeriod == '90' ? AppTheme.primaryColor : AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Last 90 days',
                style: TextStyle(
                  color: _selectedPeriod == '90' ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'all',
          child: Row(
            children: [
              Icon(
                Icons.all_inclusive,
                color: _selectedPeriod == 'all' ? AppTheme.primaryColor : AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'All time',
                style: TextStyle(
                  color: _selectedPeriod == 'all' ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Generating reports...',
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodDescription() {
    switch (_selectedPeriod) {
      case '7':
        return 'Showing data from the last 7 days';
      case '30':
        return 'Showing data from the last 30 days';
      case '90':
        return 'Showing data from the last 90 days';
      case 'all':
        return 'Showing all available data';
      default:
        return 'Comprehensive analytics dashboard';
    }
  }

  Widget _buildModernOverviewTab(PatientProvider patientProvider) {
    final patients = patientProvider.patients;
    final totalPatients = patients.length;
    final totalSessions = patients.fold<int>(0, (sum, patient) => sum + patient.sessions.length);
    final patientsWithImprovement = patients.where((p) => p.hasImprovement).length;
    final averagePainReduction = patients.isNotEmpty
        ? patients.map((p) => p.painReductionPercentage).reduce((a, b) => a + b) / patients.length
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernOverviewStats(
              totalPatients,
              totalSessions,
              patientsWithImprovement,
              averagePainReduction,
            ),
            const SizedBox(height: 24),
            _buildModernTreatmentOutcomesChart(patients),
            const SizedBox(height: 24),
            _buildModernSessionDistributionChart(patients),
            const SizedBox(height: 24),
            _buildModernRecentAchievements(patients),
            const SizedBox(height: 100), // Space for potential FAB
          ],
        ),
      ),
    );
  }

  Widget _buildModernOverviewStats(int totalPatients, int totalSessions, int improving, double avgPainReduction) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                'Total Patients',
                totalPatients.toString(),
                Icons.people_outline,
                AppTheme.infoColor,
                'Active patients in system',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernStatCard(
                'Total Sessions',
                totalSessions.toString(),
                Icons.event_note_outlined,
                AppTheme.primaryColor,
                'Completed treatment sessions',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                'Improving',
                improving.toString(),
                Icons.trending_up,
                AppTheme.successColor,
                'Patients showing improvement',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernStatCard(
                'Avg. Pain Reduction',
                '${avgPainReduction.toStringAsFixed(1)}%',
                Icons.healing_outlined,
                AppTheme.warningColor,
                'Average across all patients',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: Icon(icon, size: 24, color: color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    size: 12,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTreatmentOutcomesChart(List<Patient> patients) {
    if (patients.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  size: 48,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No treatment data available',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final improving = patients.where((p) => p.hasImprovement).length;
    final stable = patients.where((p) => !p.hasImprovement && p.sessions.isNotEmpty).length;
    final newPatients = patients.where((p) => p.sessions.isEmpty).length;
    final total = patients.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Treatment Outcomes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;
                
                if (isSmallScreen) {
                  // Stack layout for small screens
                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            sections: [
                              PieChartSectionData(
                                value: improving.toDouble(),
                                title: '',
                                color: AppTheme.successColor,
                                radius: 60,
                              ),
                              PieChartSectionData(
                                value: stable.toDouble(),
                                title: '',
                                color: AppTheme.warningColor,
                                radius: 60,
                              ),
                              PieChartSectionData(
                                value: newPatients.toDouble(),
                                title: '',
                                color: AppTheme.infoColor,
                                radius: 60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOutcomeLegendItem(
                              'Improving',
                              improving,
                              total,
                              AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOutcomeLegendItem(
                              'Stable',
                              stable,
                              total,
                              AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOutcomeLegendItem(
                              'New Patients',
                              newPatients,
                              total,
                              AppTheme.infoColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Side-by-side layout for larger screens
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 50,
                              sections: [
                                PieChartSectionData(
                                  value: improving.toDouble(),
                                  title: '',
                                  color: AppTheme.successColor,
                                  radius: 60,
                                ),
                                PieChartSectionData(
                                  value: stable.toDouble(),
                                  title: '',
                                  color: AppTheme.warningColor,
                                  radius: 60,
                                ),
                                PieChartSectionData(
                                  value: newPatients.toDouble(),
                                  title: '',
                                  color: AppTheme.infoColor,
                                  radius: 60,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOutcomeLegendItem(
                              'Improving',
                              improving,
                              total,
                              AppTheme.successColor,
                            ),
                            const SizedBox(height: 16),
                            _buildOutcomeLegendItem(
                              'Stable',
                              stable,
                              total,
                              AppTheme.warningColor,
                            ),
                            const SizedBox(height: 16),
                            _buildOutcomeLegendItem(
                              'New Patients',
                              newPatients,
                              total,
                              AppTheme.infoColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeLegendItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count patients',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          '$percentage%',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildModernSessionDistributionChart(List<Patient> patients) {
    if (patients.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group patients by session count
    final sessionCounts = <int, int>{};
    for (final patient in patients) {
      final sessionCount = patient.sessions.length;
      final range = (sessionCount / 5).floor() * 5; // Group in ranges of 5
      sessionCounts[range] = (sessionCounts[range] ?? 0) + 1;
    }

    final sortedEntries = sessionCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Session Distribution',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sortedEntries.isNotEmpty 
                      ? sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 1
                      : 10,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => AppTheme.textColor.withOpacity(0.8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final range = sortedEntries[group.x].key;
                        return BarTooltipItem(
                          '${range}-${range + 4} sessions\n${rod.toY.toInt()} patients',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedEntries.length) {
                            final range = sortedEntries[index].key;
                            return Text(
                              '${range}-${range + 4}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
                      bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: sortedEntries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.8),
                              AppTheme.primaryColor,
                            ],
                          ),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRecentAchievements(List<Patient> patients) {
    final achievements = <Map<String, dynamic>>[];
    
    for (final patient in patients) {
      if (patient.painReductionPercentage > 30) {
        achievements.add({
          'patient': patient.name,
          'achievement': '${patient.painReductionPercentage.toStringAsFixed(1)}% pain reduction',
          'icon': Icons.healing,
          'color': AppTheme.successColor,
          'type': 'pain_reduction',
        });
      }
      if (patient.sessions.length >= 10) {
        achievements.add({
          'patient': patient.name,
          'achievement': 'Completed ${patient.sessions.length} sessions',
          'icon': Icons.event_available,
          'color': AppTheme.infoColor,
          'type': 'sessions',
        });
      }
      if (patient.hasImprovement) {
        achievements.add({
          'patient': patient.name,
          'achievement': 'Showing consistent improvement',
          'icon': Icons.trending_up,
          'color': AppTheme.primaryColor,
          'type': 'improvement',
        });
      }
    }

    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by type priority and take unique patients
    final uniqueAchievements = <String, Map<String, dynamic>>{};
    for (final achievement in achievements) {
      final patientName = achievement['patient'] as String;
      if (!uniqueAchievements.containsKey(patientName) || 
          achievement['type'] == 'pain_reduction') {
        uniqueAchievements[patientName] = achievement;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recent Achievements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...uniqueAchievements.values.take(5).map((achievement) => 
              _buildAchievementItem(
                achievement['patient'] as String,
                achievement['achievement'] as String,
                achievement['icon'] as IconData,
                achievement['color'] as Color,
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(String patient, String achievement, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
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
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernProgressTab(PatientProvider patientProvider) {
    final patients = patientProvider.patients;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProgressSummaryStats(patients),
            const SizedBox(height: 24),
            _buildModernAveragePainReductionChart(patients),
            const SizedBox(height: 24),
            _buildModernWeightChangeChart(patients),
            const SizedBox(height: 24),
            _buildModernSessionEffectivenessChart(patients),
            const SizedBox(height: 100), // Space for potential FAB
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryStats(List<Patient> patients) {
    if (patients.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate overall statistics
    final totalSessions = patients.fold<int>(0, (sum, patient) => sum + patient.sessions.length);
    final averagePainReduction = patients.isNotEmpty
        ? patients.map((p) => p.painReductionPercentage).reduce((a, b) => a + b) / patients.length
        : 0.0;
    
    final patientsWithWeightData = patients.where((p) => p.currentWeight != null).length;
    final averageWeightChange = patientsWithWeightData > 0
        ? patients.where((p) => p.currentWeight != null)
            .map((p) => p.weightChangePercentage)
            .reduce((a, b) => a + b) / patientsWithWeightData
        : 0.0;

    final averageSessionsPerPatient = patients.isNotEmpty ? totalSessions / patients.length : 0.0;
    final patientsImproving = patients.where((p) => p.hasImprovement).length;
    final improvementRate = patients.isNotEmpty ? (patientsImproving / patients.length) * 100 : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildProgressStatCard(
                'Average Pain Reduction',
                '${averagePainReduction.toStringAsFixed(1)}%',
                Icons.healing_outlined,
                AppTheme.successColor,
                averagePainReduction > 30 ? 'Excellent progress' : 'Steady improvement',
                averagePainReduction / 100,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProgressStatCard(
                'Improvement Rate',
                '${improvementRate.toStringAsFixed(1)}%',
                Icons.trending_up,
                AppTheme.primaryColor,
                '$patientsImproving of ${patients.length} patients',
                improvementRate / 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildProgressStatCard(
                'Avg Sessions/Patient',
                averageSessionsPerPatient.toStringAsFixed(1),
                Icons.event_note_outlined,
                AppTheme.infoColor,
                '$totalSessions total sessions',
                (averageSessionsPerPatient / 20).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProgressStatCard(
                'Weight Change',
                '${averageWeightChange > 0 ? '+' : ''}${averageWeightChange.toStringAsFixed(1)}%',
                Icons.monitor_weight_outlined,
                averageWeightChange.abs() > 5 ? AppTheme.warningColor : AppTheme.successColor,
                '$patientsWithWeightData patients tracked',
                (averageWeightChange.abs() / 10).clamp(0.0, 1.0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressStatCard(String title, String value, IconData icon, Color color, String subtitle, double progress) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: Icon(icon, size: 24, color: color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    progress > 0.7 ? Icons.trending_up : Icons.trending_flat,
                    size: 12,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAveragePainReductionChart(List<Patient> patients) {
    if (patients.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No pain reduction data available',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate average pain reduction over time
    final Map<int, List<double>> painBySession = {};
    
    for (final patient in patients) {
      for (int i = 0; i < patient.sessions.length; i++) {
        final session = patient.sessions[i];
        final painReduction = ((patient.baselineVasScore - session.vasScore) / patient.baselineVasScore) * 100;
        
        if (!painBySession.containsKey(i + 1)) {
          painBySession[i + 1] = [];
        }
        painBySession[i + 1]!.add(painReduction);
      }
    }

    final averagePainReduction = painBySession.entries.map((entry) {
      final sessionNumber = entry.key;
      final painReductions = entry.value;
      final average = painReductions.reduce((a, b) => a + b) / painReductions.length;
      return FlSpot(sessionNumber.toDouble(), average);
    }).toList();

    // Calculate key metrics
    final totalImprovement = averagePainReduction.isNotEmpty ? averagePainReduction.last.y : 0.0;
    final trendDirection = averagePainReduction.length > 1 
        ? (averagePainReduction.last.y > averagePainReduction.first.y ? 'improving' : 'declining')
        : 'stable';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Average Pain Reduction Over Time',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: trendDirection == 'improving' 
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trendDirection == 'improving' ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 12,
                                  color: trendDirection == 'improving' 
                                      ? AppTheme.successColor 
                                      : AppTheme.warningColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${totalImprovement.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: trendDirection == 'improving' 
                                        ? AppTheme.successColor 
                                        : AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current average improvement',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Transform.rotate(
                            angle: -0.5, // Rotate text by -0.5 radians (about -28.6 degrees)
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Session ${value.toInt()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
                      bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.3)),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: averagePainReduction,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.successColor.withOpacity(0.8),
                          AppTheme.successColor,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: AppTheme.successColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successColor.withOpacity(0.1),
                            AppTheme.successColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernWeightChangeChart(List<Patient> patients) {
    final patientsWithWeightData = patients.where((p) => 
      p.currentWeight != null && p.sessions.isNotEmpty
    ).toList();

    if (patientsWithWeightData.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.monitor_weight_outlined,
                  size: 48,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No weight data available',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate weight change statistics
    final totalPatients = patientsWithWeightData.length;
    final averageWeightChange = patientsWithWeightData.fold<double>(0, 
        (sum, patient) => sum + patient.weightChangePercentage) / totalPatients;
    final significantChanges = patientsWithWeightData
        .where((p) => p.weightChangePercentage.abs() > 5).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weight Changes Distribution',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalPatients patients tracked • Avg: ${averageWeightChange.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (significantChanges > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '$significantChanges significant changes',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: patientsWithWeightData.map((patient) {
                    final weightChange = patient.weightChangePercentage;
                    final color = weightChange.abs() > 5 
                        ? (weightChange > 0 ? AppTheme.warningColor : AppTheme.infoColor)
                        : AppTheme.successColor;
                    
                    final isSignificant = weightChange.abs() > 5;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(isSignificant ? 0.3 : 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    patient.name.split(' ').map((n) => n[0]).take(2).join(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isSignificant 
                                          ? 'Significant change detected'
                                          : 'Normal weight variation',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  if (isSignificant)
                                    Icon(
                                      weightChange > 0 ? Icons.trending_up : Icons.trending_down,
                                      size: 16,
                                      color: color,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (weightChange.abs() / 20).clamp(0.0, 1.0),
                              backgroundColor: color.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSessionEffectivenessChart(List<Patient> patients) {
    if (patients.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate effectiveness based on improvement per session
    final effectivenessData = patients.where((p) => p.sessions.isNotEmpty).map((patient) {
      final improvement = patient.painReductionPercentage;
      final sessions = patient.sessions.length;
      final effectiveness = sessions > 0 ? improvement / sessions : 0;
      return {
        'name': patient.name,
        'firstName': patient.name.split(' ').first,
        'effectiveness': effectiveness,
        'sessions': sessions,
        'improvement': improvement,
      };
    }).toList()..sort((a, b) => (b['effectiveness'] as double).compareTo(a['effectiveness'] as double));

    final averageEffectiveness = effectivenessData.isNotEmpty 
        ? effectivenessData.fold<double>(0, (sum, data) => sum + (data['effectiveness'] as double)) / effectivenessData.length
        : 0.0;
    
    final topPerformers = effectivenessData.where((data) => (data['effectiveness'] as double) > averageEffectiveness).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.speed,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Treatment Effectiveness',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Improvement rate per session • Avg: ${averageEffectiveness.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (topPerformers > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '$topPerformers above average',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ...effectivenessData.take(8).map((data) {
              final effectiveness = data['effectiveness'] as double;
              final name = data['name'] as String;
              final sessions = data['sessions'] as int;
              final improvement = data['improvement'] as double;
              final isAboveAverage = effectiveness > averageEffectiveness;
              
              final effectivenessColor = isAboveAverage 
                  ? AppTheme.successColor 
                  : AppTheme.primaryColor;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: effectivenessColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: effectivenessColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                effectivenessColor.withOpacity(0.8),
                                effectivenessColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              name.split(' ').map((n) => n[0]).take(2).join(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$sessions sessions • ${improvement.toStringAsFixed(1)}% total improvement',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${effectiveness.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: effectivenessColor,
                              ),
                            ),
                            Text(
                              'per session',
                              style: TextStyle(
                                fontSize: 10,
                                color: effectivenessColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isAboveAverage)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  size: 12,
                                  color: AppTheme.successColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (effectiveness / (averageEffectiveness * 2)).clamp(0.0, 1.0),
                        backgroundColor: effectivenessColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(effectivenessColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPatientsTab(PatientProvider patientProvider) {
    final patients = patientProvider.patients;

    if (patients.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No patients available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add patients to see their progress reports',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isSmallScreen = screenWidth < 400;
          final padding = isSmallScreen ? 16.0 : 20.0;
          
          return ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final progress = patientProvider.calculateProgress(patient.id);
              return AnimatedContainer(
                duration: Duration(milliseconds: 100 + (index * 50)),
                curve: Curves.easeOutBack,
                child: _buildModernPatientReportCard(patient, progress, index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModernPatientReportCard(Patient patient, ProgressMetrics progress, int index) {
    final progressColor = patient.hasImprovement 
        ? AppTheme.successColor 
        : AppTheme.infoColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // Navigate to patient details
          },
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 400;
              final padding = isSmallScreen ? 16.0 : 20.0;
              
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 350;
                    
                    return Column(
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'patient_report_${patient.id}',
                              child: Container(
                                width: isSmallScreen ? 45 : 50,
                                height: isSmallScreen ? 45 : 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      progressColor.withOpacity(0.8),
                                      progressColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: progressColor.withOpacity(0.3),
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    patient.name.split(' ').map((n) => n[0]).take(2).join(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.name,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_note_outlined,
                                        size: 12,
                                        color: AppTheme.secondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${patient.sessions.length} sessions completed',
                                          style: TextStyle(
                                            color: AppTheme.secondaryColor,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (patient.hasImprovement) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 12, 
                                vertical: isSmallScreen ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.successColor.withOpacity(0.1),
                                    AppTheme.successColor.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.successColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    size: 12,
                                    color: AppTheme.successColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Improving',
                                    style: TextStyle(
                                      color: AppTheme.successColor,
                                      fontSize: isSmallScreen ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 350;
                    
                    if (isSmallScreen) {
                      // Stack layout for very small screens
                      return Column(
                        children: [
                          _buildModernProgressMetric(
                            'Pain Reduction',
                            '${progress.painReductionPercentage.toStringAsFixed(1)}%',
                            progress.painReductionPercentage / 100,
                            AppTheme.successColor,
                            Icons.healing_outlined,
                            isCompact: true,
                          ),
                          const SizedBox(height: 12),
                          _buildModernProgressMetric(
                            'Weight Change',
                            '${progress.weightChangePercentage.toStringAsFixed(1)}%',
                            progress.weightChangePercentage.abs() / 20, // Normalize to 20% max
                            progress.weightChangePercentage.abs() > 5 
                                ? AppTheme.warningColor 
                                : AppTheme.infoColor,
                            Icons.monitor_weight_outlined,
                            isCompact: true,
                          ),
                        ],
                      );
                    } else {
                      // Side-by-side layout for larger screens
                      return Row(
                        children: [
                          Expanded(
                            child: _buildModernProgressMetric(
                              'Pain Reduction',
                              '${progress.painReductionPercentage.toStringAsFixed(1)}%',
                              progress.painReductionPercentage / 100,
                              AppTheme.successColor,
                              Icons.healing_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModernProgressMetric(
                              'Weight Change',
                              '${progress.weightChangePercentage.toStringAsFixed(1)}%',
                              progress.weightChangePercentage.abs() / 20, // Normalize to 20% max
                              progress.weightChangePercentage.abs() > 5 
                                  ? AppTheme.warningColor 
                                  : AppTheme.infoColor,
                              Icons.monitor_weight_outlined,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                if (progress.improvementSummary.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.infoColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 16,
                          color: AppTheme.infoColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            progress.improvementSummary,
                            style: TextStyle(
                              color: AppTheme.infoColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernProgressMetric(String label, String value, double progress, Color color, IconData icon, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: isCompact 
          ? Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: color.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
    );
  }
}
