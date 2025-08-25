import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentType {
  consultation('Consultation'),
  followUp('Follow-up'),
  treatment('Treatment'),
  assessment('Assessment'),
  emergency('Emergency');

  const AppointmentType(this.displayName);
  final String displayName;
}

enum AppointmentStatus {
  scheduled('Scheduled'),
  confirmed('Confirmed'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled'),
  noShow('No Show'),
  rescheduled('Rescheduled');

  const AppointmentStatus(this.displayName);
  final String displayName;

  Color get color {
    switch (this) {
      case AppointmentStatus.scheduled:
        return Colors.blue;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.inProgress:
        return Colors.orange;
      case AppointmentStatus.completed:
        return Colors.teal;
      case AppointmentStatus.cancelled:
        return Colors.red;
      case AppointmentStatus.noShow:
        return Colors.grey;
      case AppointmentStatus.rescheduled:
        return Colors.purple;
    }
  }
}

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentType type;
  final AppointmentStatus status;
  final String? practitionerId;
  final String? practitionerName;
  final String? location;
  final List<String> notes;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final String? reminderSent;
  final Map<String, dynamic>? metadata;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.status,
    this.practitionerId,
    this.practitionerName,
    this.location,
    required this.notes,
    required this.createdAt,
    this.lastUpdated,
    this.reminderSent,
    this.metadata,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
           startTime.month == now.month &&
           startTime.day == now.day;
  }

  bool get isUpcoming {
    return startTime.isAfter(DateTime.now());
  }

  bool get isPast {
    return endTime.isBefore(DateTime.now());
  }

  bool get isActive {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  bool get canBeModified {
    return status != AppointmentStatus.completed &&
           status != AppointmentStatus.cancelled &&
           status != AppointmentStatus.noShow;
  }

  String get timeRange {
    final start = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Appointment copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    AppointmentType? type,
    AppointmentStatus? status,
    String? practitionerId,
    String? practitionerName,
    String? location,
    List<String>? notes,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? reminderSent,
    Map<String, dynamic>? metadata,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      status: status ?? this.status,
      practitionerId: practitionerId ?? this.practitionerId,
      practitionerName: practitionerName ?? this.practitionerName,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      reminderSent: reminderSent ?? this.reminderSent,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type.name,
      'status': status.name,
      'practitionerId': practitionerId,
      'practitionerName': practitionerName,
      'location': location,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'reminderSent': reminderSent,
      'metadata': metadata,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      patientId: json['patientId'],
      patientName: json['patientName'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      type: AppointmentType.values.firstWhere((e) => e.name == json['type']),
      status: AppointmentStatus.values.firstWhere((e) => e.name == json['status']),
      practitionerId: json['practitionerId'],
      practitionerName: json['practitionerName'],
      location: json['location'],
      notes: List<String>.from(json['notes'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
      reminderSent: json['reminderSent'],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Appointment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Appointment(id: $id, patientName: $patientName, title: $title, startTime: $startTime, status: $status)';
  }

  // Firestore serialization methods
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'type': type.name,
      'status': status.name,
      'practitionerId': practitionerId,
      'practitionerName': practitionerName,
      'location': location,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'reminderSent': reminderSent,
      'metadata': metadata,
      // Additional fields for Firebase
      'dateKey': '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}',
      'timeSlot': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'duration': duration.inMinutes,
    };
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      startTime: data['startTime']?.toDate() ?? DateTime.now(),
      endTime: data['endTime']?.toDate() ?? DateTime.now(),
      type: AppointmentType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AppointmentType.consultation,
      ),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AppointmentStatus.scheduled,
      ),
      practitionerId: data['practitionerId'],
      practitionerName: data['practitionerName'],
      location: data['location'],
      notes: List<String>.from(data['notes'] ?? []),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      lastUpdated: data['lastUpdated']?.toDate(),
      reminderSent: data['reminderSent'],
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
    );
  }
}

// Helper class for calendar events
class CalendarEvent {
  final Appointment appointment;
  final DateTime date;

  CalendarEvent({
    required this.appointment,
    required this.date,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent && 
           other.appointment.id == appointment.id &&
           other.date.day == date.day &&
           other.date.month == date.month &&
           other.date.year == date.year;
  }

  @override
  int get hashCode => appointment.id.hashCode ^ date.hashCode;
}
