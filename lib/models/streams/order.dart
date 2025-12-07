import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }
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
