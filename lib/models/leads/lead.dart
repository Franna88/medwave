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
  final String? assignedTo; // userId of assigned marketing admin
  final String? assignedToName; // name of assigned marketing admin
  final double? depositAmount;
  final String? depositInvoiceNumber;
  final double? cashCollectedAmount;
  final String? cashCollectedInvoiceNumber;
  final String? bookingId; // Link to booking
  final DateTime? bookingDate; // Quick reference
  final String? bookingStatus; // Quick reference
  final String? convertedToAppointmentId; // Set when moved to Sales stream
  final String? submissionId; // Link to FormSubmission
  // UTM tracking fields
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmCampaignId;
  final String? utmAdset;
  final String? utmAdsetId;
  final String? utmAd;
  final String? utmAdId;
  final String? fbclid;

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
    this.assignedTo,
    this.assignedToName,
    this.depositAmount,
    this.depositInvoiceNumber,
    this.cashCollectedAmount,
    this.cashCollectedInvoiceNumber,
    this.bookingId,
    this.bookingDate,
    this.bookingStatus,
    this.convertedToAppointmentId,
    this.submissionId,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmCampaignId,
    this.utmAdset,
    this.utmAdsetId,
    this.utmAd,
    this.utmAdId,
    this.fbclid,
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

  /// Helper function to parse timestamp from either Timestamp object or ISO string
  static DateTime _parseTimestamp(dynamic value, DateTime defaultValue) {
    if (value == null) return defaultValue;

    // If it's already a Timestamp object, convert to DateTime
    if (value is Timestamp) {
      return value.toDate();
    }

    // If it's a string (ISO format), parse it
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (e) {
        return defaultValue;
      }
    }

    return defaultValue;
  }

  /// Helper function to parse optional timestamp
  static DateTime? _parseOptionalTimestamp(dynamic value) {
    if (value == null) return null;

    // If it's already a Timestamp object, convert to DateTime
    if (value is Timestamp) {
      return value.toDate();
    }

    // If it's a string (ISO format), parse it
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (e) {
        return null;
      }
    }

    return null;
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
      createdAt: _parseTimestamp(map['createdAt'], DateTime.now()),
      updatedAt: _parseTimestamp(map['updatedAt'], DateTime.now()),
      stageEnteredAt: _parseTimestamp(map['stageEnteredAt'], DateTime.now()),
      stageHistory:
          (map['stageHistory'] as List<dynamic>?)
              ?.map((h) => StageHistoryEntry.fromMap(h as Map<String, dynamic>))
              .toList() ??
          [],
      notes:
          (map['notes'] as List<dynamic>?)
              ?.map((n) => LeadNote.fromMap(n as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      assignedTo: map['assignedTo']?.toString(),
      assignedToName: map['assignedToName']?.toString(),
      depositAmount: map['depositAmount']?.toDouble(),
      depositInvoiceNumber: map['depositInvoiceNumber']?.toString(),
      cashCollectedAmount: map['cashCollectedAmount']?.toDouble(),
      cashCollectedInvoiceNumber: map['cashCollectedInvoiceNumber']?.toString(),
      bookingId: map['bookingId']?.toString(),
      bookingDate: _parseOptionalTimestamp(map['bookingDate']),
      bookingStatus: map['bookingStatus']?.toString(),
      convertedToAppointmentId: map['convertedToAppointmentId']?.toString(),
      submissionId: map['submissionId']?.toString(),
      utmSource: map['utmSource']?.toString(),
      utmMedium: map['utmMedium']?.toString(),
      utmCampaign: map['utmCampaign']?.toString(),
      utmCampaignId: map['utmCampaignId']?.toString(),
      utmAdset: map['utmAdset']?.toString(),
      utmAdsetId: map['utmAdsetId']?.toString(),
      utmAd: map['utmAd']?.toString(),
      utmAdId: map['utmAdId']?.toString(),
      fbclid: map['fbclid']?.toString(),
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
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'depositAmount': depositAmount,
      'depositInvoiceNumber': depositInvoiceNumber,
      'cashCollectedAmount': cashCollectedAmount,
      'cashCollectedInvoiceNumber': cashCollectedInvoiceNumber,
      'bookingId': bookingId,
      'bookingDate': bookingDate != null
          ? Timestamp.fromDate(bookingDate!)
          : null,
      'bookingStatus': bookingStatus,
      'convertedToAppointmentId': convertedToAppointmentId,
      'submissionId': submissionId,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'utmCampaignId': utmCampaignId,
      'utmAdset': utmAdset,
      'utmAdsetId': utmAdsetId,
      'utmAd': utmAd,
      'utmAdId': utmAdId,
      'fbclid': fbclid,
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
    String? assignedTo,
    String? assignedToName,
    double? depositAmount,
    String? depositInvoiceNumber,
    double? cashCollectedAmount,
    String? cashCollectedInvoiceNumber,
    String? bookingId,
    DateTime? bookingDate,
    String? bookingStatus,
    String? convertedToAppointmentId,
    String? submissionId,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? utmCampaignId,
    String? utmAdset,
    String? utmAdsetId,
    String? utmAd,
    String? utmAdId,
    String? fbclid,
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
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      depositAmount: depositAmount ?? this.depositAmount,
      depositInvoiceNumber: depositInvoiceNumber ?? this.depositInvoiceNumber,
      cashCollectedAmount: cashCollectedAmount ?? this.cashCollectedAmount,
      cashCollectedInvoiceNumber:
          cashCollectedInvoiceNumber ?? this.cashCollectedInvoiceNumber,
      bookingId: bookingId ?? this.bookingId,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      convertedToAppointmentId:
          convertedToAppointmentId ?? this.convertedToAppointmentId,
      submissionId: submissionId ?? this.submissionId,
      utmSource: utmSource ?? this.utmSource,
      utmMedium: utmMedium ?? this.utmMedium,
      utmCampaign: utmCampaign ?? this.utmCampaign,
      utmCampaignId: utmCampaignId ?? this.utmCampaignId,
      utmAdset: utmAdset ?? this.utmAdset,
      utmAdsetId: utmAdsetId ?? this.utmAdsetId,
      utmAd: utmAd ?? this.utmAd,
      utmAdId: utmAdId ?? this.utmAdId,
      fbclid: fbclid ?? this.fbclid,
    );
  }
}

