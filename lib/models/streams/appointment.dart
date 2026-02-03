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
  final List<OptInProduct> optInPackages;
  final Map<String, String>? optInQuestions;
  final String? depositConfirmationToken;
  final String? depositConfirmationStatus; // pending | confirmed | declined
  final DateTime? depositConfirmationSentAt;
  final DateTime? depositConfirmationRespondedAt;
  final DateTime?
  contractEmailSentAt; // When contract link email was sent to customer
  final bool
  manuallyAdded; // Indicates if appointment was manually added to stream
  final String paymentType; // 'deposit' or 'full_payment'
  final String? depositProofUrl; // URL of uploaded proof of payment
  final DateTime? depositProofUploadedAt; // Timestamp of proof upload
  final String? depositProofUploadedBy; // User ID who uploaded proof
  final String? depositProofUploadedByName; // User name who uploaded proof
  final String? customerUploadedProofUrl; // URL of proof uploaded by customer
  final DateTime? customerUploadedProofAt; // When customer uploaded
  final bool customerProofVerified; // Whether sales verified it
  final DateTime? customerProofVerifiedAt; // When sales verified
  final String? customerProofVerifiedBy; // Sales user ID who verified
  final String? customerProofVerifiedByName; // Sales user name who verified
  final bool customerProofRejected; // Whether sales rejected the proof
  final DateTime? customerProofRejectedAt; // When it was rejected
  final String? customerProofRejectedBy; // User ID who rejected
  final String? customerProofRejectedByName; // User name who rejected
  final String? customerProofRejectionReason; // Optional reason for rejection

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
    this.optInPackages = const [],
    this.optInQuestions,
    this.depositConfirmationToken,
    this.depositConfirmationStatus,
    this.depositConfirmationSentAt,
    this.depositConfirmationRespondedAt,
    this.contractEmailSentAt,
    this.manuallyAdded = false,
    this.paymentType = 'deposit',
    this.depositProofUrl,
    this.depositProofUploadedAt,
    this.depositProofUploadedBy,
    this.depositProofUploadedByName,
    this.customerUploadedProofUrl,
    this.customerUploadedProofAt,
    this.customerProofVerified = false,
    this.customerProofVerifiedAt,
    this.customerProofVerifiedBy,
    this.customerProofVerifiedByName,
    this.customerProofRejected = false,
    this.customerProofRejectedAt,
    this.customerProofRejectedBy,
    this.customerProofRejectedByName,
    this.customerProofRejectionReason,
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
      optInPackages:
          (map['optInPackages'] as List<dynamic>?)
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
      contractEmailSentAt: (map['contractEmailSentAt'] as Timestamp?)?.toDate(),
      manuallyAdded: map['manuallyAdded'] == true,
      paymentType: map['paymentType']?.toString() ?? 'deposit',
      depositProofUrl: map['depositProofUrl']?.toString(),
      depositProofUploadedAt: (map['depositProofUploadedAt'] as Timestamp?)
          ?.toDate(),
      depositProofUploadedBy: map['depositProofUploadedBy']?.toString(),
      depositProofUploadedByName: map['depositProofUploadedByName']?.toString(),
      customerUploadedProofUrl: map['customerUploadedProofUrl']?.toString(),
      customerUploadedProofAt: (map['customerUploadedProofAt'] as Timestamp?)
          ?.toDate(),
      customerProofVerified: map['customerProofVerified'] == true,
      customerProofVerifiedAt: (map['customerProofVerifiedAt'] as Timestamp?)
          ?.toDate(),
      customerProofVerifiedBy: map['customerProofVerifiedBy']?.toString(),
      customerProofVerifiedByName: map['customerProofVerifiedByName']
          ?.toString(),
      customerProofRejected: map['customerProofRejected'] == true,
      customerProofRejectedAt: (map['customerProofRejectedAt'] as Timestamp?)
          ?.toDate(),
      customerProofRejectedBy: map['customerProofRejectedBy']?.toString(),
      customerProofRejectedByName: map['customerProofRejectedByName']
          ?.toString(),
      customerProofRejectionReason: map['customerProofRejectionReason']
          ?.toString(),
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
      'optInPackages': optInPackages.map((p) => p.toMap()).toList(),
      if (optInQuestions != null) 'optInQuestions': optInQuestions,
      'depositConfirmationToken': depositConfirmationToken,
      'depositConfirmationStatus': depositConfirmationStatus,
      'depositConfirmationSentAt': depositConfirmationSentAt != null
          ? Timestamp.fromDate(depositConfirmationSentAt!)
          : null,
      'depositConfirmationRespondedAt': depositConfirmationRespondedAt != null
          ? Timestamp.fromDate(depositConfirmationRespondedAt!)
          : null,
      'contractEmailSentAt': contractEmailSentAt != null
          ? Timestamp.fromDate(contractEmailSentAt!)
          : null,
      'manuallyAdded': manuallyAdded,
      'paymentType': paymentType,
      'depositProofUrl': depositProofUrl,
      'depositProofUploadedAt': depositProofUploadedAt != null
          ? Timestamp.fromDate(depositProofUploadedAt!)
          : null,
      'depositProofUploadedBy': depositProofUploadedBy,
      'depositProofUploadedByName': depositProofUploadedByName,
      'customerUploadedProofUrl': customerUploadedProofUrl,
      'customerUploadedProofAt': customerUploadedProofAt != null
          ? Timestamp.fromDate(customerUploadedProofAt!)
          : null,
      'customerProofVerified': customerProofVerified,
      'customerProofVerifiedAt': customerProofVerifiedAt != null
          ? Timestamp.fromDate(customerProofVerifiedAt!)
          : null,
      'customerProofVerifiedBy': customerProofVerifiedBy,
      'customerProofVerifiedByName': customerProofVerifiedByName,
      'customerProofRejected': customerProofRejected,
      'customerProofRejectedAt': customerProofRejectedAt != null
          ? Timestamp.fromDate(customerProofRejectedAt!)
          : null,
      'customerProofRejectedBy': customerProofRejectedBy,
      'customerProofRejectedByName': customerProofRejectedByName,
      'customerProofRejectionReason': customerProofRejectionReason,
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
    List<OptInProduct>? optInPackages,
    Map<String, String>? optInQuestions,
    String? depositConfirmationToken,
    String? depositConfirmationStatus,
    DateTime? depositConfirmationSentAt,
    DateTime? depositConfirmationRespondedAt,
    DateTime? contractEmailSentAt,
    bool? manuallyAdded,
    String? paymentType,
    String? depositProofUrl,
    DateTime? depositProofUploadedAt,
    String? depositProofUploadedBy,
    String? depositProofUploadedByName,
    String? customerUploadedProofUrl,
    DateTime? customerUploadedProofAt,
    bool? customerProofVerified,
    DateTime? customerProofVerifiedAt,
    String? customerProofVerifiedBy,
    String? customerProofVerifiedByName,
    bool? customerProofRejected,
    DateTime? customerProofRejectedAt,
    String? customerProofRejectedBy,
    String? customerProofRejectedByName,
    String? customerProofRejectionReason,
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
      optInPackages: optInPackages ?? this.optInPackages,
      optInQuestions: optInQuestions ?? this.optInQuestions,
      depositConfirmationToken:
          depositConfirmationToken ?? this.depositConfirmationToken,
      depositConfirmationStatus:
          depositConfirmationStatus ?? this.depositConfirmationStatus,
      depositConfirmationSentAt:
          depositConfirmationSentAt ?? this.depositConfirmationSentAt,
      depositConfirmationRespondedAt:
          depositConfirmationRespondedAt ?? this.depositConfirmationRespondedAt,
      contractEmailSentAt: contractEmailSentAt ?? this.contractEmailSentAt,
      manuallyAdded: manuallyAdded ?? this.manuallyAdded,
      paymentType: paymentType ?? this.paymentType,
      depositProofUrl: depositProofUrl ?? this.depositProofUrl,
      depositProofUploadedAt:
          depositProofUploadedAt ?? this.depositProofUploadedAt,
      depositProofUploadedBy:
          depositProofUploadedBy ?? this.depositProofUploadedBy,
      depositProofUploadedByName:
          depositProofUploadedByName ?? this.depositProofUploadedByName,
      customerUploadedProofUrl:
          customerUploadedProofUrl ?? this.customerUploadedProofUrl,
      customerUploadedProofAt:
          customerUploadedProofAt ?? this.customerUploadedProofAt,
      customerProofVerified:
          customerProofVerified ?? this.customerProofVerified,
      customerProofVerifiedAt:
          customerProofVerifiedAt ?? this.customerProofVerifiedAt,
      customerProofVerifiedBy:
          customerProofVerifiedBy ?? this.customerProofVerifiedBy,
      customerProofVerifiedByName:
          customerProofVerifiedByName ?? this.customerProofVerifiedByName,
      customerProofRejected:
          customerProofRejected ?? this.customerProofRejected,
      customerProofRejectedAt:
          customerProofRejectedAt ?? this.customerProofRejectedAt,
      customerProofRejectedBy:
          customerProofRejectedBy ?? this.customerProofRejectedBy,
      customerProofRejectedByName:
          customerProofRejectedByName ?? this.customerProofRejectedByName,
      customerProofRejectionReason:
          customerProofRejectionReason ?? this.customerProofRejectionReason,
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
