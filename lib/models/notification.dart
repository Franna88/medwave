import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  appointment('Appointment'),
  improvement('Improvement Alert'),
  reminder('Reminder'),
  alert('Alert');

  const NotificationType(this.displayName);
  final String displayName;
}

enum NotificationPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const NotificationPriority(this.displayName);
  final String displayName;
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime createdAt;
  final bool isRead;
  final String? patientId;
  final String? patientName;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.isRead = false,
    this.patientId,
    this.patientName,
    this.data,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    DateTime? createdAt,
    bool? isRead,
    String? patientId,
    String? patientName,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'patientId': patientId,
      'patientName': patientName,
      'data': data,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: NotificationType.values.firstWhere((e) => e.name == json['type']),
      priority: NotificationPriority.values.firstWhere((e) => e.name == json['priority']),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      patientId: json['patientId'],
      patientName: json['patientName'],
      data: json['data'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'patientId': patientId,
      'patientName': patientName,
      'data': data,
    };
  }

  /// Create from Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.reminder,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      patientId: data['patientId'],
      patientName: data['patientName'],
      data: data['data'] != null ? Map<String, dynamic>.from(data['data']) : null,
    );
  }
}