/// Model for stage history entry
class StageHistoryEntry {
  final String stage;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final dynamic note; // Can be String or Map<String, dynamic> for questionnaire

  StageHistoryEntry({
    required this.stage,
    required this.enteredAt,
    this.exitedAt,
    this.note,
  });

  factory StageHistoryEntry.fromMap(Map<String, dynamic> map) {
    // Handle both String and Map formats for backward compatibility
    dynamic noteValue = map['note'];
    
    // If note is a Map, preserve it as Map
    if (noteValue is Map) {
      noteValue = Map<String, dynamic>.from(noteValue);
    } else if (noteValue != null) {
      // Otherwise treat as String
      noteValue = noteValue.toString();
    }

    return StageHistoryEntry(
      stage: map['stage']?.toString() ?? '',
      enteredAt: Lead._parseTimestamp(map['enteredAt'], DateTime.now()),
      exitedAt: Lead._parseOptionalTimestamp(map['exitedAt']),
      note: noteValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stage': stage,
      'enteredAt': Timestamp.fromDate(enteredAt),
      'exitedAt': exitedAt != null ? Timestamp.fromDate(exitedAt!) : null,
      'note': note, // Store as-is (String, Map, or null)
    };
  }

  StageHistoryEntry copyWith({
    String? stage,
    DateTime? enteredAt,
    DateTime? exitedAt,
    dynamic note,
  }) {
    return StageHistoryEntry(
      stage: stage ?? this.stage,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
      note: note ?? this.note,
    );
  }
}
