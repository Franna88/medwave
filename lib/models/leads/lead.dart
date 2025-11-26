import 'package:cloud_firestore/cloud_firestore.dart';
import 'lead_note.dart';

/// Model for a lead in the pipeline
class Lead {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String source;
  final String channelId;
  final String currentStage;
  final int? followUpWeek; // 1-10, null if not in follow-up
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stageEnteredAt;
  final List<StageHistoryEntry> stageHistory;
  final List<LeadNote> notes;
  final String createdBy;
  final String? createdByName;
  final double? depositAmount;
  final String? depositInvoiceNumber;
  final double? cashCollectedAmount;
  final String? cashCollectedInvoiceNumber;
  final String? bookingId; // Link to booking
  final DateTime? bookingDate; // Quick reference
  final String? bookingStatus; // Quick reference
  final String? convertedToAppointmentId; // Set when moved to Sales stream

  Lead({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.source,
    required this.channelId,
    required this.currentStage,
    this.followUpWeek,
    required this.createdAt,
    required this.updatedAt,
    required this.stageEnteredAt,
    this.stageHistory = const [],
    this.notes = const [],
    required this.createdBy,
    this.createdByName,
    this.depositAmount,
    this.depositInvoiceNumber,
    this.cashCollectedAmount,
    this.cashCollectedInvoiceNumber,
    this.bookingId,
    this.bookingDate,
    this.bookingStatus,
    this.convertedToAppointmentId,
  });

  /// Get full name
  String get fullName => '$firstName $lastName'.trim();

  /// Get initials for avatar
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  /// Calculate time in current stage
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

  factory Lead.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lead.fromMap(data, doc.id);
  }

  factory Lead.fromMap(Map<String, dynamic> map, String id) {
    return Lead(
      id: id,
      firstName: map['firstName']?.toString() ?? '',
      lastName: map['lastName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      channelId: map['channelId']?.toString() ?? '',
      currentStage: map['currentStage']?.toString() ?? '',
      followUpWeek: map['followUpWeek']?.toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageEnteredAt:
          (map['stageEnteredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageHistory: (map['stageHistory'] as List<dynamic>?)
              ?.map((h) => StageHistoryEntry.fromMap(h as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (map['notes'] as List<dynamic>?)
              ?.map((n) => LeadNote.fromMap(n as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      depositAmount: map['depositAmount']?.toDouble(),
      depositInvoiceNumber: map['depositInvoiceNumber']?.toString(),
      cashCollectedAmount: map['cashCollectedAmount']?.toDouble(),
      cashCollectedInvoiceNumber: map['cashCollectedInvoiceNumber']?.toString(),
      bookingId: map['bookingId']?.toString(),
      bookingDate: (map['bookingDate'] as Timestamp?)?.toDate(),
      bookingStatus: map['bookingStatus']?.toString(),
      convertedToAppointmentId: map['convertedToAppointmentId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'source': source,
      'channelId': channelId,
      'currentStage': currentStage,
      'followUpWeek': followUpWeek,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stageEnteredAt': Timestamp.fromDate(stageEnteredAt),
      'stageHistory': stageHistory.map((h) => h.toMap()).toList(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'depositAmount': depositAmount,
      'depositInvoiceNumber': depositInvoiceNumber,
      'cashCollectedAmount': cashCollectedAmount,
      'cashCollectedInvoiceNumber': cashCollectedInvoiceNumber,
      'bookingId': bookingId,
      'bookingDate': bookingDate != null ? Timestamp.fromDate(bookingDate!) : null,
      'bookingStatus': bookingStatus,
      'convertedToAppointmentId': convertedToAppointmentId,
    };
  }

  Lead copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? source,
    String? channelId,
    String? currentStage,
    int? followUpWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? stageEnteredAt,
    List<StageHistoryEntry>? stageHistory,
    List<LeadNote>? notes,
    String? createdBy,
    String? createdByName,
    double? depositAmount,
    String? depositInvoiceNumber,
    double? cashCollectedAmount,
    String? cashCollectedInvoiceNumber,
    String? bookingId,
    DateTime? bookingDate,
    String? bookingStatus,
    String? convertedToAppointmentId,
  }) {
    return Lead(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      source: source ?? this.source,
      channelId: channelId ?? this.channelId,
      currentStage: currentStage ?? this.currentStage,
      followUpWeek: followUpWeek ?? this.followUpWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageEnteredAt: stageEnteredAt ?? this.stageEnteredAt,
      stageHistory: stageHistory ?? this.stageHistory,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      depositAmount: depositAmount ?? this.depositAmount,
      depositInvoiceNumber: depositInvoiceNumber ?? this.depositInvoiceNumber,
      cashCollectedAmount: cashCollectedAmount ?? this.cashCollectedAmount,
      cashCollectedInvoiceNumber: cashCollectedInvoiceNumber ?? this.cashCollectedInvoiceNumber,
      bookingId: bookingId ?? this.bookingId,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      convertedToAppointmentId: convertedToAppointmentId ?? this.convertedToAppointmentId,
    );
  }
}

/// Model for stage history entry
class StageHistoryEntry {
  final String stage;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final String? note;

  StageHistoryEntry({
    required this.stage,
    required this.enteredAt,
    this.exitedAt,
    this.note,
  });

  factory StageHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StageHistoryEntry(
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

  StageHistoryEntry copyWith({
    String? stage,
    DateTime? enteredAt,
    DateTime? exitedAt,
    String? note,
  }) {
    return StageHistoryEntry(
      stage: stage ?? this.stage,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
      note: note ?? this.note,
    );
  }
}

