import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/notification.dart';

class NotificationService {
  final NotificationProvider _notificationProvider;

  NotificationService(this._notificationProvider);

  // Generate notifications based on patient progress
  void checkPatientProgress(Patient patient) {
    // Check for significant pain reduction
    if (patient.sessions.isNotEmpty) {
      final latestSession = patient.sessions.last;
      if (latestSession.vasScore < 3) {
        _notificationProvider.addPatientImprovementAlert(
          patient.id,
          patient.name,
          'pain reduction',
          70.0, // Calculate actual percentage
        );
      }
    }

    // Check for wound healing progress
    if (patient.sessions.isNotEmpty) {
      final latestSession = patient.sessions.last;
      if (latestSession.wounds.isNotEmpty) {
        final totalWoundArea = latestSession.wounds.fold<double>(
          0, (sum, wound) => sum + wound.area);
        if (totalWoundArea < 2.0) {
          _notificationProvider.addPatientImprovementAlert(
            patient.id,
            patient.name,
            'wound healing',
            60.0, // Calculate actual percentage
          );
        }
      }
    }

    // Check for missed sessions
    final missedSessions = _calculateMissedSessions(patient);
    if (missedSessions > 0) {
      _notificationProvider.addTreatmentComplianceAlert(
        patient.id,
        patient.name,
        missedSessions,
      );
    }
  }

