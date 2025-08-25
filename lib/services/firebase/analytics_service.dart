import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/patient.dart';
import '../../models/appointment.dart';
import '../../models/progress_metrics.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _patientsCollection => _firestore.collection('patients');
  static CollectionReference get _appointmentsCollection => _firestore.collection('appointments');

  /// Get comprehensive dashboard analytics for the current practitioner
  static Future<DashboardAnalytics> getDashboardAnalytics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfYear = DateTime(now.year, 1, 1);

      // Get practitioner's patients
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = patientsSnapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();

      // Get appointments for periods  
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('practitionerId', isEqualTo: userId)
          .get();

      final appointments = appointmentsSnapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();

      // Calculate session statistics
      int totalSessions = 0;
      int monthSessions = 0;
      int weekSessions = 0;

      for (final patient in patients) {
        // Get sessions for this patient
        final sessionsSnapshot = await _patientsCollection
            .doc(patient.id)
            .collection('sessions')
            .get();

        totalSessions += sessionsSnapshot.docs.length;

        // Count sessions for this month
        final monthSessionsSnapshot = await _patientsCollection
            .doc(patient.id)
            .collection('sessions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .get();

        monthSessions += monthSessionsSnapshot.docs.length;

        // Count sessions for this week
        final weekSessionsSnapshot = await _patientsCollection
            .doc(patient.id)
            .collection('sessions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
            .get();

        weekSessions += weekSessionsSnapshot.docs.length;
      }

      // Calculate appointment statistics
      final monthAppointments = appointments.where((a) => a.startTime.isAfter(startOfMonth)).length;
      final weekAppointments = appointments.where((a) => a.startTime.isAfter(startOfWeek)).length;
      final todayAppointments = appointments.where((a) => 
          a.startTime.year == now.year && 
          a.startTime.month == now.month && 
          a.startTime.day == now.day
      ).length;

      // Calculate patient progress statistics
      double totalWeightChange = 0;
      double totalPainReduction = 0;
      double totalWoundHealing = 0;
      int patientsWithProgress = 0;

      for (final patient in patients) {
        if (patient.weightChange != null && patient.painReduction != null && patient.woundHealingProgress != null) {
          totalWeightChange += patient.weightChange!;
          totalPainReduction += patient.painReduction!;
          totalWoundHealing += patient.woundHealingProgress!;
          patientsWithProgress++;
        }
      }

      final averageWeightChange = patientsWithProgress > 0 ? totalWeightChange / patientsWithProgress : 0.0;
      final averagePainReduction = patientsWithProgress > 0 ? totalPainReduction / patientsWithProgress : 0.0;
      final averageWoundHealing = patientsWithProgress > 0 ? totalWoundHealing / patientsWithProgress : 0.0;

      return DashboardAnalytics(
        totalPatients: patients.length,
        totalSessions: totalSessions,
        totalAppointments: appointments.length,
        sessionsThisMonth: monthSessions,
        sessionsThisWeek: weekSessions,
        appointmentsThisMonth: monthAppointments,
        appointmentsThisWeek: weekAppointments,
        appointmentsToday: todayAppointments,
        averageWeightChange: averageWeightChange,
        averagePainReduction: averagePainReduction,
        averageWoundHealing: averageWoundHealing,
        activePatients: patients.where((p) => p.sessions.isNotEmpty).length,
        completedAppointments: appointments.where((a) => a.status == AppointmentStatus.completed).length,
        cancelledAppointments: appointments.where((a) => a.status == AppointmentStatus.cancelled).length,
      );
    } catch (e) {
      throw Exception('Failed to get dashboard analytics: $e');
    }
  }

  /// Get patient progress data for charts over a specified period
  static Future<List<ProgressDataPoint>> getPatientProgressData(String patientId, int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Get patient sessions within the date range
      final sessionsSnapshot = await _patientsCollection
          .doc(patientId)
          .collection('sessions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date')
          .get();

      final sessions = sessionsSnapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();

      // Get patient baseline data
      final patientDoc = await _patientsCollection.doc(patientId).get();
      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }

      final patient = Patient.fromFirestore(patientDoc);

      // Convert sessions to progress data points
      final progressData = <ProgressDataPoint>[];

      for (final session in sessions) {
        // Calculate progress metrics for this session
        final weightChange = patient.baselineWeight > 0
            ? ((session.weight - patient.baselineWeight) / patient.baselineWeight) * 100
            : 0.0;

        final painReduction = patient.baselineVasScore > 0
            ? ((patient.baselineVasScore - session.vasScore) / patient.baselineVasScore) * 100
            : 0.0;

        // Calculate wound healing progress
        double woundHealingProgress = 0.0;
        if (patient.baselineWounds.isNotEmpty && session.wounds.isNotEmpty) {
          final baselineArea = patient.baselineWounds.fold(0.0, (sum, w) => sum + w.area);
          final currentArea = session.wounds.fold(0.0, (sum, w) => sum + w.area);
          if (baselineArea > 0) {
            woundHealingProgress = ((baselineArea - currentArea) / baselineArea) * 100;
          }
        }

        progressData.add(ProgressDataPoint(
          date: session.date,
          value: weightChange, // Use weight change as the primary value
          sessionNumber: session.sessionNumber,
          weightChange: weightChange,
          painReduction: painReduction,
          woundHealingProgress: woundHealingProgress,
          vasScore: session.vasScore.toDouble(),
          weight: session.weight,
        ));
      }

      return progressData;
    } catch (e) {
      throw Exception('Failed to get patient progress data: $e');
    }
  }

  /// Get overall progress data for all patients
  static Future<List<ProgressDataPoint>> getOverallProgressData(int days) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Get practitioner's patients
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = patientsSnapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();

      // Collect all progress data points
      final allProgressData = <ProgressDataPoint>[];

      for (final patient in patients) {
        final patientProgressData = await getPatientProgressData(patient.id, days);
        allProgressData.addAll(patientProgressData);
      }

      // Group by date and calculate averages
      final groupedData = <DateTime, List<ProgressDataPoint>>{};
      
      for (final dataPoint in allProgressData) {
        final dateKey = DateTime(dataPoint.date.year, dataPoint.date.month, dataPoint.date.day);
        groupedData.putIfAbsent(dateKey, () => []).add(dataPoint);
      }

      // Calculate daily averages
      final averagedData = <ProgressDataPoint>[];
      
      for (final entry in groupedData.entries) {
        final dayData = entry.value;
        final avgWeightChange = dayData.map((d) => d.weightChange ?? 0.0).reduce((a, b) => a + b) / dayData.length;
        final avgPainReduction = dayData.map((d) => d.painReduction ?? 0.0).reduce((a, b) => a + b) / dayData.length;
        final avgWoundHealing = dayData.map((d) => d.woundHealingProgress ?? 0.0).reduce((a, b) => a + b) / dayData.length;
        final avgVasScore = dayData.map((d) => d.vasScore ?? 0.0).reduce((a, b) => a + b) / dayData.length;
        final avgWeight = dayData.map((d) => d.weight ?? 0.0).reduce((a, b) => a + b) / dayData.length;

        averagedData.add(ProgressDataPoint(
          date: entry.key,
          value: avgWeightChange, // Use weight change as the primary value
          sessionNumber: 0, // Not applicable for averaged data
          weightChange: avgWeightChange,
          painReduction: avgPainReduction,
          woundHealingProgress: avgWoundHealing,
          vasScore: avgVasScore,
          weight: avgWeight,
        ));
      }

      // Sort by date
      averagedData.sort((a, b) => a.date.compareTo(b.date));

      return averagedData;
    } catch (e) {
      throw Exception('Failed to get overall progress data: $e');
    }
  }

  /// Get patient statistics for reports
  static Future<PatientStatistics> getPatientStatistics() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get practitioner's patients
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = patientsSnapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();

      // Calculate age distribution
      final now = DateTime.now();
      final ageGroups = <String, int>{
        '18-30': 0,
        '31-45': 0,
        '46-60': 0,
        '61-75': 0,
        '75+': 0,
      };

      final genderDistribution = <String, int>{
        'Male': 0,
        'Female': 0,
        'Other': 0,
      };

      final conditionTypes = <String, int>{};

      for (final patient in patients) {
        // Calculate age
        final age = now.difference(patient.dateOfBirth).inDays ~/ 365;
        
        if (age <= 30) {
          ageGroups['18-30'] = (ageGroups['18-30'] ?? 0) + 1;
        } else if (age <= 45) {
          ageGroups['31-45'] = (ageGroups['31-45'] ?? 0) + 1;
        } else if (age <= 60) {
          ageGroups['46-60'] = (ageGroups['46-60'] ?? 0) + 1;
        } else if (age <= 75) {
          ageGroups['61-75'] = (ageGroups['61-75'] ?? 0) + 1;
        } else {
          ageGroups['75+'] = (ageGroups['75+'] ?? 0) + 1;
        }

        // Count medical conditions
        for (final condition in patient.medicalConditions.entries) {
          if (condition.value) {
            conditionTypes[condition.key] = (conditionTypes[condition.key] ?? 0) + 1;
          }
        }
      }

      return PatientStatistics(
        totalPatients: patients.length,
        ageDistribution: ageGroups,
        genderDistribution: genderDistribution,
        conditionTypes: conditionTypes,
        averageAge: patients.isNotEmpty 
            ? patients.map((p) => now.difference(p.dateOfBirth).inDays ~/ 365).reduce((a, b) => a + b) / patients.length
            : 0.0,
        patientsWithActiveSessions: patients.where((p) => p.sessions.isNotEmpty).length,
      );
    } catch (e) {
      throw Exception('Failed to get patient statistics: $e');
    }
  }

  /// Get appointment analytics
  static Future<AppointmentAnalytics> getAppointmentAnalytics(int days) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Get appointments for the period
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final appointments = appointmentsSnapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();

      // Calculate statistics
      final totalAppointments = appointments.length;
      final completedAppointments = appointments.where((a) => a.status == AppointmentStatus.completed).length;
      final cancelledAppointments = appointments.where((a) => a.status == AppointmentStatus.cancelled).length;
      final noShowAppointments = appointments.where((a) => a.status == AppointmentStatus.noShow).length;

      final completionRate = totalAppointments > 0 ? (completedAppointments / totalAppointments) * 100 : 0.0;
      final cancellationRate = totalAppointments > 0 ? (cancelledAppointments / totalAppointments) * 100 : 0.0;
      final noShowRate = totalAppointments > 0 ? (noShowAppointments / totalAppointments) * 100 : 0.0;

      // Group by appointment type
      final typeDistribution = <AppointmentType, int>{};
      for (final appointment in appointments) {
        typeDistribution[appointment.type] = (typeDistribution[appointment.type] ?? 0) + 1;
      }

              // Calculate daily appointment counts for trending
        final dailyCounts = <DateTime, int>{};
        for (final appointment in appointments) {
          final dateKey = DateTime(appointment.startTime.year, appointment.startTime.month, appointment.startTime.day);
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }

      return AppointmentAnalytics(
        totalAppointments: totalAppointments,
        completedAppointments: completedAppointments,
        cancelledAppointments: cancelledAppointments,
        noShowAppointments: noShowAppointments,
        completionRate: completionRate,
        cancellationRate: cancellationRate,
        noShowRate: noShowRate,
        typeDistribution: typeDistribution,
        dailyCounts: dailyCounts,
        averageAppointmentsPerDay: dailyCounts.isNotEmpty 
            ? dailyCounts.values.reduce((a, b) => a + b) / dailyCounts.length
            : 0.0,
      );
    } catch (e) {
      throw Exception('Failed to get appointment analytics: $e');
    }
  }

  /// Get session frequency analytics
  static Future<SessionAnalytics> getSessionAnalytics(int days) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Get practitioner's patients
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = patientsSnapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();

      int totalSessions = 0;
      final dailySessionCounts = <DateTime, int>{};
      final patientSessionCounts = <String, int>{};

      for (final patient in patients) {
        // Get sessions for this patient within the date range
        final sessionsSnapshot = await _patientsCollection
            .doc(patient.id)
            .collection('sessions')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();

        final sessionCount = sessionsSnapshot.docs.length;
        totalSessions += sessionCount;
        patientSessionCounts[patient.id] = sessionCount;

        // Count daily sessions
        for (final sessionDoc in sessionsSnapshot.docs) {
          final session = Session.fromFirestore(sessionDoc);
          final dateKey = DateTime(session.date.year, session.date.month, session.date.day);
          dailySessionCounts[dateKey] = (dailySessionCounts[dateKey] ?? 0) + 1;
        }
      }

      final averageSessionsPerPatient = patients.isNotEmpty ? totalSessions / patients.length : 0.0;
      final averageSessionsPerDay = dailySessionCounts.isNotEmpty 
          ? dailySessionCounts.values.reduce((a, b) => a + b) / dailySessionCounts.length
          : 0.0;

      return SessionAnalytics(
        totalSessions: totalSessions,
        averageSessionsPerPatient: averageSessionsPerPatient,
        averageSessionsPerDay: averageSessionsPerDay,
        dailySessionCounts: dailySessionCounts,
        patientSessionCounts: patientSessionCounts,
        activePatientsCount: patientSessionCounts.values.where((count) => count > 0).length,
      );
    } catch (e) {
      throw Exception('Failed to get session analytics: $e');
    }
  }

  /// Export patient data to CSV format
  static Future<String> exportPatientsToCSV() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get practitioner's patients
      final patientsSnapshot = await _patientsCollection
          .where('practitionerId', isEqualTo: userId)
          .get();

      final patients = patientsSnapshot.docs.map((doc) => Patient.fromFirestore(doc)).toList();

      // Create CSV content
      final csvContent = StringBuffer();
      
      // Headers
      csvContent.writeln('Patient ID,Surname,Full Names,ID Number,Date of Birth,Cell,Email,'
          'Baseline Weight,Current Weight,Weight Change %,Baseline VAS Score,Current VAS Score,'
          'Pain Reduction %,Wound Healing Progress %,Total Sessions,Last Session Date');

      // Data rows
      for (final patient in patients) {
        final lastSessionDate = patient.sessions.isNotEmpty 
            ? patient.sessions.last.date.toIso8601String().split('T')[0]
            : '';

        csvContent.writeln('${patient.id},"${patient.surname}","${patient.fullNames}",'
            '"${patient.idNumber}","${patient.dateOfBirth.toIso8601String().split('T')[0]}",'
            '"${patient.patientCell}","${patient.email}",${patient.baselineWeight},'
            '${patient.currentWeight ?? 'N/A'},${patient.weightChange?.toStringAsFixed(2) ?? 'N/A'},'
            '${patient.baselineVasScore},${patient.currentVasScore ?? 'N/A'},'
            '${patient.painReduction?.toStringAsFixed(2) ?? 'N/A'},'
            '${patient.woundHealingProgress?.toStringAsFixed(2) ?? 'N/A'},'
            '${patient.sessions.length},"$lastSessionDate"');
      }

      return csvContent.toString();
    } catch (e) {
      throw Exception('Failed to export patients to CSV: $e');
    }
  }
}

