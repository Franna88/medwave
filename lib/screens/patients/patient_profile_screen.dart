import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../widgets/firebase_image.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../models/progress_metrics.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_utils.dart';
import '../../utils/responsive_utils.dart';
import '../../services/wound_management_service.dart';
import '../../widgets/session_restriction_card.dart';

enum PhotoType { baseline, session, wound }

class PhotoItem {
  final String photoPath;
  final PhotoType type;
  final DateTime timestamp;
  final int? sessionNumber;
  final String label;

  PhotoItem({
    required this.photoPath,
    required this.type,
    required this.timestamp,
    this.sessionNumber,
    required this.label,
  });
}

class PatientProfileScreen extends StatefulWidget {
  final String patientId;

  const PatientProfileScreen({super.key, required this.patientId});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;

  final ScrollController _scrollController = ScrollController();
  bool _isHeaderExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    
    _scrollController.addListener(_onScroll);
    _headerAnimationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patientProvider = context.read<PatientProvider>();
      final patient = await patientProvider.getPatient(widget.patientId);
      if (patient != null) {
        patientProvider.selectPatient(patient);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    const threshold = 100.0;
    final shouldExpand = _scrollController.offset < threshold;
    
    if (shouldExpand != _isHeaderExpanded) {
      setState(() {
        _isHeaderExpanded = shouldExpand;
      });
      
      if (_isHeaderExpanded) {
        _headerAnimationController.forward();
      } else {
        _headerAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        final patient = patientProvider.selectedPatient;
        
        if (patient == null) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              title: const Text('Patient Profile'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildModernHeader(patient),
              ];
            },
            body: _buildTabBarView(patient, patientProvider),
          ),
          floatingActionButton: _buildModernFAB(patient),
        );
      },
    );
  }

  Widget _buildModernHeader(Patient patient) {
    final progressColor = patient.hasImprovement 
        ? AppTheme.successColor 
        : AppTheme.primaryColor;

    return SliverAppBar(
      expandedHeight: 280, // Reduced height for essential content only
      collapsedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Text(
        patient.name ?? 'Unknown Patient',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
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
          child: const Icon(Icons.arrow_back, color: AppTheme.textColor),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
      ),
      actions: [
        Tooltip(
          message: 'Export Progress Report',
          child: IconButton(
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
              child: const Icon(Icons.file_download_outlined, color: AppTheme.textColor),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _exportPatientProgress(patient);
            },
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Edit Patient',
          child: IconButton(
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
              child: const Icon(Icons.edit, color: AppTheme.textColor),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              // Navigate to edit patient screen
            },
          ),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                progressColor.withOpacity(0.08),
                Colors.white,
              ],
            ),
          ),
                                           child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20), // Reduced padding
                child: Column(
                  children: [
                    // Patient Avatar and Basic Info
                    Row(
                      children: [
                        // Enhanced Avatar
                        Hero(
                          tag: 'patient_avatar_${patient.id}',
                          child: Container(
                            width: 70,
                            height: 70,
                           decoration: BoxDecoration(
                             gradient: LinearGradient(
                               colors: [
                                 progressColor.withOpacity(0.8),
                                 progressColor,
                               ],
                               begin: Alignment.topLeft,
                               end: Alignment.bottomRight,
                             ),
                             borderRadius: BorderRadius.circular(18),
                             boxShadow: [
                               BoxShadow(
                                 color: progressColor.withOpacity(0.3),
                                 offset: const Offset(0, 6),
                                 blurRadius: 12,
                               ),
                             ],
                           ),
                           child: Center(
                             child: Text(
                               _getPatientInitials(patient.name),
                               style: const TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 24,
                               ),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 16),
                       
                       // Patient Info
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               patient.name ?? 'Unknown Patient',
                               style: const TextStyle(
                                 fontSize: 22,
                                 fontWeight: FontWeight.bold,
                                 color: AppTheme.textColor,
                               ),
                             ),
                             const SizedBox(height: 4),
                             Text(
                               'Age ${patient.age} • ${patient.medicalAid ?? 'No Medical Aid'}',
                               style: TextStyle(
                                 fontSize: 13,
                                 color: AppTheme.secondaryColor.withOpacity(0.8),
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                             const SizedBox(height: 6),
                             Row(
                               children: [
                                 Icon(
                                   Icons.event_note,
                                   size: 14,
                                   color: AppTheme.primaryColor.withOpacity(0.7),
                                 ),
                                 const SizedBox(width: 4),
                                                                 FutureBuilder<List<Session>>(
                                  future: context.read<PatientProvider>().getPatientSessions(patient.id),
                                  builder: (context, snapshot) {
                                    final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
                                    return Text(
                                      '$sessionCount sessions',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.primaryColor.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                               ],
                             ),
                           ],
                         ),
                       ),
                       
                       // Status Badge
                       _buildStatusBadge(patient),
                     ],
                   ),
                   
                   const SizedBox(height: 16), // Reduced spacing
                    
                   // Essential Quick Stats Row
                  //  Row(
                  //    children: [
                  //      Expanded(
                  //        child: _buildQuickStat(
                  //          'Pain',
                  //          '${patient.currentVasScore ?? 'N/A'}/10',
                  //          Icons.healing_outlined,
                  //          _getPainColor(patient.currentVasScore ?? 0),
                  //        ),
                  //      ),
                  //      const SizedBox(width: 8), // Reduced spacing
                  //      Expanded(
                  //        child: _buildQuickStat(
                  //          'Weight',
                  //          '${patient.currentWeight?.toStringAsFixed(1) ?? 'N/A'} kg',
                  //          Icons.monitor_weight_outlined,
                  //          AppTheme.infoColor,
                  //        ),
                  //      ),
                  //    ],
                  //  ),
                 ],
               ),
             ),
           ),
        ),
      ),
                    bottom: PreferredSize(
         preferredSize: const Size.fromHeight(45), // Further reduced height
         child: Container(
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.05),
                 blurRadius: 8,
                 offset: const Offset(0, -2),
               ),
             ],
           ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.secondaryColor.withOpacity(0.6),
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
                         labelStyle: const TextStyle(
               fontWeight: FontWeight.w600,
               fontSize: 11, // Smaller font
             ),
             unselectedLabelStyle: const TextStyle(
               fontWeight: FontWeight.w500,
               fontSize: 11, // Smaller font
             ),
                         tabs: const [
               Tab(text: 'Overview', icon: Icon(Icons.person_outline, size: 16)), // Smaller icons
               Tab(text: 'Progress', icon: Icon(Icons.trending_up, size: 16)),
               Tab(text: 'Sessions', icon: Icon(Icons.history, size: 16)),
               Tab(text: 'Photos', icon: Icon(Icons.photo_library_outlined, size: 16)),
             ],
          ),
        ),
       ),
    );
  }

  Widget _buildStatusBadge(Patient patient) {
    if (patient.hasImprovement) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.successColor.withOpacity(0.15),
              AppTheme.successColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.successColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up,
              size: 16,
              color: AppTheme.successColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Improving',
              style: TextStyle(
                color: AppTheme.successColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warningColor.withOpacity(0.15),
              AppTheme.warningColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.warningColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_down,
              size: 16,
              color: AppTheme.warningColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Stable',
              style: TextStyle(
                color: AppTheme.warningColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.all(8), // Further reduced padding
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.08),
  //       borderRadius: BorderRadius.circular(10),
  //       border: Border.all(
  //         color: color.withOpacity(0.2),
  //         width: 1,
  //       ),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, size: 16, color: color), // Smaller icon
  //         const SizedBox(height: 4), // Reduced spacing
  //         Text(
  //           value,
  //           style: TextStyle(
  //             fontSize: 13, // Smaller font
  //             fontWeight: FontWeight.bold,
  //             color: color,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //         const SizedBox(height: 2),
  //         Text(
  //           label,
  //           style: TextStyle(
  //             fontSize: 9, // Smaller font
  //             color: color.withOpacity(0.8),
  //             fontWeight: FontWeight.w500,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildTabBarView(Patient patient, PatientProvider patientProvider) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildModernOverviewTab(patient, patientProvider),
          _buildModernProgressTab(patient, patientProvider),
          _buildModernSessionsTab(patient),
          _buildModernPhotosTab(patient),
        ],
      ),
    );
  }

  Widget _buildModernFAB(Patient patient) {
    // Don't show FAB for session logging on web platform
    if (ResponsiveUtils.shouldRestrictSessions()) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Session>>(
      future: context.read<PatientProvider>().getPatientSessions(patient.id),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        final hasNoSessions = sessions.isEmpty;
        
        return FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            if (hasNoSessions) {
              context.push('/patients/${patient.id}/wound-selection?name=${Uri.encodeComponent(patient.fullNames + ' ' + patient.surname)}');
            } else {
              // Smart routing based on wound count
              final sessionRoute = WoundManagementService.getSessionLoggingRoute(patient.id, patient);
              context.push(sessionRoute);
            }
          },
          backgroundColor: hasNoSessions ? AppTheme.warningColor : AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          icon: Icon(hasNoSessions ? Icons.assignment_turned_in : Icons.add),
          label: Text(
            hasNoSessions ? 'Case History' : 'New Session',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget _buildModernOverviewTab(Patient patient, PatientProvider patientProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernPatientInfoCard(patient),
          const SizedBox(height: 20),
          _buildModernPersonalDetailsCard(patient),
          const SizedBox(height: 20),
          _buildModernResponsiblePersonCard(patient),
          const SizedBox(height: 20),
          _buildModernMedicalAidCard(patient),
          const SizedBox(height: 20),
          _buildModernMedicalHistoryCard(patient),
          const SizedBox(height: 20),
          _buildModernConsentCard(patient),
          const SizedBox(height: 20),
          _buildModernQuickStatsCardAsync(patient, patientProvider),
          const SizedBox(height: 20),
          _buildModernCurrentStatusCardAsync(patient, patientProvider),
          const SizedBox(height: 20),
          _buildModernNextAppointmentCard(patient),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildModernPatientInfoCard(Patient patient) {
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
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            _buildModernInfoRow(Icons.email_outlined, 'Email', patient.email),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.phone_android_outlined, 'Cell Phone', patient.patientCell),
            const SizedBox(height: 16),
            if (patient.homeTelNo != null && patient.homeTelNo!.isNotEmpty)
              _buildModernInfoRow(Icons.phone_outlined, 'Home Phone', patient.homeTelNo!),
            const SizedBox(height: 16),
            _buildModernInfoRow(
              Icons.calendar_today_outlined,
              'Started Treatment',
              DateFormat('MMM d, yyyy').format(patient.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPersonalDetailsCard(Patient patient) {
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
                  child: Icon(Icons.person_outline, size: 20, color: AppTheme.infoColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernInfoRow(Icons.badge_outlined, 'ID Number', patient.idNumber),
            const SizedBox(height: 16),
            _buildModernInfoRow(
              Icons.calendar_today_outlined, 
              'Date of Birth', 
              DateFormat('MMM d, yyyy').format(patient.dateOfBirth)
            ),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.cake_outlined, 'Age', '${patient.age} years old'),
            if (patient.maritalStatus != null && patient.maritalStatus!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.favorite_outline, 'Marital Status', patient.maritalStatus!.toUpperCase()),
            ],
            if (patient.occupation != null && patient.occupation!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.work_outline, 'Occupation', patient.occupation!),
            ],
            if (patient.workNameAndAddress != null && patient.workNameAndAddress!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.business_outlined, 'Work Address', patient.workNameAndAddress!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernResponsiblePersonCard(Patient patient) {
    // Only show if responsible person is different from patient
    final isDifferentPerson = patient.responsiblePersonIdNumber != patient.idNumber;
    
    if (!isDifferentPerson) {
      return const SizedBox.shrink(); // Don't show if same person
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
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.family_restroom, size: 20, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Responsible Person',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernInfoRow(
              Icons.person_outline, 
              'Name', 
              '${patient.responsiblePersonFullNames} ${patient.responsiblePersonSurname}'
            ),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.badge_outlined, 'ID Number', patient.responsiblePersonIdNumber),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.phone_android_outlined, 'Cell Phone', patient.responsiblePersonCell),
            if (patient.relationToPatient != null && patient.relationToPatient!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.link_outlined, 'Relation to Patient', patient.relationToPatient!),
            ],
            if (patient.responsiblePersonEmail != null && patient.responsiblePersonEmail!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.email_outlined, 'Email', patient.responsiblePersonEmail!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernMedicalAidCard(Patient patient) {
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
                  child: Icon(Icons.medical_services_outlined, size: 20, color: AppTheme.successColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Medical Aid Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernInfoRow(Icons.local_hospital_outlined, 'Scheme Name', patient.medicalAidSchemeName),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.credit_card_outlined, 'Member Number', patient.medicalAidNumber),
            const SizedBox(height: 16),
            _buildModernInfoRow(Icons.person_outline, 'Main Member', patient.mainMemberName),
            if (patient.planAndDepNumber != null && patient.planAndDepNumber!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.description_outlined, 'Plan & DEP No', patient.planAndDepNumber!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernMedicalHistoryCard(Patient patient) {
    final activeConditions = patient.medicalConditions.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

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
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medical_information_outlined, size: 20, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Medical History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Medical Conditions
            if (activeConditions.isNotEmpty) ...[
              const Text(
                'Medical Conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeConditions.map((condition) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    condition.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Smoking Status
            Row(
              children: [
                Icon(
                  patient.isSmoker ? Icons.smoking_rooms : Icons.smoke_free,
                  size: 20,
                  color: patient.isSmoker ? AppTheme.errorColor : AppTheme.successColor,
                ),
                const SizedBox(width: 8),
                Text(
                  patient.isSmoker ? 'Smoker' : 'Non-Smoker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: patient.isSmoker ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
              ],
            ),
            
            // Current Medications
            if (patient.currentMedications != null && patient.currentMedications!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.medication_outlined, 'Current Medications', patient.currentMedications!),
            ],
            
            // Allergies
            if (patient.allergies != null && patient.allergies!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernInfoRow(Icons.warning_amber_outlined, 'Allergies', patient.allergies!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernConsentCard(Patient patient) {
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
            Column(
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
                      child: Icon(Icons.verified_user_outlined, size: 20, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Consent & Legal Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Account Responsibility
            Row(
              children: [
                Icon(
                  patient.accountResponsibilitySignature != null 
                      ? Icons.check_circle 
                      : Icons.pending,
                  size: 20,
                  color: patient.accountResponsibilitySignature != null 
                      ? AppTheme.successColor 
                      : AppTheme.warningColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Account Responsibility Signed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: patient.accountResponsibilitySignature != null 
                          ? AppTheme.successColor 
                          : AppTheme.warningColor,
                    ),
                  ),
                ),
                if (patient.accountResponsibilitySignatureDate != null)
                  Text(
                    DateFormat('MMM d, yyyy').format(patient.accountResponsibilitySignatureDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Wound Photography Consent
            Row(
              children: [
                Icon(
                  patient.woundPhotographyConsentSignature != null 
                      ? Icons.check_circle 
                      : Icons.pending,
                  size: 20,
                  color: patient.woundPhotographyConsentSignature != null 
                      ? AppTheme.successColor 
                      : AppTheme.warningColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wound Photography Consent Signed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: patient.woundPhotographyConsentSignature != null 
                          ? AppTheme.successColor 
                          : AppTheme.warningColor,
                    ),
                  ),
                ),
                if (patient.woundPhotographyConsentDate != null)
                  Text(
                    DateFormat('MMM d, yyyy').format(patient.woundPhotographyConsentDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Training Photos Consent
            if (patient.trainingPhotosConsent != null) ...[
              Row(
                children: [
                  Icon(
                    patient.trainingPhotosConsent! 
                        ? Icons.check_circle 
                        : Icons.cancel,
                    size: 20,
                    color: patient.trainingPhotosConsent! 
                        ? AppTheme.successColor 
                        : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      patient.trainingPhotosConsent! 
                          ? 'Training Photos Consent Given' 
                          : 'Training Photos Consent Declined',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: patient.trainingPhotosConsent! 
                            ? AppTheme.successColor 
                            : AppTheme.errorColor,
                      ),
                    ),
                  ),
                  if (patient.trainingPhotosConsentDate != null)
                    Text(
                      DateFormat('MMM d, yyyy').format(patient.trainingPhotosConsentDate!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernQuickStatsCardAsync(Patient patient, PatientProvider patientProvider) {
    return FutureBuilder<ProgressMetrics>(
      future: patientProvider.calculateProgress(patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              child: Column(
                children: [
                  Text(
                    'Progress Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
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
                children: [
                  const Text(
                    'Progress Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Error loading progress: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        
        final progress = snapshot.data!;
        return _buildModernQuickStatsCard(patient, progress);
      },
    );
  }

  Widget _buildModernQuickStatsCard(Patient patient, ProgressMetrics progress) {
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
            const Text(
              'Progress Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModernProgressIndicator(
                    'Pain Reduction',
                    '${progress.painReductionPercentage.toStringAsFixed(1)}%',
                    progress.painReductionPercentage / 100,
                    AppTheme.successColor,
                    Icons.healing_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernProgressIndicator(
                    'Total Sessions',
                    '${progress.totalSessions}',
                    progress.totalSessions / 20, // Assuming max 20 sessions
                    AppTheme.infoColor,
                    Icons.event_note_outlined,
                  ),
                ),
              ],
            ),
            if (progress.improvementSummary.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successColor.withOpacity(0.1),
                      AppTheme.successColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        progress.improvementSummary,
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernProgressIndicator(String label, String value, double progress, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
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

  Widget _buildModernCurrentStatusCardAsync(Patient patient, PatientProvider patientProvider) {
    return FutureBuilder<List<Session>>(
      future: patientProvider.getPatientSessions(patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
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
                  const Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Error loading status: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        
        final sessions = snapshot.data ?? [];
        final latestSession = sessions.isNotEmpty ? sessions.last : null;
        return _buildModernCurrentStatusCardWithData(patient, latestSession);
      },
    );
  }

  Widget _buildModernCurrentStatusCardWithData(Patient patient, Session? latestSession) {
    // Use latest session data if available, otherwise fall back to patient baseline/current data
    final currentWeight = latestSession?.weight ?? patient.currentWeight ?? patient.baselineWeight;
    final currentVasScore = latestSession?.vasScore ?? patient.currentVasScore ?? patient.baselineVasScore;
    final currentWounds = latestSession?.wounds ?? patient.currentWounds;
    
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
                const Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const Spacer(),
                if (latestSession != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Session ${latestSession.sessionNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatusItem(
                    'Weight',
                    currentWeight != null ? '${currentWeight.toStringAsFixed(1)} kg' : 'N/A',
                    Icons.monitor_weight_outlined,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatusItem(
                    'Pain Score',
                    currentVasScore != null ? '$currentVasScore/10' : 'N/A',
                    Icons.healing_outlined,
                    _getPainColor(currentVasScore ?? 0),
                  ),
                ),
              ],
            ),
            if (currentWounds.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.healing,
                          color: AppTheme.warningColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active Wounds (${currentWounds.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...currentWounds.take(3).map((wound) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${wound.location} - ${wound.length.toStringAsFixed(1)}×${wound.width.toStringAsFixed(1)} cm',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.warningColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    if (currentWounds.length > 3)
                      Text(
                        '... and ${currentWounds.length - 3} more',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningColor.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernCurrentStatusCard(Patient patient) {
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
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatusItem(
                    'Weight',
                    '${patient.currentWeight?.toStringAsFixed(1) ?? 'N/A'} kg',
                    Icons.monitor_weight_outlined,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatusItem(
                    'Pain Score',
                    '${patient.currentVasScore ?? 'N/A'}/10',
                    Icons.healing_outlined,
                    _getPainColor(patient.currentVasScore ?? 0),
                  ),
                ),
              ],
            ),
            if (patient.currentWounds.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Current Wounds',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              ...patient.currentWounds.map((wound) => _buildModernWoundItem(wound)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatusItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
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
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWoundItem(Wound wound) {
    final stageColor = _getWoundStageColor(wound.stage);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stageColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: stageColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  wound.stage.description,
                  style: TextStyle(
                    color: stageColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${wound.area.toStringAsFixed(1)} cm²',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${wound.location} - ${wound.type}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${wound.length} × ${wound.width} × ${wound.depth} cm',
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getWoundStageColor(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return AppTheme.successColor;
      case WoundStage.stage2:
        return AppTheme.warningColor;
      case WoundStage.stage3:
        return Colors.orange;
      case WoundStage.stage4:
        return AppTheme.errorColor;
      default:
        return AppTheme.secondaryColor;
    }
  }

  Widget _buildModernNextAppointmentCard(Patient patient) {
    final nextAppointment = patient.nextAppointment;
    final hasAppointment = nextAppointment != null;
    
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasAppointment ? Icons.schedule : Icons.schedule_outlined,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next Appointment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasAppointment
                            ? DateFormat('EEEE, MMM d, yyyy').format(nextAppointment)
                            : 'Not scheduled yet',
                        style: TextStyle(
                          color: hasAppointment 
                              ? AppTheme.textColor 
                              : AppTheme.secondaryColor,
                          fontSize: 14,
                          fontWeight: hasAppointment 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // Schedule appointment
                },
                icon: Icon(hasAppointment ? Icons.edit : Icons.add),
                label: Text(
                  hasAppointment ? 'Reschedule' : 'Schedule Appointment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernProgressTab(Patient patient, PatientProvider patientProvider) {
    return FutureBuilder<ProgressMetrics>(
      future: patientProvider.calculateProgress(patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Calculating progress metrics...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error calculating progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Trigger a rebuild to retry
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final progress = snapshot.data!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProgressSummaryCard(patient, progress),
              const SizedBox(height: 24),
              _buildModernPainChart(progress.painHistory),
              const SizedBox(height: 24),
              _buildModernWeightChart(progress.weightHistory),
              const SizedBox(height: 24),
              if (progress.woundSizeHistory.isNotEmpty)
                _buildModernWoundSizeChart(progress.woundSizeHistory),
              const SizedBox(height: 24),
              // TODO: Implement treatment timeline
              // _buildTreatmentTimelineCard(patient, progress),
              // const SizedBox(height: 24),
              // TODO: Implement goals and milestones
              // _buildGoalsAndMilestonesCard(patient, progress),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernPainChart(List<ProgressDataPoint> painData) {
    if (painData.isEmpty) {
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
                  Icons.healing_outlined,
                  size: 48,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'No pain data available',
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
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.healing_outlined,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pain Score Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 350,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 16, right: 12),
                        child: Text(
                          'Pain Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value % 2 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Session Number',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: painData.length > 10 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < painData.length) {
                            // Show every session if <= 10, every other if > 10
                            if (painData.length <= 10 || index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'S${painData[index].sessionNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
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
                  minX: 0,
                  maxX: painData.length - 1.0,
                  minY: 0,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: painData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.errorColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: AppTheme.errorColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.errorColor.withOpacity(0.2),
                            AppTheme.errorColor.withOpacity(0.05),
                          ],
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

  Widget _buildModernWeightChart(List<ProgressDataPoint> weightData) {
    if (weightData.isEmpty) {
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
                  child: Icon(
                    Icons.monitor_weight_outlined,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weight Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 350,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 16, right: 12),
                        child: Text(
                          'Weight (kg)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${value.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Session Number',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: weightData.length > 10 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < weightData.length) {
                            if (weightData.length <= 10 || index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'S${weightData[index].sessionNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
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
                  minX: 0,
                  maxX: weightData.length - 1.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: weightData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.infoColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: AppTheme.infoColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.infoColor.withOpacity(0.2),
                            AppTheme.infoColor.withOpacity(0.05),
                          ],
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

  Widget _buildModernWoundSizeChart(List<ProgressDataPoint> woundData) {
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
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.straighten,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Wound Size Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 350,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 16, right: 12),
                        child: Text(
                          'Area (cm²)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 75,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Session Number',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: woundData.length > 10 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < woundData.length) {
                            if (woundData.length <= 10 || index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'S${woundData[index].sessionNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
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
                  minX: 0,
                  maxX: woundData.length - 1.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: woundData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.warningColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: AppTheme.warningColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.warningColor.withOpacity(0.2),
                            AppTheme.warningColor.withOpacity(0.05),
                          ],
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

  Widget _buildProgressSummaryCard(Patient patient, ProgressMetrics progress) {
    final treatmentDays = DateTime.now().difference(patient.createdAt).inDays;
    final averageSessionsPerWeek = patient.sessions.isNotEmpty 
        ? (patient.sessions.length / (treatmentDays / 7)).clamp(0.0, 7.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Treatment Progress Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    'Treatment Days',
                    '$treatmentDays',
                    'days',
                    Icons.calendar_today,
                    AppTheme.infoColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FutureBuilder<List<Session>>(
                    future: context.read<PatientProvider>().getPatientSessions(patient.id),
                    builder: (context, snapshot) {
                      final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
                      return _buildProgressMetric(
                        'Total Sessions',
                        '$sessionCount',
                        'sessions',
                        Icons.event_note,
                        AppTheme.primaryColor,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    'Sessions/Week',
                    averageSessionsPerWeek.toStringAsFixed(1),
                    'avg',
                    Icons.trending_up,
                    AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressMetric(
                    'Pain Reduction',
                    '${progress.painReductionPercentage.toStringAsFixed(0)}%',
                    'improvement',
                    Icons.healing,
                    AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            if (progress.improvementSummary.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        progress.improvementSummary,
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
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
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentTimelineCard(Patient patient) {
    final milestones = <Map<String, dynamic>>[];
    
    // Add treatment start
    milestones.add({
      'date': patient.createdAt,
      'title': 'Treatment Started',
      'description': 'Initial assessment and baseline measurements',
      'icon': Icons.play_arrow,
      'color': AppTheme.primaryColor,
    });

    // Add significant sessions
    for (int i = 0; i < patient.sessions.length; i++) {
      final session = patient.sessions[i];
      if (i % 5 == 0 || i == patient.sessions.length - 1) { // Every 5th session or last
        milestones.add({
          'date': session.date,
          'title': 'Session ${session.sessionNumber}',
          'description': 'Pain: ${session.vasScore}/10, Weight: ${session.weight.toStringAsFixed(1)}kg',
          'icon': Icons.medical_services,
          'color': AppTheme.infoColor,
        });
      }
    }

    // Sort by date
    milestones.sort((a, b) => a['date'].compareTo(b['date']));

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
                  child: Icon(Icons.timeline, size: 20, color: AppTheme.infoColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Treatment Timeline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...milestones.asMap().entries.map((entry) {
              final index = entry.key;
              final milestone = entry.value;
              final isLast = index == milestones.length - 1;
              
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: milestone['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: milestone['color'], width: 2),
                        ),
                        child: Icon(
                          milestone['icon'],
                          size: 16,
                          color: milestone['color'],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: AppTheme.borderColor.withOpacity(0.3),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          milestone['description'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(milestone['date']),
                          style: TextStyle(
                            fontSize: 12,
                            color: milestone['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsAndMilestonesCard(Patient patient, ProgressMetrics progress) {
    final goals = <Map<String, dynamic>>[];
    
    // Pain reduction goal
    final painReduction = progress.painReductionPercentage;
    goals.add({
      'title': 'Pain Reduction',
      'target': 'Reduce pain by 50%',
      'current': '${painReduction.toStringAsFixed(0)}% achieved',
      'progress': (painReduction / 50).clamp(0.0, 1.0),
      'icon': Icons.healing,
      'color': painReduction >= 50 ? AppTheme.successColor : AppTheme.warningColor,
      'achieved': painReduction >= 50,
    });

    // Session consistency goal
    final treatmentWeeks = DateTime.now().difference(patient.createdAt).inDays / 7;
    final sessionConsistency = treatmentWeeks > 0 ? (patient.sessions.length / treatmentWeeks / 2) : 0.0; // Target: 2 sessions per week
    goals.add({
      'title': 'Session Consistency',
      'target': '2 sessions per week',
      'current': '${(patient.sessions.length / treatmentWeeks).toStringAsFixed(1)} avg/week',
      'progress': sessionConsistency.clamp(0.0, 1.0),
      'icon': Icons.event_repeat,
      'color': sessionConsistency >= 0.8 ? AppTheme.successColor : AppTheme.warningColor,
      'achieved': sessionConsistency >= 0.8,
    });

    // Wound healing goal (if applicable)
    if (patient.currentWounds.isNotEmpty && patient.baselineWounds.isNotEmpty) {
      final currentArea = patient.currentWounds.first.area;
      final baselineArea = patient.baselineWounds.first.area;
      final healingProgress = ((baselineArea - currentArea) / baselineArea).clamp(0.0, 1.0);
      
      goals.add({
        'title': 'Wound Healing',
        'target': 'Reduce wound size by 75%',
        'current': '${(healingProgress * 100).toStringAsFixed(0)}% reduction',
        'progress': (healingProgress / 0.75).clamp(0.0, 1.0),
        'icon': Icons.healing,
        'color': healingProgress >= 0.75 ? AppTheme.successColor : AppTheme.infoColor,
        'achieved': healingProgress >= 0.75,
      });
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
                  child: Icon(Icons.flag_outlined, size: 20, color: AppTheme.successColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Treatment Goals & Milestones',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...goals.map((goal) => Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: goal['color'].withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: goal['color'].withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: goal['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          goal['icon'],
                          size: 16,
                          color: goal['color'],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: goal['color'],
                              ),
                            ),
                            Text(
                              goal['target'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (goal['achieved'])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppTheme.successColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Achieved',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    goal['current'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: goal['color'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal['progress'],
                      backgroundColor: goal['color'].withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(goal['color']),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSessionsTab(Patient patient) {
    return FutureBuilder<List<Session>>(
      future: context.read<PatientProvider>().getPatientSessions(patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading sessions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Trigger a rebuild to retry loading
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final sessions = snapshot.data ?? [];
        
        if (sessions.isEmpty) {
          // Show session restriction card for web platform
          if (ResponsiveUtils.shouldRestrictSessions()) {
            return const Center(
              child: SessionRestrictionCard(),
            );
          }
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 60,
                      color: AppTheme.primaryColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Complete Patient Case History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This patient needs their initial case history assessment to establish baseline data and wound information.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryColor,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Required before regular sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/patients/${patient.id}/wound-selection?name=${Uri.encodeComponent(patient.fullNames + ' ' + patient.surname)}');
                    },
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('Complete Case History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      elevation: 2,
                      shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      // Show info dialog about case history
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('About Patient Case History'),
                          content: const Text(
                            'The Patient Case History collects essential baseline information including:\n\n'
                            '• Initial wound assessment and measurements\n'
                            '• Patient weight and pain levels\n'
                            '• Wound history and previous treatments\n'
                            '• Baseline photos for progress tracking\n\n'
                            'This information is crucial for AI report generation and treatment planning.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    label: Text(
                      'What is Case History?',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Sort sessions by date (newest first)
        sessions.sort((a, b) => b.date.compareTo(a.date));
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return AnimatedContainer(
              duration: Duration(milliseconds: 100 + (index * 50)),
              curve: Curves.easeOutBack,
              child: _buildModernSessionCard(patient, session, index),
            );
          },
        );
      },
    );
  }

  Widget _buildModernSessionCard(Patient patient, Session session, int index) {
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
            context.push('/patients/${patient.id}/sessions/${session.id}', extra: {
              'patient': patient,
              'session': session,
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'Session ${session.sessionNumber}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d, yyyy').format(session.date),
                            style: const TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildModernSessionMetric(
                      'Weight',
                      '${session.weight.toStringAsFixed(1)}kg',
                      Icons.monitor_weight_outlined,
                      AppTheme.infoColor,
                    ),
                    const SizedBox(width: 12),
                    _buildModernSessionMetric(
                      'Pain',
                      '${session.vasScore}/10',
                      Icons.healing_outlined,
                      _getPainColor(session.vasScore),
                    ),
                    const SizedBox(width: 12),
                    _buildModernSessionMetric(
                      'Photos',
                      session.photos.length.toString(),
                      Icons.photo_camera_outlined,
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
                if (session.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes_outlined,
                              size: 16,
                              color: AppTheme.secondaryColor,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.notes,
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSessionMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPhotosTab(Patient patient) {
    return FutureBuilder<List<Session>>(
      future: context.read<PatientProvider>().getPatientSessions(patient.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading photos...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Trigger a rebuild to retry
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final sessions = snapshot.data ?? [];
        final photoItems = _buildPhotoItemsListFromSessions(patient, sessions);

        if (photoItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      size: 50,
                      color: AppTheme.primaryColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No photos available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Photos will appear here as you document sessions',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/patients/${patient.id}/session');
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take First Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75, // Reduced to give more height for content
          ),
          itemCount: photoItems.length,
          itemBuilder: (context, index) {
            final photoItem = photoItems[index];
            return _buildPhotoCard(photoItem);
          },
        );
      },
    );
  }

  List<PhotoItem> _buildPhotoItemsListFromSessions(Patient patient, List<Session> sessions) {
    final List<PhotoItem> photoItems = [];

    // Add baseline photos
    if (patient.baselinePhotos.isNotEmpty) {
      for (int i = 0; i < patient.baselinePhotos.length; i++) {
        photoItems.add(PhotoItem(
          photoPath: patient.baselinePhotos[i],
          type: PhotoType.baseline,
          timestamp: patient.createdAt ?? DateTime.now(),
          label: 'Baseline Photo ${i + 1}',
        ));
      }
    }

    // Add session photos from fetched sessions
    for (Session session in sessions) {
      print('📷 PHOTO DEBUG: Session ${session.sessionNumber} has ${session.photos.length} photos');
      for (int i = 0; i < session.photos.length; i++) {
        final photoUrl = session.photos[i];
        print('📷 PHOTO DEBUG: Photo ${i + 1}: $photoUrl');
        print('📷 PHOTO DEBUG: Photo URL starts with http: ${photoUrl.startsWith('http')}');
        
        photoItems.add(PhotoItem(
          photoPath: photoUrl,
          type: PhotoType.session,
          timestamp: session.date,
          sessionNumber: session.sessionNumber,
          label: 'Session ${session.sessionNumber} - Photo ${i + 1}',
        ));
      }
    }

    // Add wound photos from latest session wounds or current wounds
    final woundsToCheck = sessions.isNotEmpty ? sessions.last.wounds : patient.currentWounds;
    for (Wound wound in woundsToCheck) {
      for (int i = 0; i < wound.photos.length; i++) {
        photoItems.add(PhotoItem(
          photoPath: wound.photos[i],
          type: PhotoType.wound,
          timestamp: wound.assessedAt,
          label: 'Wound - ${wound.location} (${i + 1})',
        ));
      }
    }

    // Sort by timestamp (newest first)
    photoItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return photoItems;
  }

  List<PhotoItem> _buildPhotoItemsList(Patient patient) {
    final List<PhotoItem> photoItems = [];

    // Add baseline photos
    for (String photo in patient.baselinePhotos) {
      photoItems.add(PhotoItem(
        photoPath: photo,
        type: PhotoType.baseline,
        timestamp: patient.createdAt,
        sessionNumber: null,
        label: 'Baseline',
      ));
    }

    // Add session photos
    for (Session session in patient.sessions) {
      for (String photo in session.photos) {
        photoItems.add(PhotoItem(
          photoPath: photo,
          type: PhotoType.session,
          timestamp: session.date,
          sessionNumber: session.sessionNumber,
          label: 'Session ${session.sessionNumber}',
        ));
      }
    }

    // Add wound photos
    for (Wound wound in patient.currentWounds) {
      for (String photo in wound.photos) {
        photoItems.add(PhotoItem(
          photoPath: photo,
          type: PhotoType.wound,
          timestamp: wound.assessedAt,
          sessionNumber: null,
          label: 'Wound - ${wound.location}',
        ));
      }
    }

    // Sort by timestamp (newest first)
    photoItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return photoItems;
  }

  Widget _buildPhotoCard(PhotoItem photoItem) {
    Color typeColor;
    IconData typeIcon;
    
    switch (photoItem.type) {
      case PhotoType.baseline:
        typeColor = AppTheme.infoColor;
        typeIcon = Icons.timeline;
        break;
      case PhotoType.session:
        typeColor = AppTheme.primaryColor;
        typeIcon = Icons.medical_services;
        break;
      case PhotoType.wound:
        typeColor = AppTheme.warningColor;
        typeIcon = Icons.healing;
        break;
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showPhotoViewer(photoItem);
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo area
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Main photo
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: SizedBox.expand(
                          child: FirebaseImage(
                            imagePath: photoItem.photoPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Type badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                typeIcon,
                                size: 10,
                                color: Colors.white,
                              ),
                              if (photoItem.sessionNumber != null) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${photoItem.sessionNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info area
              Container(
                height: 60, // Fixed height to prevent overflow
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      photoItem.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 9,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            DateFormat('MMM d').format(photoItem.timestamp),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.secondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(photoItem.timestamp),
                          style: const TextStyle(
                            fontSize: 9,
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
        ),
      ),
    );
  }

  void _showPhotoViewer(PhotoItem photoItem) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Photo header
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    photoItem.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('EEEE, MMM d, yyyy').format(photoItem.timestamp)} at ${DateFormat('HH:mm').format(photoItem.timestamp)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Actual photo
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photoItem.photoPath.startsWith('http')
                      ? FirebaseImage(
                          imagePath: photoItem.photoPath,
                          fit: BoxFit.contain,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 80,
                                  color: AppTheme.errorColor,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Failed to load photo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SizedBox.expand(
                          child: Image.file(
                            File(photoItem.photoPath),
                            fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 80,
                                    color: AppTheme.errorColor,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Failed to load photo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          ),
                        ),
                ),
              ),
            ),
            // Close button
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPatientInitials(String? name) {
    if (name == null || name.trim().isEmpty) {
      return '?';
    }
    
    final words = name.trim().split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) {
      return '?';
    }
    
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Color _getPainColor(int painScore) {
    if (painScore <= 3) return AppTheme.successColor;
    if (painScore <= 6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Future<void> _exportPatientProgress(Patient patient) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(width: 16),
              Text('Generating progress report...'),
            ],
          ),
        ),
      );

      // Calculate progress
      final patientProvider = context.read<PatientProvider>();
      final progress = await patientProvider.calculateProgress(patient.id);

      // Generate PDF
      final file = await ExportUtils.exportPatientProgressToPdf(patient, progress);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog with file path
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Patient progress report has been exported successfully.'),
              const SizedBox(height: 8),
              Text(
                'File saved to:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  file.path,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Failed'),
          content: Text('Failed to export patient progress: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
