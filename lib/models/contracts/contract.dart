import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a contract
enum ContractStatus {
  pending,
  viewed,
  signed,
  voided;

  String get displayName {
    switch (this) {
      case ContractStatus.pending:
        return 'Pending';
      case ContractStatus.viewed:
        return 'Viewed';
      case ContractStatus.signed:
        return 'Signed';
      case ContractStatus.voided:
        return 'Voided';
    }
  }

  static ContractStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ContractStatus.pending;
      case 'viewed':
        return ContractStatus.viewed;
      case 'signed':
        return ContractStatus.signed;
      case 'voided':
        return ContractStatus.voided;
      default:
        return ContractStatus.pending;
    }
  }
}

/// Product in a contract quote
class ContractProduct {
  final String id;
  final String name;
  final double price;

  const ContractProduct({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ContractProduct.fromMap(Map<String, dynamic> map) {
    return ContractProduct(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price};
  }
}

/// Model for a contract document
class Contract {
  final String id;

  // Security & Access
  final String accessToken;
  final ContractStatus status;

  // References
  final String appointmentId;
  final String leadId;

  // Customer Info
  final String customerName;
  final String email;
  final String phone;
  final String? shippingAddress;

  // Contract Content
  final int contractContentVersion;
  final Map<String, dynamic> contractContentData;

  // Quote/Invoice Details
  final List<ContractProduct> products;
  final double subtotal;
  final double depositAmount;
  final double remainingBalance;

  // Signature Data
  final bool hasSigned;
  final String? digitalSignature; // Customer's typed name
  final String? digitalSignatureToken; // Unique UUID-based token: DST-{uuid}
  final DateTime? signedAt;
  final String? ipAddress;
  final String? userAgent;

  // PDF
  final String? pdfUrl; // Firebase Storage URL for generated PDF

  // Timestamps
  final DateTime createdAt;
  final DateTime? viewedAt;

  // Metadata
  final String createdBy;
  final String createdByName;
  final String? voidedBy;
  final DateTime? voidedAt;
  final String? voidReason;

  // Payment type ('deposit' or 'full_payment')
  final String paymentType;

  // Revision tracking
  final String? parentContractId; // ID of original contract (null for original)
  final int revisionNumber; // 0 for original, 1+ for revisions
  final String? editReason; // Reason for editing this revision
  final String? editedBy; // User who created this revision
  final DateTime? editedAt; // When this revision was created

  Contract({
    required this.id,
    required this.accessToken,
    required this.status,
    required this.appointmentId,
    required this.leadId,
    required this.customerName,
    required this.email,
    required this.phone,
    this.shippingAddress,
    required this.contractContentVersion,
    required this.contractContentData,
    required this.products,
    required this.subtotal,
    required this.depositAmount,
    required this.remainingBalance,
    this.hasSigned = false,
    this.digitalSignature,
    this.digitalSignatureToken,
    this.signedAt,
    this.ipAddress,
    this.userAgent,
    this.pdfUrl,
    required this.createdAt,
    this.viewedAt,
    required this.createdBy,
    required this.createdByName,
    this.voidedBy,
    this.voidedAt,
    this.voidReason,
    this.paymentType = 'deposit',
    this.parentContractId,
    this.revisionNumber = 0,
    this.editReason,
    this.editedBy,
    this.editedAt,
  });

  /// Check if this is a full payment contract
  bool get isFullPayment => paymentType == 'full_payment';

  /// Check if contract is accessible (not voided)
  bool get isAccessible => status != ContractStatus.voided;

  /// Check if contract can be signed (pending or viewed, not already signed or voided)
  bool get canSign =>
      (status == ContractStatus.pending || status == ContractStatus.viewed) &&
      !hasSigned;

  /// Get status badge color
  String get statusColor {
    switch (status) {
      case ContractStatus.pending:
        return '#FFC107'; // amber
      case ContractStatus.viewed:
        return '#2196F3'; // blue
      case ContractStatus.signed:
        return '#4CAF50'; // green
      case ContractStatus.voided:
        return '#F44336'; // red
    }
  }

  factory Contract.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contract.fromMap(data, doc.id);
  }

  factory Contract.fromMap(Map<String, dynamic> map, String id) {
    return Contract(
      id: id,
      accessToken: map['accessToken']?.toString() ?? '',
      status: ContractStatus.fromString(map['status']?.toString() ?? 'pending'),
      appointmentId: map['appointmentId']?.toString() ?? '',
      leadId: map['leadId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      shippingAddress: map['shippingAddress']?.toString(),
      contractContentVersion: map['contractContentVersion'] as int? ?? 0,
      contractContentData:
          map['contractContentData'] as Map<String, dynamic>? ?? {},
      products:
          (map['products'] as List<dynamic>?)
              ?.map(
                (item) => ContractProduct.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      subtotal: (map['subtotal'] is num)
          ? (map['subtotal'] as num).toDouble()
          : 0.0,
      depositAmount: (map['depositAmount'] is num)
          ? (map['depositAmount'] as num).toDouble()
          : 0.0,
      remainingBalance: (map['remainingBalance'] is num)
          ? (map['remainingBalance'] as num).toDouble()
          : 0.0,
      hasSigned: map['hasSigned'] == true,
      digitalSignature: map['digitalSignature']?.toString(),
      digitalSignatureToken: map['digitalSignatureToken']?.toString(),
      signedAt: (map['signedAt'] as Timestamp?)?.toDate(),
      ipAddress: map['ipAddress']?.toString(),
      userAgent: map['userAgent']?.toString(),
      pdfUrl: map['pdfUrl']?.toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewedAt: (map['viewedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
      voidedBy: map['voidedBy']?.toString(),
      voidedAt: (map['voidedAt'] as Timestamp?)?.toDate(),
      voidReason: map['voidReason']?.toString(),
      paymentType: map['paymentType']?.toString() ?? 'deposit',
      parentContractId: map['parentContractId']?.toString(),
      revisionNumber: (map['revisionNumber'] as num?)?.toInt() ?? 0,
      editReason: map['editReason']?.toString(),
      editedBy: map['editedBy']?.toString(),
      editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'status': status.name,
      'appointmentId': appointmentId,
      'leadId': leadId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'shippingAddress': shippingAddress,
      'contractContentVersion': contractContentVersion,
      'contractContentData': contractContentData,
      'products': products.map((p) => p.toMap()).toList(),
      'subtotal': subtotal,
      'depositAmount': depositAmount,
      'remainingBalance': remainingBalance,
      'hasSigned': hasSigned,
      'digitalSignature': digitalSignature,
      'digitalSignatureToken': digitalSignatureToken,
      'signedAt': signedAt != null ? Timestamp.fromDate(signedAt!) : null,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'pdfUrl': pdfUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewedAt': viewedAt != null ? Timestamp.fromDate(viewedAt!) : null,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'voidedBy': voidedBy,
      'voidedAt': voidedAt != null ? Timestamp.fromDate(voidedAt!) : null,
      'voidReason': voidReason,
      'paymentType': paymentType,
      'parentContractId': parentContractId,
      'revisionNumber': revisionNumber,
      'editReason': editReason,
      'editedBy': editedBy,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }

  Contract copyWith({
    String? id,
    String? accessToken,
    ContractStatus? status,
    String? appointmentId,
    String? leadId,
    String? customerName,
    String? email,
    String? phone,
    String? shippingAddress,
    int? contractContentVersion,
    Map<String, dynamic>? contractContentData,
    List<ContractProduct>? products,
    double? subtotal,
    double? depositAmount,
    double? remainingBalance,
    bool? hasSigned,
    String? digitalSignature,
    String? digitalSignatureToken,
    DateTime? signedAt,
    String? ipAddress,
    String? userAgent,
    String? pdfUrl,
    DateTime? createdAt,
    DateTime? viewedAt,
    String? createdBy,
    String? createdByName,
    String? voidedBy,
    DateTime? voidedAt,
    String? voidReason,
    String? paymentType,
    String? parentContractId,
    int? revisionNumber,
    String? editReason,
    String? editedBy,
    DateTime? editedAt,
  }) {
    return Contract(
      id: id ?? this.id,
      accessToken: accessToken ?? this.accessToken,
      status: status ?? this.status,
      appointmentId: appointmentId ?? this.appointmentId,
      leadId: leadId ?? this.leadId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      contractContentVersion:
          contractContentVersion ?? this.contractContentVersion,
      contractContentData: contractContentData ?? this.contractContentData,
      products: products ?? this.products,
      subtotal: subtotal ?? this.subtotal,
      depositAmount: depositAmount ?? this.depositAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      hasSigned: hasSigned ?? this.hasSigned,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      digitalSignatureToken:
          digitalSignatureToken ?? this.digitalSignatureToken,
      signedAt: signedAt ?? this.signedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
      viewedAt: viewedAt ?? this.viewedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      paymentType: paymentType ?? this.paymentType,
      parentContractId: parentContractId ?? this.parentContractId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      editReason: editReason ?? this.editReason,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  @override
  String toString() {
    return 'Contract(id: $id, customerName: $customerName, status: ${status.name}, hasSigned: $hasSigned)';
  }
}