  // Generate appointment reminders
  void checkUpcomingAppointments(List<Appointment> appointments) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    for (final appointment in appointments) {
      final appointmentDate = appointment.startTime;
      final daysUntilAppointment = appointmentDate.difference(now).inDays;

      // Remind 1 day before
      if (daysUntilAppointment == 1) {
        _notificationProvider.addAppointmentReminder(
          appointment.patientId,
          appointment.patientName,
          appointmentDate,
        );
      }

      // Urgent reminder for same day appointments
      if (daysUntilAppointment == 0 && appointmentDate.hour > now.hour) {
        _notificationProvider.addUrgentPatientAlert(
          appointment.patientId,
          appointment.patientName,
          'Same Day Appointment',
          'Appointment scheduled for ${DateFormat('HH:mm').format(appointmentDate)}',
        );
      }
    }
  }

  // Generate assessment reminders
  void checkAssessmentDue(List<Patient> patients) {
    final now = DateTime.now();

    for (final patient in patients) {
      if (patient.sessions.length >= 6) {
        // 6-week assessment due
        final firstSession = patient.sessions.first;
        final weeksSinceFirstSession = now.difference(firstSession.date).inDays ~/ 7;

        if (weeksSinceFirstSession >= 6) {
          _notificationProvider.addAssessmentDueReminder(
            patient.id,
            patient.name,
            '6-week',
          );
        }
      }

      if (patient.sessions.length >= 12) {
        // 12-week assessment due
        final firstSession = patient.sessions.first;
        final weeksSinceFirstSession = now.difference(firstSession.date).inDays ~/ 7;

        if (weeksSinceFirstSession >= 12) {
          _notificationProvider.addAssessmentDueReminder(
            patient.id,
            patient.name,
            '12-week',
          );
        }
      }
    }
  }

  // Generate weekly progress report
  void generateWeeklyReport(List<Patient> patients) {
    final improvedPatients = patients.where((p) => p.hasImprovement).length;
    final totalPatients = patients.length;
    final attentionNeeded = patients.where((p) => p.sessions.isNotEmpty && 
        p.sessions.last.vasScore > 6).length;

    if (improvedPatients > 0 || attentionNeeded > 0) {
      _notificationProvider.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Weekly Progress Report',
          message: 'This week: $improvedPatients patients showed improvement, $attentionNeeded need attention out of $totalPatients total patients.',
          type: NotificationType.alert,
          priority: NotificationPriority.low,
          createdAt: DateTime.now(),
          data: {
            'improvedPatients': improvedPatients,
            'attentionNeeded': attentionNeeded,
            'totalPatients': totalPatients,
          },
        ),
      );
    }
  }

  // Check for patient deterioration
  void checkPatientDeterioration(Patient patient) {
    if (patient.sessions.length >= 2) {
      final lastSession = patient.sessions.last;
      final previousSession = patient.sessions[patient.sessions.length - 2];

      // Check for increased pain
      if (lastSession.vasScore > previousSession.vasScore + 2) {
        _notificationProvider.addUrgentPatientAlert(
          patient.id,
          patient.name,
          'Pain Increase',
          'Pain level increased from ${previousSession.vasScore} to ${lastSession.vasScore}',
        );
      }

      // Check for wound deterioration
      if (lastSession.wounds.isNotEmpty && previousSession.wounds.isNotEmpty) {
        final lastTotalArea = lastSession.wounds.fold<double>(0, (sum, wound) => sum + wound.area);
        final previousTotalArea = previousSession.wounds.fold<double>(0, (sum, wound) => sum + wound.area);
        
        if (lastTotalArea > previousTotalArea * 1.2) {
          _notificationProvider.addUrgentPatientAlert(
            patient.id,
            patient.name,
            'Wound Deterioration',
            'Wound area increased by ${((lastTotalArea / previousTotalArea - 1) * 100).toStringAsFixed(1)}%',
          );
        }
      }
    }
  }

  // Calculate missed sessions
  int _calculateMissedSessions(Patient patient) {
    if (patient.sessions.isEmpty) return 0;

    final now = DateTime.now();
    final lastSession = patient.sessions.last;
    final daysSinceLastSession = now.difference(lastSession.date).inDays;

    // Assuming sessions should be weekly
    if (daysSinceLastSession > 14) {
      return (daysSinceLastSession / 7).floor();
    }

    return 0;
  }

  // Generate treatment milestone notifications
  void checkTreatmentMilestones(Patient patient) {
    final sessionCount = patient.sessions.length;

    // Milestone notifications
    if (sessionCount == 5) {
      _notificationProvider.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Treatment Milestone',
          message: '${patient.name} has completed 5 sessions. Consider progress evaluation.',
          type: NotificationType.improvement,
          priority: NotificationPriority.medium,
          createdAt: DateTime.now(),
          patientId: patient.id,
          patientName: patient.name,
          data: {'sessionCount': sessionCount},
        ),
      );
    }

    if (sessionCount == 10) {
      _notificationProvider.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Treatment Milestone',
          message: '${patient.name} has completed 10 sessions. Ready for comprehensive assessment.',
          type: NotificationType.improvement,
          priority: NotificationPriority.high,
          createdAt: DateTime.now(),
          patientId: patient.id,
          patientName: patient.name,
          data: {'sessionCount': sessionCount},
        ),
      );
    }
  }

  // Generate discharge planning notifications
  void checkDischargeReadiness(Patient patient) {
    if (patient.sessions.length >= 8) {
      final recentSessions = patient.sessions.skip(patient.sessions.length - 3).toList();
      bool allLowPain = true;
      bool allSmallWounds = true;

      for (final session in recentSessions) {
        if (session.vasScore > 2) {
          allLowPain = false;
        }
        if (session.wounds.isNotEmpty) {
          final totalWoundArea = session.wounds.fold<double>(0, (sum, wound) => sum + wound.area);
          if (totalWoundArea > 1.0) {
            allSmallWounds = false;
          }
        }
      }

      if (allLowPain && allSmallWounds) {
        _notificationProvider.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Discharge Planning',
            message: '${patient.name} shows consistent improvement. Consider discharge planning.',
            type: NotificationType.improvement,
            priority: NotificationPriority.high,
            createdAt: DateTime.now(),
            patientId: patient.id,
            patientName: patient.name,
            data: {'dischargeReady': true},
          ),
        );
      }
    }
  }
}
