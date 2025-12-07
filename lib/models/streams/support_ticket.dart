import 'package:cloud_firestore/cloud_firestore.dart';

/// Priority levels for support tickets
enum TicketPriority { low, medium, high, urgent }

/// Model for a support ticket in the Support stream
class SupportTicket {
  final String id;
  final String orderId; // Reference to Operations Order
  final String customerName;
  final String email;
  final String phone;
  final String currentStage;
  final String? issueDescription;
  final TicketPriority priority;
  final String? resolution;
  final int? satisfactionRating; // 1-5 stars
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stageEnteredAt;
  final List<TicketStageHistoryEntry> stageHistory;
  final List<TicketNote> notes;
  final String createdBy;
  final String? createdByName;
  final double? formScore;

  SupportTicket({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.currentStage,
    this.issueDescription,
    this.priority = TicketPriority.medium,
    this.resolution,
    this.satisfactionRating,
    required this.createdAt,
    required this.updatedAt,
    required this.stageEnteredAt,
    this.stageHistory = const [],
    this.notes = const [],
    required this.createdBy,
    this.createdByName,
    this.formScore,
  });

  /// Get time in current stage
  Duration get timeInStage => DateTime.now().difference(stageEnteredAt);

  /// Get time in stage as human-readable string
  String get timeInStageDisplay {
    final duration = timeInStage;
    if (duration.inDays > 0) {
      return '${duration.inDays}d';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  /// Get priority display text
  String get priorityDisplay {
    switch (priority) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
      case TicketPriority.urgent:
        return 'Urgent';
    }
  }

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket.fromMap(data, doc.id);
  }

  factory SupportTicket.fromMap(Map<String, dynamic> map, String id) {
    return SupportTicket(
      id: id,
      orderId: map['orderId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      currentStage: map['currentStage']?.toString() ?? '',
      issueDescription: map['issueDescription']?.toString(),
      priority: TicketPriority.values.firstWhere(
        (e) => e.toString() == 'TicketPriority.${map['priority']}',
        orElse: () => TicketPriority.medium,
      ),
      resolution: map['resolution']?.toString(),
      satisfactionRating: map['satisfactionRating']?.toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageEnteredAt:
          (map['stageEnteredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageHistory:
          (map['stageHistory'] as List<dynamic>?)
              ?.map(
                (h) =>
                    TicketStageHistoryEntry.fromMap(h as Map<String, dynamic>),
              )
              .toList() ??
          [],
      notes:
          (map['notes'] as List<dynamic>?)
              ?.map((n) => TicketNote.fromMap(n as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      formScore: map['formScore'] != null
          ? (map['formScore'] as num?)?.toDouble()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'currentStage': currentStage,
      'issueDescription': issueDescription,
      'priority': priority.toString().split('.').last,
      'resolution': resolution,
      'satisfactionRating': satisfactionRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stageEnteredAt': Timestamp.fromDate(stageEnteredAt),
      'stageHistory': stageHistory.map((h) => h.toMap()).toList(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'formScore': formScore,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? orderId,
    String? customerName,
    String? email,
    String? phone,
    String? currentStage,
    String? issueDescription,
    TicketPriority? priority,
    String? resolution,
    int? satisfactionRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? stageEnteredAt,
    List<TicketStageHistoryEntry>? stageHistory,
    List<TicketNote>? notes,
    String? createdBy,
    String? createdByName,
    double? formScore,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      currentStage: currentStage ?? this.currentStage,
      issueDescription: issueDescription ?? this.issueDescription,
      priority: priority ?? this.priority,
      resolution: resolution ?? this.resolution,
      satisfactionRating: satisfactionRating ?? this.satisfactionRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageEnteredAt: stageEnteredAt ?? this.stageEnteredAt,
      stageHistory: stageHistory ?? this.stageHistory,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      formScore: formScore ?? this.formScore,
    );
  }
}

/// Model for ticket stage history entry
class TicketStageHistoryEntry {
  final String stage;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final String? note;

  TicketStageHistoryEntry({
    required this.stage,
    required this.enteredAt,
    this.exitedAt,
    this.note,
  });

  factory TicketStageHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TicketStageHistoryEntry(
      stage: map['stage']?.toString() ?? '',
      enteredAt: (map['enteredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exitedAt: (map['exitedAt'] as Timestamp?)?.toDate(),
      note: map['note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stage': stage,
      'enteredAt': Timestamp.fromDate(enteredAt),
      'exitedAt': exitedAt != null ? Timestamp.fromDate(exitedAt!) : null,
      'note': note,
    };
  }
}

/// Model for ticket notes
class TicketNote {
  final String text;
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;

  TicketNote({
    required this.text,
    required this.createdAt,
    required this.createdBy,
    this.createdByName,
  });

  factory TicketNote.fromMap(Map<String, dynamic> map) {
    return TicketNote(
      text: map['text']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }
}
