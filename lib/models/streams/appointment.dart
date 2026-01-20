import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a sales appointment in the Sales stream
class SalesAppointment {
  final String id;
  final String leadId; // Reference to Marketing Lead
  final String customerName;
  final String email;
  final String phone;
  final String currentStage;
  final DateTime? appointmentDate;
  final String? appointmentTime;
  final double? depositAmount;
  final bool depositPaid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stageEnteredAt;
  final List<SalesAppointmentStageHistoryEntry> stageHistory;
  final List<SalesAppointmentNote> notes;
  final String createdBy;
  final String? createdByName;
  final String? convertedToOrderId; // Set when moved to Operations
  final double? formScore;
  final String? assignedTo; // userId of assigned Sales Admin
  final String? assignedToName; // name of assigned Sales Admin
  final String? optInNote;
  final List<OptInProduct> optInProducts;
  final Map<String, String>? optInQuestions;
  final String? depositConfirmationToken;
  final String? depositConfirmationStatus; // pending | confirmed | declined
  final DateTime? depositConfirmationSentAt;
  final DateTime? depositConfirmationRespondedAt;
  final bool
  manuallyAdded; // Indicates if appointment was manually added to stream
  final String paymentType; // 'deposit' or 'full_payment'

  SalesAppointment({
    required this.id,
    required this.leadId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.currentStage,
    this.appointmentDate,
    this.appointmentTime,
    this.depositAmount,
    this.depositPaid = false,
    required this.createdAt,
    required this.updatedAt,
    required this.stageEnteredAt,
    this.stageHistory = const [],
    this.notes = const [],
    required this.createdBy,
    this.createdByName,
    this.convertedToOrderId,
    this.formScore,
    this.assignedTo,
    this.assignedToName,
    this.optInNote,
    this.optInProducts = const [],
    this.optInQuestions,
    this.depositConfirmationToken,
    this.depositConfirmationStatus,
    this.depositConfirmationSentAt,
    this.depositConfirmationRespondedAt,
    this.manuallyAdded = false,
    this.paymentType = 'deposit',
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

  factory SalesAppointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalesAppointment.fromMap(data, doc.id);
  }

  factory SalesAppointment.fromMap(Map<String, dynamic> map, String id) {
    return SalesAppointment(
      id: id,
      leadId: map['leadId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      currentStage: map['currentStage']?.toString() ?? '',
      appointmentDate: (map['appointmentDate'] as Timestamp?)?.toDate(),
      appointmentTime: map['appointmentTime']?.toString(),
      depositAmount: map['depositAmount']?.toDouble(),
      depositPaid: map['depositPaid'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageEnteredAt:
          (map['stageEnteredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageHistory:
          (map['stageHistory'] as List<dynamic>?)
              ?.map(
                (h) => SalesAppointmentStageHistoryEntry.fromMap(
                  h as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      notes:
          (map['notes'] as List<dynamic>?)
              ?.map(
                (n) => SalesAppointmentNote.fromMap(n as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      convertedToOrderId: map['convertedToOrderId']?.toString(),
      formScore: map['formScore'] != null
          ? (map['formScore'] as num?)?.toDouble()
          : null,
      assignedTo: map['assignedTo']?.toString(),
      assignedToName: map['assignedToName']?.toString(),
      optInNote: map['optInNote']?.toString(),
      optInProducts:
          (map['optInProducts'] as List<dynamic>?)
              ?.map(
                (item) => OptInProduct.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      optInQuestions: (map['optInQuestions'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      depositConfirmationToken: map['depositConfirmationToken']?.toString(),
      depositConfirmationStatus: map['depositConfirmationStatus']?.toString(),
      depositConfirmationSentAt:
          (map['depositConfirmationSentAt'] as Timestamp?)?.toDate(),
      depositConfirmationRespondedAt:
          (map['depositConfirmationRespondedAt'] as Timestamp?)?.toDate(),
      manuallyAdded: map['manuallyAdded'] == true,
      paymentType: map['paymentType']?.toString() ?? 'deposit',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leadId': leadId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'currentStage': currentStage,
      'appointmentDate': appointmentDate != null
          ? Timestamp.fromDate(appointmentDate!)
          : null,
      'appointmentTime': appointmentTime,
      'depositAmount': depositAmount,
      'depositPaid': depositPaid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stageEnteredAt': Timestamp.fromDate(stageEnteredAt),
      'stageHistory': stageHistory.map((h) => h.toMap()).toList(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'convertedToOrderId': convertedToOrderId,
      'formScore': formScore,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'optInNote': optInNote,
      'optInProducts': optInProducts.map((p) => p.toMap()).toList(),
      if (optInQuestions != null) 'optInQuestions': optInQuestions,
      'depositConfirmationToken': depositConfirmationToken,
      'depositConfirmationStatus': depositConfirmationStatus,
      'depositConfirmationSentAt': depositConfirmationSentAt != null
          ? Timestamp.fromDate(depositConfirmationSentAt!)
          : null,
      'depositConfirmationRespondedAt': depositConfirmationRespondedAt != null
          ? Timestamp.fromDate(depositConfirmationRespondedAt!)
          : null,
      'manuallyAdded': manuallyAdded,
      'paymentType': paymentType,
    };
  }

  SalesAppointment copyWith({
    String? id,
    String? leadId,
    String? customerName,
    String? email,
    String? phone,
    String? currentStage,
    DateTime? appointmentDate,
    String? appointmentTime,
    double? depositAmount,
    bool? depositPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? stageEnteredAt,
    List<SalesAppointmentStageHistoryEntry>? stageHistory,
    List<SalesAppointmentNote>? notes,
    String? createdBy,
    String? createdByName,
    String? convertedToOrderId,
    double? formScore,
    String? assignedTo,
    String? assignedToName,
    String? optInNote,
    List<OptInProduct>? optInProducts,
    Map<String, String>? optInQuestions,
    String? depositConfirmationToken,
    String? depositConfirmationStatus,
    DateTime? depositConfirmationSentAt,
    DateTime? depositConfirmationRespondedAt,
    bool? manuallyAdded,
    String? paymentType,
  }) {
    return SalesAppointment(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      currentStage: currentStage ?? this.currentStage,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      depositAmount: depositAmount ?? this.depositAmount,
      depositPaid: depositPaid ?? this.depositPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageEnteredAt: stageEnteredAt ?? this.stageEnteredAt,
      stageHistory: stageHistory ?? this.stageHistory,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      convertedToOrderId: convertedToOrderId ?? this.convertedToOrderId,
      formScore: formScore ?? this.formScore,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      optInNote: optInNote ?? this.optInNote,
      optInProducts: optInProducts ?? this.optInProducts,
      optInQuestions: optInQuestions ?? this.optInQuestions,
      depositConfirmationToken:
          depositConfirmationToken ?? this.depositConfirmationToken,
      depositConfirmationStatus:
          depositConfirmationStatus ?? this.depositConfirmationStatus,
      depositConfirmationSentAt:
          depositConfirmationSentAt ?? this.depositConfirmationSentAt,
      depositConfirmationRespondedAt:
          depositConfirmationRespondedAt ?? this.depositConfirmationRespondedAt,
      manuallyAdded: manuallyAdded ?? this.manuallyAdded,
      paymentType: paymentType ?? this.paymentType,
    );
  }

  /// Check if this is a full payment appointment (priority for installation)
  bool get isFullPayment => paymentType == 'full_payment';

  /// Requires: contract signed, deposit paid, and customer confirmed
  bool get isReadyForOperations {
    return currentStage == 'deposit_made' &&
        depositPaid == true &&
        depositConfirmationStatus == 'confirmed';
  }
}

/// Model for sales appointment stage history entry
class SalesAppointmentStageHistoryEntry {
  final String stage;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final String? note;

  SalesAppointmentStageHistoryEntry({
    required this.stage,
    required this.enteredAt,
    this.exitedAt,
    this.note,
  });

  factory SalesAppointmentStageHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SalesAppointmentStageHistoryEntry(
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

/// Model for sales appointment notes
class SalesAppointmentNote {
  final String text;
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;
  final String? stageTransition; // e.g., "opt_in → deposit_requested"

  SalesAppointmentNote({
    required this.text,
    required this.createdAt,
    required this.createdBy,
    this.createdByName,
    this.stageTransition,
  });

  factory SalesAppointmentNote.fromMap(Map<String, dynamic> map) {
    return SalesAppointmentNote(
      text: map['text']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      stageTransition: map['stageTransition']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'stageTransition': stageTransition,
    };
  }
}

class OptInProduct {
  final String id;
  final String name;
  final double price;
  final int quantity;

  const OptInProduct({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory OptInProduct.fromMap(Map<String, dynamic> map) {
    return OptInProduct(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toInt() : 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price, 'quantity': quantity};
  }
}
