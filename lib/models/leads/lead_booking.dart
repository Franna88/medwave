import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Booking status enum
enum BookingStatus {
  scheduled,
  completed,
  cancelled,
  noShow;

  String get displayName {
    switch (this) {
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => BookingStatus.scheduled,
    );
  }
}

/// Model for a lead booking/appointment
class LeadBooking {
  final String id;
  final String leadId;
  final String leadName;
  final String leadEmail;
  final String leadPhone;
  final DateTime bookingDate;
  final String bookingTime; // Format: "09:30"
  final int duration; // minutes: 15, 30, 45, 60
  final BookingStatus status;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final String? callNotes;
  final String? callOutcome;
  final String leadSource; // e.g., "Facebook Ad - Campaign X"
  final List<String> leadHistory; // Journey: ["Ad Click", "Form Submit", "Week 3 Follow-up"]
  final AICallPrompts aiPrompts;
  final String? assignedTo; // userId of assigned Sales Admin
  final String? assignedToName; // name of assigned Sales Admin

  LeadBooking({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.leadEmail,
    required this.leadPhone,
    required this.bookingDate,
    required this.bookingTime,
    required this.duration,
    required this.status,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.callNotes,
    this.callOutcome,
    required this.leadSource,
    required this.leadHistory,
    required this.aiPrompts,
    this.assignedTo,
    this.assignedToName,
  });