// Data models for analytics

class DashboardAnalytics {
  final int totalPatients;
  final int totalSessions;
  final int totalAppointments;
  final int sessionsThisMonth;
  final int sessionsThisWeek;
  final int appointmentsThisMonth;
  final int appointmentsThisWeek;
  final int appointmentsToday;
  final double averageWeightChange;
  final double averagePainReduction;
  final double averageWoundHealing;
  final int activePatients;
  final int completedAppointments;
  final int cancelledAppointments;

  DashboardAnalytics({
    required this.totalPatients,
    required this.totalSessions,
    required this.totalAppointments,
    required this.sessionsThisMonth,
    required this.sessionsThisWeek,
    required this.appointmentsThisMonth,
    required this.appointmentsThisWeek,
    required this.appointmentsToday,
    required this.averageWeightChange,
    required this.averagePainReduction,
    required this.averageWoundHealing,
    required this.activePatients,
    required this.completedAppointments,
    required this.cancelledAppointments,
  });
}

class PatientStatistics {
  final int totalPatients;
  final Map<String, int> ageDistribution;
  final Map<String, int> genderDistribution;
  final Map<String, int> conditionTypes;
  final double averageAge;
  final int patientsWithActiveSessions;

  PatientStatistics({
    required this.totalPatients,
    required this.ageDistribution,
    required this.genderDistribution,
    required this.conditionTypes,
    required this.averageAge,
    required this.patientsWithActiveSessions,
  });
}

class AppointmentAnalytics {
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final int noShowAppointments;
  final double completionRate;
  final double cancellationRate;
  final double noShowRate;
  final Map<AppointmentType, int> typeDistribution;
  final Map<DateTime, int> dailyCounts;
  final double averageAppointmentsPerDay;

  AppointmentAnalytics({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.noShowAppointments,
    required this.completionRate,
    required this.cancellationRate,
    required this.noShowRate,
    required this.typeDistribution,
    required this.dailyCounts,
    required this.averageAppointmentsPerDay,
  });
}

class SessionAnalytics {
  final int totalSessions;
  final double averageSessionsPerPatient;
  final double averageSessionsPerDay;
  final Map<DateTime, int> dailySessionCounts;
  final Map<String, int> patientSessionCounts;
  final int activePatientsCount;

  SessionAnalytics({
    required this.totalSessions,
    required this.averageSessionsPerPatient,
    required this.averageSessionsPerDay,
    required this.dailySessionCounts,
    required this.patientSessionCounts,
    required this.activePatientsCount,
  });
}
