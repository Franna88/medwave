import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../services/firebase/patient_service.dart';

class ResponsivePatientList extends StatelessWidget {
  final String searchQuery;
  final String sortBy;
  final bool showOnlyImproving;

  const ResponsivePatientList({
    super.key,
    required this.searchQuery,
    required this.sortBy,
    required this.showOnlyImproving,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        if (patientProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final patients = _getFilteredPatients(patientProvider.patients);

        if (ResponsiveUtils.shouldUseHorizontalLayout(context)) {
          return _buildTabletGrid(context, patients);
        } else {
          return _buildMobileList(context, patients);
        }
      },
    );
  }

  Widget _buildTabletGrid(BuildContext context, List<Patient> patients) {
    if (patients.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundColor,
            AppTheme.cardColor.withOpacity(0.2),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Patient',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Wound Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Sessions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 60), // Space for status indicator
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Patient list
          Expanded(
            child: ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + (index * 30)),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _buildTabletPatientRow(context, patients[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, List<Patient> patients) {
    if (patients.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        return _buildMobilePatientCard(context, patients[index]);
      },
    );
  }

  Widget _buildTabletPatientCard(BuildContext context, Patient patient) {
    final hasProgress = patient.woundHealingProgress != null;
    final isImproving = hasProgress && patient.woundHealingProgress! > 0;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.cardColor.withOpacity(0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/patients/${patient.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with avatar and status
                Row(
                  children: [
                    // Enhanced avatar with gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          patient.name[0].toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildEnhancedStatusIndicator(patient),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Patient name with enhanced typography
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                
                // Wound type with icon
                Row(
                  children: [
                    Icon(
                      Icons.healing,
                      size: 16,
                      color: AppTheme.secondaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      patient.baselineWounds.isNotEmpty ? patient.baselineWounds.first.type : 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Progress section with enhanced design
                if (hasProgress) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isImproving
                            ? [
                                AppTheme.successColor.withOpacity(0.1),
                                AppTheme.successColor.withOpacity(0.05),
                              ]
                            : [
                                AppTheme.errorColor.withOpacity(0.1),
                                AppTheme.errorColor.withOpacity(0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isImproving
                            ? AppTheme.successColor.withOpacity(0.2)
                            : AppTheme.errorColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isImproving
                                    ? AppTheme.successColor.withOpacity(0.2)
                                    : AppTheme.errorColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isImproving ? Icons.trending_up : Icons.trending_down,
                                size: 16,
                                color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isImproving ? 'Improving' : 'Stable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                                    ),
                                  ),
                                  Text(
                                    '${patient.woundHealingProgress!.toStringAsFixed(1)}% progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: AppTheme.secondaryColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No sessions yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryColor.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Sessions count with enhanced design
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_note,
                        size: 14,
                        color: AppTheme.primaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      FutureBuilder<List<Session>>(
                        future: PatientService.getPatientSessions(patient.id),
                        builder: (context, snapshot) {
                          final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
                          return Text(
                            '$sessionCount sessions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor.withOpacity(0.8),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePatientCard(BuildContext context, Patient patient) {

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/patients/${patient.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  patient.name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.baselineWounds.isNotEmpty ? patient.baselineWounds.first.type : 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusIndicator(patient),
                  const SizedBox(height: 4),
                  FutureBuilder<List<Session>>(
                    future: PatientService.getPatientSessions(patient.id),
                    builder: (context, snapshot) {
                      final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
                      return Text(
                        '$sessionCount sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryColor.withOpacity(0.6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletPatientRow(BuildContext context, Patient patient) {
    final hasProgress = patient.woundHealingProgress != null;
    final isImproving = hasProgress && patient.woundHealingProgress! > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/patients/${patient.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Patient info column
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    // Avatar with patient initial
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          patient.name[0].toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${patient.id}',
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
              ),
              
              // Wound type column
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.healing,
                      size: 16,
                      color: AppTheme.secondaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        patient.baselineWounds.isNotEmpty ? patient.baselineWounds.first.type : 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress column
              Expanded(
                flex: 1,
                child: hasProgress
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isImproving
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              isImproving ? Icons.trending_up : Icons.trending_down,
                              size: 14,
                              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${patient.woundHealingProgress!.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'No data',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
              
              // Sessions column
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 16,
                      color: AppTheme.primaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    FutureBuilder<List<Session>>(
                      future: PatientService.getPatientSessions(patient.id),
                      builder: (context, snapshot) {
                        final sessionCount = snapshot.hasData ? snapshot.data!.length : 0;
                        return Text(
                          '$sessionCount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Status indicator
              SizedBox(
                width: 60,
                child: _buildCompactStatusIndicator(patient),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(Patient patient) {
    if (patient.woundHealingProgress == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.secondaryColor.withOpacity(0.15),
              AppTheme.secondaryColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.secondaryColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add,
              size: 14,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              'New',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isImproving = patient.woundHealingProgress! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isImproving
              ? [
                  AppTheme.successColor.withOpacity(0.15),
                  AppTheme.successColor.withOpacity(0.08),
                ]
              : [
                  AppTheme.errorColor.withOpacity(0.15),
                  AppTheme.errorColor.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isImproving
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.errorColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isImproving ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImproving ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 6),
          Text(
            isImproving ? 'Improving' : 'Stable',
            style: TextStyle(
              fontSize: 12,
              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatusIndicator(Patient patient) {
    if (patient.woundHealingProgress == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'New',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isImproving = patient.woundHealingProgress! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isImproving ? AppTheme.greenColor : AppTheme.redColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isImproving ? 'Improving' : 'Stable',
        style: TextStyle(
          fontSize: 12,
          color: isImproving ? AppTheme.greenColor : AppTheme.redColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCompactStatusIndicator(Patient patient) {
    if (patient.woundHealingProgress == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.secondaryColor.withOpacity(0.15),
              AppTheme.secondaryColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.secondaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add,
              size: 12,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isImproving = patient.woundHealingProgress! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isImproving
              ? [
                  AppTheme.successColor.withOpacity(0.15),
                  AppTheme.successColor.withOpacity(0.08),
                ]
              : [
                  AppTheme.errorColor.withOpacity(0.15),
                  AppTheme.errorColor.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isImproving
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImproving ? Icons.trending_up : Icons.trending_down,
            size: 12,
            color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 4),
          Text(
            isImproving ? 'Improving' : 'Stable',
            style: TextStyle(
              fontSize: 11,
              color: isImproving ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardColor.withOpacity(0.5),
              AppTheme.backgroundColor,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.borderColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.isNotEmpty 
                ? 'No patients found matching "$searchQuery"'
                : 'No patients yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'Add your first patient to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Patient> _getFilteredPatients(List<Patient> allPatients) {
    var filtered = allPatients.where((patient) {
      final woundType = patient.baselineWounds.isNotEmpty ? patient.baselineWounds.first.type : '';
      final matchesSearch = searchQuery.isEmpty ||
          patient.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          woundType.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesFilter = !showOnlyImproving ||
          (patient.woundHealingProgress != null && patient.woundHealingProgress! > 0);

      return matchesSearch && matchesFilter;
    }).toList();

    // Sort patients
    switch (sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'lastUpdated':
        filtered.sort((a, b) {
          final aLastUpdate = a.lastUpdated ?? a.createdAt;
          final bLastUpdate = b.lastUpdated ?? b.createdAt;
          return bLastUpdate.compareTo(aLastUpdate);
        });
        break;
      case 'sessions':
        filtered.sort((a, b) => b.sessions.length.compareTo(a.sessions.length));
        break;
    }

    return filtered;
  }
}
