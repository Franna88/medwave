import 'package:cloud_firestore/cloud_firestore.dart';

/// Status for installation booking
enum InstallBookingStatus {
  pending('pending'),
  datesSelected('dates_selected'),
  confirmed('confirmed');

  const InstallBookingStatus(this.value);
  final String value;

  static InstallBookingStatus fromString(String value) {
    return InstallBookingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InstallBookingStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case InstallBookingStatus.pending:
        return 'Pending';
      case InstallBookingStatus.datesSelected:
        return 'Dates Selected';
      case InstallBookingStatus.confirmed:
        return 'Confirmed';
    }
  }
}

/// Model for an order in the Operations stream
class Order {
  final String id;
  final String appointmentId; // Reference to Sales Appointment
  final String customerName;
  final String email;
  final String phone;
  final String currentStage;
  final DateTime? orderDate;
  final List<OrderItem> items;
  final DateTime? deliveryDate;
  final String? invoiceNumber;
  final DateTime? installDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stageEnteredAt;
  final List<OrderStageHistoryEntry> stageHistory;
  final List<OrderNote> notes;
  final String createdBy;
  final String? createdByName;
  final String? convertedToTicketId; // Set when moved to Support
  final double? formScore;
  final Map<String, String>? optInQuestions; // Questionnaire from opt-in stage

  // Installation booking fields
  final String? installBookingToken; // Security token for email link
  final List<DateTime> customerSelectedDates; // Customer's 3 preferred dates
  final DateTime? confirmedInstallDate; // Final admin-set install date
  final String? assignedInstallerId; // Installer assignment
  final String? assignedInstallerName;
  final String? assignedInstallerPhone; // Installer phone for customer contact
  final String? assignedInstallerEmail; // Installer email for customer contact
  final InstallBookingStatus installBookingStatus;
  final DateTime? installBookingEmailSentAt;

  // Inventory picking fields
  final Map<String, bool> pickedItems; // item name -> picked status
  final String? trackingNumber;
  final String? deliveryType; // 'courier' or 'manual'
  final String?
  vehicleRegistrationNumber; // Vehicle registration for manual delivery
  final String? waybillPhotoUrl;
  final DateTime? pickedAt;
  final String? pickedBy;
  final String? pickedByName;

  /// Total number of flattened pick rows (individual items including package constituents). Used for progress when set.
  final int? totalFlattenedItemCount;

  // Installation completion fields
  final List<String>
  proofOfInstallationPhotoUrls; // Multiple images for multiple installations
  final String? customerSignaturePhotoUrl;

  // Payment confirmation fields
  final String? paymentConfirmationToken; // Security token for email link
  final String?
  paymentConfirmationStatus; // 'pending' | 'confirmed' | 'declined'
  final DateTime? paymentConfirmationSentAt; // When email was sent
  final DateTime? paymentConfirmationRespondedAt; // When customer responded

  // Invoice PDF
  final String? invoicePdfUrl; // Firebase Storage URL for invoice PDF

  // Priority order flag (full payment leads get installation priority)
  final bool isPriorityOrder;

  // Order splitting fields
  final String?
  splitFromOrderId; // Reference to parent order when this is a split order
  final List<ShippedItemFromParent>
  shippedItemsFromParentOrder; // Items already shipped in parent order with waybill info
  final List<OrderItem>
  remainingItemsFromParentOrder; // Items from parent order that were NOT overridden (stayed in Order 1)

  // Installation sign-off fields
  final String? installationSignoffId; // Reference to sign-off document
  final bool hasInstallationSignoff;
  final DateTime? installationSignoffCreatedAt;
  final DateTime? installationSignedOffAt;

  // Final payment proof fields (operations-uploaded)
  final String? finalPaymentProofUrl; // URL of proof uploaded by operations
  final DateTime? finalPaymentProofUploadedAt; // Timestamp of proof upload
  final String? finalPaymentProofUploadedBy; // User ID who uploaded proof
  final String? finalPaymentProofUploadedByName; // User name who uploaded proof

