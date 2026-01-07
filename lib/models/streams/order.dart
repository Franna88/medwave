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
  final String? waybillPhotoUrl;
  final DateTime? pickedAt;
  final String? pickedBy;
  final String? pickedByName;

  // Priority order flag (full payment leads get installation priority)
  final bool isPriorityOrder;

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
    this.waybillPhotoUrl,
    this.pickedAt,
    this.pickedBy,
    this.pickedByName,
    // Priority order flag
    this.isPriorityOrder = false,
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
      // Installation booking fields
      installBookingToken: map['installBookingToken']?.toString(),
      customerSelectedDates: (map['customerSelectedDates'] as List<dynamic>?)
              ?.map((d) => (d as Timestamp).toDate())
              .toList() ??
          [],
      confirmedInstallDate:
          (map['confirmedInstallDate'] as Timestamp?)?.toDate(),
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
      pickedItems: (map['pickedItems'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as bool)) ??
          {},
      trackingNumber: map['trackingNumber']?.toString(),
      waybillPhotoUrl: map['waybillPhotoUrl']?.toString(),
      pickedAt: (map['pickedAt'] as Timestamp?)?.toDate(),
      pickedBy: map['pickedBy']?.toString(),
      pickedByName: map['pickedByName']?.toString(),
      isPriorityOrder: map['isPriorityOrder'] == true,
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
      'waybillPhotoUrl': waybillPhotoUrl,
      'pickedAt': pickedAt != null ? Timestamp.fromDate(pickedAt!) : null,
      'pickedBy': pickedBy,
      'pickedByName': pickedByName,
      'isPriorityOrder': isPriorityOrder,
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
    String? waybillPhotoUrl,
    DateTime? pickedAt,
    String? pickedBy,
    String? pickedByName,
    // Priority order flag
    bool? isPriorityOrder,
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
      waybillPhotoUrl: waybillPhotoUrl ?? this.waybillPhotoUrl,
      pickedAt: pickedAt ?? this.pickedAt,
      pickedBy: pickedBy ?? this.pickedBy,
      pickedByName: pickedByName ?? this.pickedByName,
      isPriorityOrder: isPriorityOrder ?? this.isPriorityOrder,
    );
  }

  /// Get the earliest customer selected date for sorting
  DateTime? get earliestSelectedDate {
    if (customerSelectedDates.isEmpty) return null;
    return customerSelectedDates.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
  }

  /// Get count of picked items
  int get pickedItemCount => pickedItems.values.where((v) => v).length;

  /// Get total item count (sum of quantities)
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Check if all items are picked
  bool get allItemsPicked {
    if (items.isEmpty) return false;
    for (final item in items) {
      // Check each item by name - if quantity > 1, we still just need one tick
      if (pickedItems[item.name] != true) return false;
    }
    return true;
  }

  /// Get picking progress as percentage (0.0 to 1.0)
  double get pickingProgress {
    if (items.isEmpty) return 0.0;
    return pickedItemCount / items.length;
  }

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

  OrderItem({required this.name, required this.quantity, this.price});

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: map['name']?.toString() ?? '',
      quantity: map['quantity']?.toInt() ?? 1,
      price: map['price']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity, 'price': price};
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
