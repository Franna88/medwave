import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import '../providers/patient_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/appointment_provider.dart';
import '../models/patient.dart';
import '../models/notification.dart';
import '../services/firebase/patient_service.dart';
import '../models/appointment.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../screens/calendar/widgets/add_appointment_dialog.dart';

class ResponsiveDashboardContent extends StatelessWidget {
  const ResponsiveDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PatientProvider, NotificationProvider>(
      builder: (context, patientProvider, notificationProvider, child) {
        if (patientProvider.isLoading || notificationProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ResponsiveUtils.shouldUseHorizontalLayout(context)) {
          return _buildTabletLayout(context, patientProvider, notificationProvider);
        } else {
          return _buildMobileLayout(context, patientProvider, notificationProvider);
        }
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context, PatientProvider patientProvider, NotificationProvider notificationProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          patientProvider.loadPatients(),
          notificationProvider.loadNotifications(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildTabletWelcomeSection(),
            const SizedBox(height: 32),
            
            // Stats Cards Grid
            _buildTabletStatsGrid(patientProvider),
            const SizedBox(height: 32),
            
            // Main Content Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildTabletNotificationsCard(notificationProvider),
                      const SizedBox(height: 24),
                      _buildTabletUpcomingAppointments(patientProvider),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                
                // Right Column
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildTabletQuickActions(context),
                      const SizedBox(height: 24),
                      _buildTabletRecentPatients(patientProvider),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, PatientProvider patientProvider, NotificationProvider notificationProvider) {
    // Return the original mobile layout structure with modern header
    return Column(
      children: [
        _buildMobileDashboardHeader(context, patientProvider),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                patientProvider.loadPatients(),
                notificationProvider.loadNotifications(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStatsCards(patientProvider),
                  ),
                  const SizedBox(height: 32),
                  _buildNotificationsSection(notificationProvider),
                  const SizedBox(height: 32),
                  _buildUpcomingAppointments(patientProvider),
                  const SizedBox(height: 32),
                  _buildRecentlyUpdatedPatients(patientProvider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDashboardHeader(BuildContext context, PatientProvider patientProvider) {
    final now = DateTime.now();
    final timeOfDay = now.hour < 12 ? 'Morning' : now.hour < 17 ? 'Afternoon' : 'Evening';
    
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good $timeOfDay',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ready to help your patients heal better?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: Colors.white.withOpacity(0.9),
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick stats row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 75, // Reduced height to prevent overflow
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            patientProvider.patients.length.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Text(
                            'Total Patients',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 75, // Reduced height to prevent overflow
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            patientProvider.patientsWithImprovement.length.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          const Text(
                            'Improving',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 75, // Reduced height to prevent overflow
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FutureBuilder<int>(
                            future: _getTotalSessionsCount(patientProvider.patients),
                            builder: (context, snapshot) {
                              final totalSessions = snapshot.hasData ? snapshot.data! : 0;
                              return Text(
                                totalSessions.toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.infoColor,
                                ),
                              );
                            },
                          ),
                          const Text(
                            'Sessions',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletWelcomeSection() {
    final now = DateTime.now();
    final timeOfDay = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeOfDay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to help your patients heal better?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Add New Patient'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              size: 60,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletStatsGrid(PatientProvider patientProvider) {
    final patients = patientProvider.patients;
    final totalPatients = patients.length;
    final improvingPatients = patients.where((p) => p.sessions.isNotEmpty && 
        p.woundHealingProgress != null && p.woundHealingProgress! > 0).length;
    
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Patients', totalPatients.toString(), Icons.people, AppTheme.primaryColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Improving', improvingPatients.toString(), Icons.trending_up, AppTheme.greenColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Total Sessions', patientProvider.totalSessionCount.toString(), Icons.assignment, AppTheme.pinkColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('This Month', '12', Icons.calendar_today, AppTheme.redColor)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 156, // Fixed height for consistency
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(Icons.more_horiz, color: AppTheme.secondaryColor.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryColor.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletNotificationsCard(NotificationProvider notificationProvider) {
    final notifications = notificationProvider.notifications.take(5).toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...notifications.map((notification) => _buildNotificationItem(notification)),
        ],
      ),
    );
  }

  Widget _buildTabletUpcomingAppointments(PatientProvider patientProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder for appointments
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No upcoming appointments',
                style: TextStyle(
                  color: AppTheme.secondaryColor.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.person_add, 'label': 'Add Patient', 'route': '/patients/add'},
      {'icon': Icons.calendar_today, 'label': 'Schedule', 'action': 'add_appointment'},
      {'icon': Icons.bar_chart, 'label': 'Reports', 'route': '/reports'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          ...actions.map((action) => _buildQuickActionItem(context, action)),
        ],
      ),
    );
  }

  Widget _buildTabletRecentPatients(PatientProvider patientProvider) {
    final recentPatients = patientProvider.patients.take(4).toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          ...recentPatients.map((patient) => _buildRecentPatientItem(patient)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getNotificationColor(notification.type),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(notification.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(BuildContext context, Map<String, dynamic> action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle custom actions or navigation
            if (action.containsKey('action')) {
              final actionType = action['action'] as String;
              if (actionType == 'add_appointment') {
                _showAddAppointmentDialog(context);
              }
            } else if (action.containsKey('route')) {
              final route = action['route'] as String;
              if (route.isNotEmpty) {
                // Use GoRouter for navigation
                GoRouter.of(context).push(route);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor.withOpacity(0.2),
              ),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    action['icon'],
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    action['label'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.secondaryColor.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPatientItem(Patient patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              patient.name[0].toUpperCase(),
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  patient.baselineWounds.isNotEmpty ? patient.baselineWounds.first.type : 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.improvement:
        return AppTheme.greenColor;
      case NotificationType.appointment:
        return AppTheme.primaryColor;
      case NotificationType.reminder:
        return AppTheme.pinkColor;
      case NotificationType.alert:
        return AppTheme.redColor;
    }
  }

  // Mobile layout methods (simplified versions of existing dashboard methods)

  Widget _buildStatsCards(PatientProvider patientProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Patients', patientProvider.patients.length.toString(), Icons.people, AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('Sessions', patientProvider.totalSessionCount.toString(), Icons.assignment, AppTheme.greenColor),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(NotificationProvider notificationProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...notificationProvider.notifications.take(3).map((n) => _buildNotificationItem(n)),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments(PatientProvider patientProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text('No upcoming appointments'),
        ],
      ),
    );
  }

  Widget _buildRecentlyUpdatedPatients(PatientProvider patientProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...patientProvider.patients.take(3).map((p) => _buildRecentPatientItem(p)),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 600,
            height: 700,
            child: AddAppointmentDialog(
              selectedDate: DateTime.now(),
              onAppointmentAdded: (Appointment appointment) {
                // Add the appointment to the provider
                context.read<AppointmentProvider>().addAppointment(appointment);
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Appointment scheduled for ${appointment.patientName}'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<int> _getTotalSessionsCount(List<Patient> patients) async {
    int totalSessions = 0;
    for (Patient patient in patients) {
      final sessions = await PatientService.getPatientSessions(patient.id);
      totalSessions += sessions.length;
    }
    return totalSessions;
  }
}