  // Final payment proof fields (customer-uploaded)
  final String?
  customerUploadedFinalPaymentProofUrl; // URL of proof uploaded by customer
  final DateTime? customerUploadedFinalPaymentProofAt; // When customer uploaded
  final bool
  customerFinalPaymentProofVerified; // Whether operations verified it
  final DateTime?
  customerFinalPaymentProofVerifiedAt; // When operations verified
  final String? customerFinalPaymentProofVerifiedBy; // User ID who verified
  final String?
  customerFinalPaymentProofVerifiedByName; // User name who verified

  // Final payment proof rejection fields
  final bool customerFinalPaymentProofRejected; // Whether proof was rejected
  final DateTime? customerFinalPaymentProofRejectedAt; // When rejected
  final String? customerFinalPaymentProofRejectedBy; // User ID who rejected
  final String?
  customerFinalPaymentProofRejectedByName; // User name who rejected
  final String?
  customerFinalPaymentProofRejectionReason; // Reason for rejection

  Order({
    required this.id,
    required this.appointmentId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.currentStage,
    this.orderDate,
    this.items = const [],
    this.deliveryDate,
    this.invoiceNumber,
    this.installDate,
    required this.createdAt,
    required this.updatedAt,
    required this.stageEnteredAt,
    this.stageHistory = const [],
    this.notes = const [],
    required this.createdBy,
    this.createdByName,
    this.convertedToTicketId,
    this.formScore,
    this.optInQuestions,
    // Installation booking fields
    this.installBookingToken,
    this.customerSelectedDates = const [],
    this.confirmedInstallDate,
    this.assignedInstallerId,
    this.assignedInstallerName,
    this.assignedInstallerPhone,
    this.assignedInstallerEmail,
    this.installBookingStatus = InstallBookingStatus.pending,
    this.installBookingEmailSentAt,
    // Inventory picking fields
    this.pickedItems = const {},
    this.trackingNumber,
    this.deliveryType,
    this.vehicleRegistrationNumber,
    this.waybillPhotoUrl,
    this.pickedAt,
    this.pickedBy,
    this.pickedByName,
    this.totalFlattenedItemCount,
    // Installation completion fields
    this.proofOfInstallationPhotoUrls = const [],
    this.customerSignaturePhotoUrl,
    // Payment confirmation fields
    this.paymentConfirmationToken,
    this.paymentConfirmationStatus,
    this.paymentConfirmationSentAt,
    this.paymentConfirmationRespondedAt,
    // Invoice PDF
    this.invoicePdfUrl,
    // Priority order flag
    this.isPriorityOrder = false,
    // Order splitting fields
    this.splitFromOrderId,
    this.shippedItemsFromParentOrder = const [],
    this.remainingItemsFromParentOrder = const [],
    // Installation sign-off fields
    this.installationSignoffId,
    this.hasInstallationSignoff = false,
    this.installationSignoffCreatedAt,
    this.installationSignedOffAt,
    // Final payment proof fields (operations-uploaded)
    this.finalPaymentProofUrl,
    this.finalPaymentProofUploadedAt,
    this.finalPaymentProofUploadedBy,
    this.finalPaymentProofUploadedByName,
    // Final payment proof fields (customer-uploaded)
    this.customerUploadedFinalPaymentProofUrl,
    this.customerUploadedFinalPaymentProofAt,
    this.customerFinalPaymentProofVerified = false,
    this.customerFinalPaymentProofVerifiedAt,
    this.customerFinalPaymentProofVerifiedBy,
    this.customerFinalPaymentProofVerifiedByName,
    // Final payment proof rejection fields
    this.customerFinalPaymentProofRejected = false,
    this.customerFinalPaymentProofRejectedAt,
    this.customerFinalPaymentProofRejectedBy,
    this.customerFinalPaymentProofRejectedByName,
    this.customerFinalPaymentProofRejectionReason,
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

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order.fromMap(data, doc.id);
  }

  factory Order.fromMap(Map<String, dynamic> map, String id) {
    return Order(
      id: id,
      appointmentId: map['appointmentId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      currentStage: map['currentStage']?.toString() ?? '',
      orderDate: (map['orderDate'] as Timestamp?)?.toDate(),
      items:
          (map['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryDate: (map['deliveryDate'] as Timestamp?)?.toDate(),
      invoiceNumber: map['invoiceNumber']?.toString(),
      installDate: (map['installDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageEnteredAt:
          (map['stageEnteredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stageHistory:
          (map['stageHistory'] as List<dynamic>?)
              ?.map(
                (h) =>
                    OrderStageHistoryEntry.fromMap(h as Map<String, dynamic>),
              )
              .toList() ??
          [],
      notes:
          (map['notes'] as List<dynamic>?)
              ?.map((n) => OrderNote.fromMap(n as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      convertedToTicketId: map['convertedToTicketId']?.toString(),
      formScore: map['formScore'] != null
          ? (map['formScore'] as num?)?.toDouble()
          : null,
      optInQuestions: (map['optInQuestions'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      // Installation booking fields
      installBookingToken: map['installBookingToken']?.toString(),
      customerSelectedDates:
          (map['customerSelectedDates'] as List<dynamic>?)
              ?.map((d) => (d as Timestamp).toDate())
              .toList() ??
          [],
      confirmedInstallDate: (map['confirmedInstallDate'] as Timestamp?)
          ?.toDate(),
      assignedInstallerId: map['assignedInstallerId']?.toString(),
      assignedInstallerName: map['assignedInstallerName']?.toString(),
      assignedInstallerPhone: map['assignedInstallerPhone']?.toString(),
      assignedInstallerEmail: map['assignedInstallerEmail']?.toString(),
      installBookingStatus: InstallBookingStatus.fromString(
        map['installBookingStatus']?.toString() ?? 'pending',
      ),
      installBookingEmailSentAt:
          (map['installBookingEmailSentAt'] as Timestamp?)?.toDate(),
      // Inventory picking fields
      pickedItems:
          (map['pickedItems'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as bool),
          ) ??
          {},
      trackingNumber: map['trackingNumber']?.toString(),
      deliveryType: map['deliveryType']?.toString(),
      vehicleRegistrationNumber: map['vehicleRegistrationNumber']?.toString(),
      waybillPhotoUrl: map['waybillPhotoUrl']?.toString(),
      pickedAt: (map['pickedAt'] as Timestamp?)?.toDate(),
      pickedBy: map['pickedBy']?.toString(),
      pickedByName: map['pickedByName']?.toString(),
      totalFlattenedItemCount: (map['totalFlattenedItemCount'] as num?)
          ?.toInt(),
      // Installation completion fields
      proofOfInstallationPhotoUrls:
          (map['proofOfInstallationPhotoUrls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList() ??
          (map['proofOfInstallationPhotoUrl'] != null
              ? [map['proofOfInstallationPhotoUrl'].toString()]
              : []), // Support legacy single image format
      customerSignaturePhotoUrl: map['customerSignaturePhotoUrl']?.toString(),
      // Payment confirmation fields
      paymentConfirmationToken: map['paymentConfirmationToken']?.toString(),
      paymentConfirmationStatus: map['paymentConfirmationStatus']?.toString(),
      paymentConfirmationSentAt:
          (map['paymentConfirmationSentAt'] as Timestamp?)?.toDate(),
      paymentConfirmationRespondedAt:
          (map['paymentConfirmationRespondedAt'] as Timestamp?)?.toDate(),
      invoicePdfUrl: map['invoicePdfUrl']?.toString(),
      isPriorityOrder: map['isPriorityOrder'] == true,
      // Order splitting fields
      splitFromOrderId: map['splitFromOrderId']?.toString(),
      shippedItemsFromParentOrder:
          (map['shippedItemsFromParentOrder'] as List<dynamic>?)
              ?.map(
                (i) => ShippedItemFromParent.fromMap(i as Map<String, dynamic>),
              )
              .toList() ??
          [],
      remainingItemsFromParentOrder:
          (map['remainingItemsFromParentOrder'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      // Installation sign-off fields
      installationSignoffId: map['installationSignoffId']?.toString(),
      hasInstallationSignoff: map['hasInstallationSignoff'] == true,
      installationSignoffCreatedAt:
          (map['installationSignoffCreatedAt'] as Timestamp?)?.toDate(),
      installationSignedOffAt: (map['installationSignedOffAt'] as Timestamp?)
          ?.toDate(),
      // Final payment proof fields (operations-uploaded)
      finalPaymentProofUrl: map['finalPaymentProofUrl']?.toString(),
      finalPaymentProofUploadedAt:
          (map['finalPaymentProofUploadedAt'] as Timestamp?)?.toDate(),
      finalPaymentProofUploadedBy: map['finalPaymentProofUploadedBy']
          ?.toString(),
      finalPaymentProofUploadedByName: map['finalPaymentProofUploadedByName']
          ?.toString(),
      // Final payment proof fields (customer-uploaded)
      customerUploadedFinalPaymentProofUrl:
          map['customerUploadedFinalPaymentProofUrl']?.toString(),
      customerUploadedFinalPaymentProofAt:
          (map['customerUploadedFinalPaymentProofAt'] as Timestamp?)?.toDate(),
      customerFinalPaymentProofVerified:
          map['customerFinalPaymentProofVerified'] == true,
      customerFinalPaymentProofVerifiedAt:
          (map['customerFinalPaymentProofVerifiedAt'] as Timestamp?)?.toDate(),
      customerFinalPaymentProofVerifiedBy:
          map['customerFinalPaymentProofVerifiedBy']?.toString(),
      customerFinalPaymentProofVerifiedByName:
          map['customerFinalPaymentProofVerifiedByName']?.toString(),
      // Final payment proof rejection fields
      customerFinalPaymentProofRejected:
          map['customerFinalPaymentProofRejected'] == true,
      customerFinalPaymentProofRejectedAt:
          (map['customerFinalPaymentProofRejectedAt'] as Timestamp?)?.toDate(),
      customerFinalPaymentProofRejectedBy:
          map['customerFinalPaymentProofRejectedBy']?.toString(),
      customerFinalPaymentProofRejectedByName:
          map['customerFinalPaymentProofRejectedByName']?.toString(),
      customerFinalPaymentProofRejectionReason:
          map['customerFinalPaymentProofRejectionReason']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'currentStage': currentStage,
      'orderDate': orderDate != null ? Timestamp.fromDate(orderDate!) : null,
      'items': items.map((i) => i.toMap()).toList(),
      'deliveryDate': deliveryDate != null
          ? Timestamp.fromDate(deliveryDate!)
          : null,
      'invoiceNumber': invoiceNumber,
      'installDate': installDate != null
          ? Timestamp.fromDate(installDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'stageEnteredAt': Timestamp.fromDate(stageEnteredAt),
      'stageHistory': stageHistory.map((h) => h.toMap()).toList(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'convertedToTicketId': convertedToTicketId,
      'formScore': formScore,
      if (optInQuestions != null) 'optInQuestions': optInQuestions,
      // Installation booking fields
      'installBookingToken': installBookingToken,
      'customerSelectedDates': customerSelectedDates
          .map((d) => Timestamp.fromDate(d))
          .toList(),
      'confirmedInstallDate': confirmedInstallDate != null
          ? Timestamp.fromDate(confirmedInstallDate!)
          : null,
      'assignedInstallerId': assignedInstallerId,
      'assignedInstallerName': assignedInstallerName,
      'assignedInstallerPhone': assignedInstallerPhone,
      'assignedInstallerEmail': assignedInstallerEmail,
      'installBookingStatus': installBookingStatus.value,
      'installBookingEmailSentAt': installBookingEmailSentAt != null
          ? Timestamp.fromDate(installBookingEmailSentAt!)
          : null,
      // Inventory picking fields
      'pickedItems': pickedItems,
      'trackingNumber': trackingNumber,
      'deliveryType': deliveryType,
      'vehicleRegistrationNumber': vehicleRegistrationNumber,
      'waybillPhotoUrl': waybillPhotoUrl,
      'pickedAt': pickedAt != null ? Timestamp.fromDate(pickedAt!) : null,
      'pickedBy': pickedBy,
      'pickedByName': pickedByName,
      if (totalFlattenedItemCount != null)
        'totalFlattenedItemCount': totalFlattenedItemCount,
      // Installation completion fields
      'proofOfInstallationPhotoUrls': proofOfInstallationPhotoUrls,
      'customerSignaturePhotoUrl': customerSignaturePhotoUrl,
      // Payment confirmation fields
      'paymentConfirmationToken': paymentConfirmationToken,
      'paymentConfirmationStatus': paymentConfirmationStatus,
      'paymentConfirmationSentAt': paymentConfirmationSentAt != null
          ? Timestamp.fromDate(paymentConfirmationSentAt!)
          : null,
      'paymentConfirmationRespondedAt': paymentConfirmationRespondedAt != null
          ? Timestamp.fromDate(paymentConfirmationRespondedAt!)
          : null,
      'invoicePdfUrl': invoicePdfUrl,
      'isPriorityOrder': isPriorityOrder,
      // Order splitting fields
      'splitFromOrderId': splitFromOrderId,
      'shippedItemsFromParentOrder': shippedItemsFromParentOrder
          .map((i) => i.toMap())
          .toList(),
      'remainingItemsFromParentOrder': remainingItemsFromParentOrder
          .map((i) => i.toMap())
          .toList(),
      // Installation sign-off fields
      'installationSignoffId': installationSignoffId,
      'hasInstallationSignoff': hasInstallationSignoff,
      'installationSignoffCreatedAt': installationSignoffCreatedAt != null
          ? Timestamp.fromDate(installationSignoffCreatedAt!)
          : null,
      'installationSignedOffAt': installationSignedOffAt != null
          ? Timestamp.fromDate(installationSignedOffAt!)
          : null,
      // Final payment proof fields (operations-uploaded)
      'finalPaymentProofUrl': finalPaymentProofUrl,
      'finalPaymentProofUploadedAt': finalPaymentProofUploadedAt != null
          ? Timestamp.fromDate(finalPaymentProofUploadedAt!)
          : null,
      'finalPaymentProofUploadedBy': finalPaymentProofUploadedBy,
      'finalPaymentProofUploadedByName': finalPaymentProofUploadedByName,
      // Final payment proof fields (customer-uploaded)
      'customerUploadedFinalPaymentProofUrl':
          customerUploadedFinalPaymentProofUrl,
      'customerUploadedFinalPaymentProofAt':
          customerUploadedFinalPaymentProofAt != null
          ? Timestamp.fromDate(customerUploadedFinalPaymentProofAt!)
          : null,
      'customerFinalPaymentProofVerified': customerFinalPaymentProofVerified,
      'customerFinalPaymentProofVerifiedAt':
          customerFinalPaymentProofVerifiedAt != null
          ? Timestamp.fromDate(customerFinalPaymentProofVerifiedAt!)
          : null,
      'customerFinalPaymentProofVerifiedBy':
          customerFinalPaymentProofVerifiedBy,
      'customerFinalPaymentProofVerifiedByName':
          customerFinalPaymentProofVerifiedByName,
      // Final payment proof rejection fields
      'customerFinalPaymentProofRejected': customerFinalPaymentProofRejected,
      'customerFinalPaymentProofRejectedAt':
          customerFinalPaymentProofRejectedAt != null
          ? Timestamp.fromDate(customerFinalPaymentProofRejectedAt!)
          : null,
      'customerFinalPaymentProofRejectedBy':
          customerFinalPaymentProofRejectedBy,
      'customerFinalPaymentProofRejectedByName':
          customerFinalPaymentProofRejectedByName,
      'customerFinalPaymentProofRejectionReason':
          customerFinalPaymentProofRejectionReason,
    };
  }

  Order copyWith({
    String? id,
    String? appointmentId,
    String? customerName,
    String? email,
    String? phone,
    String? currentStage,
    DateTime? orderDate,
    List<OrderItem>? items,
    DateTime? deliveryDate,
    String? invoiceNumber,
    DateTime? installDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? stageEnteredAt,
    List<OrderStageHistoryEntry>? stageHistory,
    List<OrderNote>? notes,
    String? createdBy,
    String? createdByName,
    String? convertedToTicketId,
    double? formScore,
    Map<String, String>? optInQuestions,
    // Installation booking fields
    String? installBookingToken,
    List<DateTime>? customerSelectedDates,
    DateTime? confirmedInstallDate,
    String? assignedInstallerId,
    String? assignedInstallerName,
    String? assignedInstallerPhone,
    String? assignedInstallerEmail,
    InstallBookingStatus? installBookingStatus,
    DateTime? installBookingEmailSentAt,
    // Inventory picking fields
    Map<String, bool>? pickedItems,
    String? trackingNumber,
    String? deliveryType,
    String? vehicleRegistrationNumber,
    String? waybillPhotoUrl,
    DateTime? pickedAt,
    String? pickedBy,
    String? pickedByName,
    int? totalFlattenedItemCount,
    // Installation completion fields
    List<String>? proofOfInstallationPhotoUrls,
    String? customerSignaturePhotoUrl,
    // Payment confirmation fields
    String? paymentConfirmationToken,
    String? paymentConfirmationStatus,
    DateTime? paymentConfirmationSentAt,
    DateTime? paymentConfirmationRespondedAt,
    // Invoice PDF
    String? invoicePdfUrl,
    // Priority order flag
    bool? isPriorityOrder,
    // Order splitting fields
    String? splitFromOrderId,
    List<ShippedItemFromParent>? shippedItemsFromParentOrder,
    List<OrderItem>? remainingItemsFromParentOrder,
    // Installation sign-off fields
    String? installationSignoffId,
    bool? hasInstallationSignoff,
    DateTime? installationSignoffCreatedAt,
    DateTime? installationSignedOffAt,
    // Final payment proof fields (operations-uploaded)
    String? finalPaymentProofUrl,
    DateTime? finalPaymentProofUploadedAt,
    String? finalPaymentProofUploadedBy,
    String? finalPaymentProofUploadedByName,
    // Final payment proof fields (customer-uploaded)
    String? customerUploadedFinalPaymentProofUrl,
    DateTime? customerUploadedFinalPaymentProofAt,
    bool? customerFinalPaymentProofVerified,
    DateTime? customerFinalPaymentProofVerifiedAt,
    String? customerFinalPaymentProofVerifiedBy,
    String? customerFinalPaymentProofVerifiedByName,
    // Final payment proof rejection fields
    bool? customerFinalPaymentProofRejected,
    DateTime? customerFinalPaymentProofRejectedAt,
    String? customerFinalPaymentProofRejectedBy,
    String? customerFinalPaymentProofRejectedByName,
    String? customerFinalPaymentProofRejectionReason,
  }) {
    return Order(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      currentStage: currentStage ?? this.currentStage,
      orderDate: orderDate ?? this.orderDate,
      items: items ?? this.items,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      installDate: installDate ?? this.installDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stageEnteredAt: stageEnteredAt ?? this.stageEnteredAt,
      stageHistory: stageHistory ?? this.stageHistory,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      convertedToTicketId: convertedToTicketId ?? this.convertedToTicketId,
      formScore: formScore ?? this.formScore,
      optInQuestions: optInQuestions ?? this.optInQuestions,
      // Installation booking fields
      installBookingToken: installBookingToken ?? this.installBookingToken,
      customerSelectedDates:
          customerSelectedDates ?? this.customerSelectedDates,
      confirmedInstallDate: confirmedInstallDate ?? this.confirmedInstallDate,
      assignedInstallerId: assignedInstallerId ?? this.assignedInstallerId,
      assignedInstallerName:
          assignedInstallerName ?? this.assignedInstallerName,
      assignedInstallerPhone:
          assignedInstallerPhone ?? this.assignedInstallerPhone,
      assignedInstallerEmail:
          assignedInstallerEmail ?? this.assignedInstallerEmail,
      installBookingStatus: installBookingStatus ?? this.installBookingStatus,
      installBookingEmailSentAt:
          installBookingEmailSentAt ?? this.installBookingEmailSentAt,
      // Inventory picking fields
      pickedItems: pickedItems ?? this.pickedItems,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      deliveryType: deliveryType ?? this.deliveryType,
      vehicleRegistrationNumber:
          vehicleRegistrationNumber ?? this.vehicleRegistrationNumber,
      waybillPhotoUrl: waybillPhotoUrl ?? this.waybillPhotoUrl,
      pickedAt: pickedAt ?? this.pickedAt,
      pickedBy: pickedBy ?? this.pickedBy,
      pickedByName: pickedByName ?? this.pickedByName,
      totalFlattenedItemCount:
          totalFlattenedItemCount ?? this.totalFlattenedItemCount,
      // Installation completion fields
      proofOfInstallationPhotoUrls:
          proofOfInstallationPhotoUrls ?? this.proofOfInstallationPhotoUrls,
      customerSignaturePhotoUrl:
          customerSignaturePhotoUrl ?? this.customerSignaturePhotoUrl,
      // Payment confirmation fields
      paymentConfirmationToken:
          paymentConfirmationToken ?? this.paymentConfirmationToken,
      paymentConfirmationStatus:
          paymentConfirmationStatus ?? this.paymentConfirmationStatus,
      paymentConfirmationSentAt:
          paymentConfirmationSentAt ?? this.paymentConfirmationSentAt,
      paymentConfirmationRespondedAt:
          paymentConfirmationRespondedAt ?? this.paymentConfirmationRespondedAt,
      invoicePdfUrl: invoicePdfUrl ?? this.invoicePdfUrl,
      isPriorityOrder: isPriorityOrder ?? this.isPriorityOrder,
      // Order splitting fields
      splitFromOrderId: splitFromOrderId ?? this.splitFromOrderId,
      shippedItemsFromParentOrder:
          shippedItemsFromParentOrder ?? this.shippedItemsFromParentOrder,
      remainingItemsFromParentOrder:
          remainingItemsFromParentOrder ?? this.remainingItemsFromParentOrder,
      // Installation sign-off fields
      installationSignoffId:
          installationSignoffId ?? this.installationSignoffId,
      hasInstallationSignoff:
          hasInstallationSignoff ?? this.hasInstallationSignoff,
      installationSignoffCreatedAt:
          installationSignoffCreatedAt ?? this.installationSignoffCreatedAt,
      installationSignedOffAt:
          installationSignedOffAt ?? this.installationSignedOffAt,
      // Final payment proof fields (operations-uploaded)
      finalPaymentProofUrl: finalPaymentProofUrl ?? this.finalPaymentProofUrl,
      finalPaymentProofUploadedAt:
          finalPaymentProofUploadedAt ?? this.finalPaymentProofUploadedAt,
      finalPaymentProofUploadedBy:
          finalPaymentProofUploadedBy ?? this.finalPaymentProofUploadedBy,
      finalPaymentProofUploadedByName:
          finalPaymentProofUploadedByName ??
          this.finalPaymentProofUploadedByName,
      // Final payment proof fields (customer-uploaded)
      customerUploadedFinalPaymentProofUrl:
          customerUploadedFinalPaymentProofUrl ??
          this.customerUploadedFinalPaymentProofUrl,
      customerUploadedFinalPaymentProofAt:
          customerUploadedFinalPaymentProofAt ??
          this.customerUploadedFinalPaymentProofAt,
      customerFinalPaymentProofVerified:
          customerFinalPaymentProofVerified ??
          this.customerFinalPaymentProofVerified,
      customerFinalPaymentProofVerifiedAt:
          customerFinalPaymentProofVerifiedAt ??
          this.customerFinalPaymentProofVerifiedAt,
      customerFinalPaymentProofVerifiedBy:
          customerFinalPaymentProofVerifiedBy ??
          this.customerFinalPaymentProofVerifiedBy,
      customerFinalPaymentProofVerifiedByName:
          customerFinalPaymentProofVerifiedByName ??
          this.customerFinalPaymentProofVerifiedByName,
      // Final payment proof rejection fields
      customerFinalPaymentProofRejected:
          customerFinalPaymentProofRejected ??
          this.customerFinalPaymentProofRejected,
      customerFinalPaymentProofRejectedAt:
          customerFinalPaymentProofRejectedAt ??
          this.customerFinalPaymentProofRejectedAt,
      customerFinalPaymentProofRejectedBy:
          customerFinalPaymentProofRejectedBy ??
          this.customerFinalPaymentProofRejectedBy,
      customerFinalPaymentProofRejectedByName:
          customerFinalPaymentProofRejectedByName ??
          this.customerFinalPaymentProofRejectedByName,
      customerFinalPaymentProofRejectionReason:
          customerFinalPaymentProofRejectionReason ??
          this.customerFinalPaymentProofRejectionReason,
    );
  }

  /// Get the earliest customer selected date for sorting
  DateTime? get earliestSelectedDate {
    if (customerSelectedDates.isEmpty) return null;
    return customerSelectedDates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Get count of picked items
  int get pickedItemCount => pickedItems.values.where((v) => v).length;

  /// Get total item count (sum of quantities)
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Check if all items are picked
  bool get allItemsPicked {
    if (totalFlattenedItemCount != null) {
      return pickedItemCount >= totalFlattenedItemCount!;
    }
    if (items.isEmpty) return false;
    for (final item in items) {
      // Check each item by name - if quantity > 1, we still just need one tick
      if (pickedItems[item.name] != true) return false;
    }
    return true;
  }

  /// Get picking progress as percentage (0.0 to 1.0)
  double get pickingProgress {
    if (totalFlattenedItemCount != null && totalFlattenedItemCount! > 0) {
      return (pickedItemCount / totalFlattenedItemCount!).clamp(0.0, 1.0);
    }
    if (items.isEmpty) return 0.0;
    return pickedItemCount / items.length;
  }

  /// Display item count for warehouse card (flattened when available).
  int get displayItemCount => totalFlattenedItemCount ?? items.length;

  /// Check if picking has started but not completed
  bool get isPartiallyPicked => pickedItemCount > 0 && !allItemsPicked;

  /// Check if order is ready for shipping (all picked + tracking + waybill)
  bool get isReadyForDelivery =>
      allItemsPicked &&
      trackingNumber != null &&
      trackingNumber!.isNotEmpty &&
      waybillPhotoUrl != null &&
      waybillPhotoUrl!.isNotEmpty;
}

/// Model for order items
class OrderItem {
  final String name;
  final int quantity;
  final double? price;

  /// Product id when this line is a product (for inventory match).
  final String? productId;

  /// Package id when this line is a package (expand to package items for stock).
  final String? packageId;

  OrderItem({
    required this.name,
    required this.quantity,
    this.price,
    this.productId,
    this.packageId,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name']?.toString() ?? '',
      quantity: map['quantity']?.toInt() ?? 1,
      price: map['price']?.toDouble(),
      productId: map['productId']?.toString(),
      packageId: map['packageId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      if (productId != null) 'productId': productId,
      if (packageId != null) 'packageId': packageId,
    };
  }
}

/// Model for order stage history entry
class OrderStageHistoryEntry {
  final String stage;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final String? note;

  OrderStageHistoryEntry({
    required this.stage,
    required this.enteredAt,
    this.exitedAt,
    this.note,
  });

  factory OrderStageHistoryEntry.fromMap(Map<String, dynamic> map) {
    return OrderStageHistoryEntry(
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

/// Model for items shipped in parent order (for split orders)
class ShippedItemFromParent {
  final String itemName;
  final int quantity;
  final String? trackingNumber; // Tracking number from Order 1
  final String?
  waybillNumber; // Waybill number from Order 1 - MUST be prominently displayed
  final String? waybillPhotoUrl; // Waybill photo URL from Order 1

  ShippedItemFromParent({
    required this.itemName,
    required this.quantity,
    this.trackingNumber,
    this.waybillNumber,
    this.waybillPhotoUrl,
  });

  factory ShippedItemFromParent.fromMap(Map<String, dynamic> map) {
    return ShippedItemFromParent(
      itemName: map['itemName']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      trackingNumber: map['trackingNumber']?.toString(),
      waybillNumber: map['waybillNumber']?.toString(),
      waybillPhotoUrl: map['waybillPhotoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'quantity': quantity,
      'trackingNumber': trackingNumber,
      'waybillNumber': waybillNumber,
      'waybillPhotoUrl': waybillPhotoUrl,
    };
  }

  ShippedItemFromParent copyWith({
    String? itemName,
    int? quantity,
    String? trackingNumber,
    String? waybillNumber,
    String? waybillPhotoUrl,
  }) {
    return ShippedItemFromParent(
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      waybillPhotoUrl: waybillPhotoUrl ?? this.waybillPhotoUrl,
    );
  }
}

/// Model for order notes
class OrderNote {
  final String text;
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;

  OrderNote({
    required this.text,
    required this.createdAt,
    required this.createdBy,
    this.createdByName,
  });

  factory OrderNote.fromMap(Map<String, dynamic> map) {
    return OrderNote(
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
