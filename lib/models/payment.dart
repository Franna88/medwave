import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment status enumeration
enum PaymentStatus {
  pending('Pending'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  const PaymentStatus(this.displayName);
  final String displayName;
}

/// Payment method enumeration
enum PaymentMethod {
  qrCode('QR Code'),
  card('Card'),
  bankTransfer('Bank Transfer'),
  cash('Cash'),
  other('Other');

  const PaymentMethod(this.displayName);
  final String displayName;
}

/// Payment model for tracking patient session payments
class Payment {
  final String id;
  final String? sessionId; // Optional: payment can be created before session
  final String? appointmentId; // Link to appointment
  final String patientId;
  final String patientName;
  final String practitionerId;
  
  // Payment details
  final double amount;
  final String currency; // ZAR for South Africa
  final PaymentStatus status;
  final PaymentMethod paymentMethod;
  
  // Paystack integration
  final String paymentReference; // Our internal reference
  final String? paystackReference; // Paystack transaction reference
  final String? paystackAccessCode; // For payment initialization
  final String? authorizationUrl; // Payment URL for QR code
  
  // Subaccount & Split Payment
  final String? subaccountCode; // Practitioner's subaccount code
  final double? platformCommission; // Amount kept by platform
  final double? practitionerAmount; // Amount going to practitioner
  final String? settlementStatus; // 'pending', 'settled', 'failed'
  final DateTime? settlementDate;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? lastUpdated;
  
  // Additional information
  final Map<String, dynamic>? metadata;
  final String? notes;
  final String? failureReason;

  const Payment({
    required this.id,
    this.sessionId,
    this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.practitionerId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.paymentReference,
    this.paystackReference,
    this.paystackAccessCode,
    this.authorizationUrl,
    this.subaccountCode,
    this.platformCommission,
    this.practitionerAmount,
    this.settlementStatus,
    this.settlementDate,
    required this.createdAt,
    this.completedAt,
    this.lastUpdated,
    this.metadata,
    this.notes,
    this.failureReason,
  });

  /// Check if payment is pending
  bool get isPending => status == PaymentStatus.pending;

  /// Check if payment is completed
  bool get isCompleted => status == PaymentStatus.completed;

  /// Check if payment has failed
  bool get isFailed => status == PaymentStatus.failed;

  /// Check if payment is cancelled
  bool get isCancelled => status == PaymentStatus.cancelled;

  /// Format amount with currency
  String get formattedAmount => '$currency ${amount.toStringAsFixed(2)}';

  /// Copy with method for updating payment
  Payment copyWith({
    String? id,
    String? sessionId,
    String? appointmentId,
    String? patientId,
    String? patientName,
    String? practitionerId,
    double? amount,
    String? currency,
    PaymentStatus? status,
    PaymentMethod? paymentMethod,
    String? paymentReference,
    String? paystackReference,
    String? paystackAccessCode,
    String? authorizationUrl,
    String? subaccountCode,
    double? platformCommission,
    double? practitionerAmount,
    String? settlementStatus,
    DateTime? settlementDate,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
    String? notes,
    String? failureReason,
  }) {
    return Payment(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      practitionerId: practitionerId ?? this.practitionerId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      paystackReference: paystackReference ?? this.paystackReference,
      paystackAccessCode: paystackAccessCode ?? this.paystackAccessCode,
      authorizationUrl: authorizationUrl ?? this.authorizationUrl,
      subaccountCode: subaccountCode ?? this.subaccountCode,
      platformCommission: platformCommission ?? this.platformCommission,
      practitionerAmount: practitionerAmount ?? this.practitionerAmount,
      settlementStatus: settlementStatus ?? this.settlementStatus,
      settlementDate: settlementDate ?? this.settlementDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'sessionId': sessionId,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'practitionerId': practitionerId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'paymentReference': paymentReference,
      'paystackReference': paystackReference,
      'paystackAccessCode': paystackAccessCode,
      'authorizationUrl': authorizationUrl,
      'subaccountCode': subaccountCode,
      'platformCommission': platformCommission,
      'practitionerAmount': practitionerAmount,
      'settlementStatus': settlementStatus,
      'settlementDate': settlementDate != null ? Timestamp.fromDate(settlementDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
      'metadata': metadata,
      'notes': notes,
      'failureReason': failureReason,
    };
  }

  /// Create from Firestore document
  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Payment(
      id: doc.id,
      sessionId: data['sessionId'],
      appointmentId: data['appointmentId'],
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      practitionerId: data['practitionerId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'ZAR',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == data['paymentMethod'],
        orElse: () => PaymentMethod.qrCode,
      ),
      paymentReference: data['paymentReference'] ?? '',
      paystackReference: data['paystackReference'],
      paystackAccessCode: data['paystackAccessCode'],
      authorizationUrl: data['authorizationUrl'],
      subaccountCode: data['subaccountCode'],
      platformCommission: data['platformCommission']?.toDouble(),
      practitionerAmount: data['practitionerAmount']?.toDouble(),
      settlementStatus: data['settlementStatus'],
      settlementDate: (data['settlementDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      notes: data['notes'],
      failureReason: data['failureReason'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'practitionerId': practitionerId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'paymentReference': paymentReference,
      'paystackReference': paystackReference,
      'paystackAccessCode': paystackAccessCode,
      'authorizationUrl': authorizationUrl,
      'subaccountCode': subaccountCode,
      'platformCommission': platformCommission,
      'practitionerAmount': practitionerAmount,
      'settlementStatus': settlementStatus,
      'settlementDate': settlementDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'metadata': metadata,
      'notes': notes,
      'failureReason': failureReason,
    };
  }

  /// Create from JSON
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      sessionId: json['sessionId'],
      appointmentId: json['appointmentId'],
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      practitionerId: json['practitionerId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'ZAR',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.qrCode,
      ),
      paymentReference: json['paymentReference'] ?? '',
      paystackReference: json['paystackReference'],
      paystackAccessCode: json['paystackAccessCode'],
      authorizationUrl: json['authorizationUrl'],
      subaccountCode: json['subaccountCode'],
      platformCommission: json['platformCommission']?.toDouble(),
      practitionerAmount: json['practitionerAmount']?.toDouble(),
      settlementStatus: json['settlementStatus'],
      settlementDate: json['settlementDate'] != null ? DateTime.parse(json['settlementDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      notes: json['notes'],
      failureReason: json['failureReason'],
    );
  }
}