  /// Get booking DateTime combining date and time
  DateTime get bookingDateTime {
    final timeParts = bookingTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      hour,
      minute,
    );
  }

  /// Get booking end time
  DateTime get bookingEndTime {
    return bookingDateTime.add(Duration(minutes: duration));
  }

  /// Get TimeOfDay from bookingTime string
  TimeOfDay get timeOfDay {
    final timeParts = bookingTime.split(':');
    return TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );
  }

  /// Format time for display (e.g., "9:00 AM")
  String get formattedTime {
    final time = timeOfDay;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Format end time for display
  String get formattedEndTime {
    final endDateTime = bookingEndTime;
    final endTime = TimeOfDay.fromDateTime(endDateTime);
    final hour = endTime.hourOfPeriod == 0 ? 12 : endTime.hourOfPeriod;
    final minute = endTime.minute.toString().padLeft(2, '0');
    final period = endTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  factory LeadBooking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeadBooking.fromMap(data, doc.id);
  }

  factory LeadBooking.fromMap(Map<String, dynamic> map, String id) {
    return LeadBooking(
      id: id,
      leadId: map['leadId']?.toString() ?? '',
      leadName: map['leadName']?.toString() ?? '',
      leadEmail: map['leadEmail']?.toString() ?? '',
      leadPhone: map['leadPhone']?.toString() ?? '',
      bookingDate: (map['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookingTime: map['bookingTime']?.toString() ?? '09:00',
      duration: map['duration']?.toInt() ?? 30,
      status: BookingStatus.fromString(map['status']?.toString() ?? 'scheduled'),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      callNotes: map['callNotes']?.toString(),
      callOutcome: map['callOutcome']?.toString(),
      leadSource: map['leadSource']?.toString() ?? 'Unknown',
      leadHistory: (map['leadHistory'] as List<dynamic>?)
              ?.map((h) => h.toString())
              .toList() ??
          [],
      aiPrompts: AICallPrompts.fromMap(
          map['aiPrompts'] as Map<String, dynamic>? ?? {}),
      assignedTo: map['assignedTo']?.toString(),
      assignedToName: map['assignedToName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'leadName': leadName,
      'leadEmail': leadEmail,
      'leadPhone': leadPhone,
      'bookingDate': Timestamp.fromDate(bookingDate),
      'bookingTime': bookingTime,
      'duration': duration,
      'status': status.name,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'callNotes': callNotes,
      'callOutcome': callOutcome,
      'leadSource': leadSource,
      'leadHistory': leadHistory,
      'aiPrompts': aiPrompts.toMap(),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
    };
  }

  LeadBooking copyWith({
    String? id,
    String? leadId,
    String? leadName,
    String? leadEmail,
    String? leadPhone,
    DateTime? bookingDate,
    String? bookingTime,
    int? duration,
    BookingStatus? status,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? callNotes,
    String? callOutcome,
    String? leadSource,
    List<String>? leadHistory,
    AICallPrompts? aiPrompts,
    String? assignedTo,
    String? assignedToName,
  }) {
    return LeadBooking(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      leadName: leadName ?? this.leadName,
      leadEmail: leadEmail ?? this.leadEmail,
      leadPhone: leadPhone ?? this.leadPhone,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      callNotes: callNotes ?? this.callNotes,
      callOutcome: callOutcome ?? this.callOutcome,
      leadSource: leadSource ?? this.leadSource,
      leadHistory: leadHistory ?? this.leadHistory,
      aiPrompts: aiPrompts ?? this.aiPrompts,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }

  /// Create mock booking for testing
  static LeadBooking createMock({
    required String id,
    required String leadId,
    required DateTime bookingDate,
    required String bookingTime,
    int duration = 30,
  }) {
    return LeadBooking(
      id: id,
      leadId: leadId,
      leadName: 'Test Lead',
      leadEmail: 'test@test.com',
      leadPhone: '0701234567',
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      duration: duration,
      status: BookingStatus.scheduled,
      createdBy: 'admin',
      createdByName: 'Admin User',
      createdAt: DateTime.now(),
      leadSource: 'Facebook Ad - Mock Campaign',
      leadHistory: ['Ad Click', 'Form Submit', 'Follow-up'],
      aiPrompts: AICallPrompts.getDefault(),
    );
  }
}

/// AI-powered call preparation prompts
class AICallPrompts {
  final List<String> suggestedQuestions;
  final List<String> keyPoints;
  final Map<String, String> objectionHandling;

  AICallPrompts({
    required this.suggestedQuestions,
    required this.keyPoints,
    required this.objectionHandling,
  });

  factory AICallPrompts.fromMap(Map<String, dynamic> map) {
    return AICallPrompts(
      suggestedQuestions: (map['suggestedQuestions'] as List<dynamic>?)
              ?.map((q) => q.toString())
              .toList() ??
          AICallPrompts.getDefault().suggestedQuestions,
      keyPoints: (map['keyPoints'] as List<dynamic>?)
              ?.map((k) => k.toString())
              .toList() ??
          AICallPrompts.getDefault().keyPoints,
      objectionHandling: Map<String, String>.from(
          map['objectionHandling'] as Map<dynamic, dynamic>? ??
              AICallPrompts.getDefault().objectionHandling),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'suggestedQuestions': suggestedQuestions,
      'keyPoints': keyPoints,
      'objectionHandling': objectionHandling,
    };
  }

  /// Get default AI prompts
  static AICallPrompts getDefault() {
    return AICallPrompts(
      suggestedQuestions: [
        "What initially caught your attention about our service?",
        "Have you used similar products or services before?",
        "What's your timeline for making a decision?",
        "What's most important to you in finding the right solution?",
        "Do you have any specific concerns I can address today?",
      ],
      keyPoints: [
        "Highlight our unique value proposition",
        "Explain pricing options and packages available",
        "Mention any current promotions or special offers",
        "Discuss implementation timeline and next steps",
        "Set clear expectations for follow-up communication",
      ],
      objectionHandling: {
        'price': 'Focus on ROI and long-term value. Break down costs vs. benefits over time.',
        'timing': 'Discuss flexible start dates and phased implementation options.',
        'comparison': 'Highlight key differentiators and unique features competitors don\'t offer.',
        'trust': 'Share customer testimonials, case studies, and success stories.',
        'features': 'Deep dive into specific features that address their needs.',
      },
    );
  }
}

