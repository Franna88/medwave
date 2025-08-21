import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';

class NotificationProvider with ChangeNotifier {
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  List<AppNotification> get urgentNotifications => 
      _notifications.where((n) => n.priority == NotificationPriority.urgent && !n.isRead).toList();

  int get unreadCount => unreadNotifications.length;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    setLoading(true);
    
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    _loadSampleNotifications();
    
    setLoading(false);
  }

  void _loadSampleNotifications() {
    final now = DateTime.now();
    
    final sampleNotifications = [
      AppNotification(
        id: '1',
        title: 'Urgent: Patient Deterioration',
        message: 'John Smith shows increased pain levels and requires immediate attention',
        type: NotificationType.alert,
        priority: NotificationPriority.urgent,
        createdAt: now.subtract(const Duration(minutes: 30)),
        patientId: '1',
        patientName: 'John Smith',
        data: {'painLevel': 8, 'previousPainLevel': 4},
      ),
      AppNotification(
        id: '2',
        title: 'Excellent Progress!',
        message: 'Sarah Johnson shows 65% pain reduction after 6 sessions - treatment plan working exceptionally well',
        type: NotificationType.improvement,
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(hours: 2)),
        patientId: '2',
        patientName: 'Sarah Johnson',
        data: {'painReduction': 65.0, 'sessionCount': 6},
      ),
      AppNotification(
        id: '3',
        title: 'Appointment Reminder',
        message: 'Michael Chen - Session 4 scheduled for tomorrow at 2:00 PM. Patient requested early session.',
        type: NotificationType.appointment,
        priority: NotificationPriority.medium,
        createdAt: now.subtract(const Duration(hours: 4)),
        patientId: '3',
        patientName: 'Michael Chen',
        data: {'appointmentTime': '2:00 PM', 'sessionNumber': 4},
      ),
      AppNotification(
        id: '4',
        title: 'Treatment Compliance Alert',
        message: 'Emma Williams missed 2 consecutive sessions. Consider reaching out to patient.',
        type: NotificationType.reminder,
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(days: 1)),
        patientId: '4',
        patientName: 'Emma Williams',
        data: {'missedSessions': 2},
      ),
      AppNotification(
        id: '5',
        title: 'Weekly Progress Report',
        message: 'Patient progress reports for this week are ready. 8 patients showed improvement, 2 need attention.',
        type: NotificationType.alert,
        priority: NotificationPriority.low,
        createdAt: now.subtract(const Duration(days: 2)),
        data: {'improvedPatients': 8, 'attentionNeeded': 2},
      ),
      AppNotification(
        id: '6',
        title: 'Wound Healing Milestone',
        message: 'David Brown - Wound size reduced by 45% since baseline. Ready for next phase of treatment.',
        type: NotificationType.improvement,
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(days: 3)),
        patientId: '5',
        patientName: 'David Brown',
        data: {'woundReduction': 45.0},
      ),
      AppNotification(
        id: '7',
        title: 'Assessment Due',
        message: 'Lisa Anderson - 6-week assessment due today. Patient has completed initial treatment phase.',
        type: NotificationType.reminder,
        priority: NotificationPriority.medium,
        createdAt: now.subtract(const Duration(days: 4)),
        patientId: '6',
        patientName: 'Lisa Anderson',
        data: {'assessmentType': '6-week', 'treatmentPhase': 'initial'},
      ),
      AppNotification(
        id: '8',
        title: 'Treatment Goal Achieved',
        message: 'Robert Wilson achieved 80% mobility improvement. Consider discharge planning.',
        type: NotificationType.improvement,
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(days: 5)),
        patientId: '7',
        patientName: 'Robert Wilson',
        data: {'mobilityImprovement': 80.0},
      ),
    ];

    _notifications.clear();
    _notifications.addAll(sampleNotifications);
  }

  Future<void> addNotification(AppNotification notification) async {
    _notifications.insert(0, notification); // Add to beginning for newest first
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  // Auto-generate notifications based on patient progress
  void checkForProgressAlerts(String patientId, double painReduction, double woundHealing) {
    if (painReduction > 30) {
      addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Significant Pain Reduction',
        message: 'Patient shows ${painReduction.toStringAsFixed(1)}% pain reduction',
        type: NotificationType.improvement,
        priority: NotificationPriority.high,
        createdAt: DateTime.now(),
        patientId: patientId,
      ));
    }

    if (woundHealing > 40) {
      addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Excellent Wound Healing',
        message: 'Wound healing progress: ${woundHealing.toStringAsFixed(1)}%',
        type: NotificationType.improvement,
        priority: NotificationPriority.high,
        createdAt: DateTime.now(),
        patientId: patientId,
      ));
    }
  }

  void addAppointmentReminder(String patientId, String patientName, DateTime appointmentTime) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Appointment Reminder',
      message: '$patientName - Appointment scheduled for ${DateFormat('MMM d, yyyy at HH:mm').format(appointmentTime)}',
      type: NotificationType.appointment,
      priority: NotificationPriority.medium,
      createdAt: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      data: {'appointmentTime': appointmentTime.toIso8601String()},
    ));
  }

  void addPatientImprovementAlert(String patientId, String patientName, String improvementType, double percentage) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Patient Improvement Alert',
      message: '$patientName shows ${percentage.toStringAsFixed(1)}% improvement in $improvementType',
      type: NotificationType.improvement,
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      data: {'improvementType': improvementType, 'percentage': percentage},
    ));
  }

  void addTreatmentComplianceAlert(String patientId, String patientName, int missedSessions) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Treatment Compliance Alert',
      message: '$patientName has missed $missedSessions consecutive sessions. Consider intervention.',
      type: NotificationType.reminder,
      priority: missedSessions >= 3 ? NotificationPriority.urgent : NotificationPriority.high,
      createdAt: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      data: {'missedSessions': missedSessions},
    ));
  }

  void addAssessmentDueReminder(String patientId, String patientName, String assessmentType) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Assessment Due',
      message: '$patientName - $assessmentType assessment is due. Please schedule evaluation.',
      type: NotificationType.reminder,
      priority: NotificationPriority.medium,
      createdAt: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      data: {'assessmentType': assessmentType},
    ));
  }

  void addUrgentPatientAlert(String patientId, String patientName, String alertType, String details) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Urgent: $alertType',
      message: '$patientName - $details. Immediate attention required.',
      type: NotificationType.alert,
      priority: NotificationPriority.urgent,
      createdAt: DateTime.now(),
      patientId: patientId,
      patientName: patientName,
      data: {'alertType': alertType, 'details': details},
    ));
  }

  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get notifications by priority
  List<AppNotification> getNotificationsByPriority(NotificationPriority priority) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  // Get recent notifications (last 7 days)
  List<AppNotification> getRecentNotifications() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _notifications.where((n) => n.createdAt.isAfter(weekAgo)).toList();
  }

  // Clear old notifications (older than 30 days)
  void clearOldNotifications() {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    _notifications.removeWhere((n) => n.createdAt.isBefore(monthAgo));
    notifyListeners();
  }
}
