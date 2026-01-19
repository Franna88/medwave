import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an installation sign-off
enum SignoffStatus {
  pending,
  viewed,
  signed;

  String get displayName {
    switch (this) {
      case SignoffStatus.pending:
        return 'Pending';
      case SignoffStatus.viewed:
        return 'Viewed';
      case SignoffStatus.signed:
        return 'Signed';
    }
  }

  static SignoffStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return SignoffStatus.pending;
      case 'viewed':
        return SignoffStatus.viewed;
      case 'signed':
        return SignoffStatus.signed;
      default:
        return SignoffStatus.pending;
    }
  }
}

/// Item in a sign-off
class SignoffItem {
  final String name;
  final int quantity;

  const SignoffItem({
    required this.name,
    required this.quantity,
  });

  factory SignoffItem.fromMap(Map<String, dynamic> map) {
    return SignoffItem(
      name: map['name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity};
  }
}

/// Model for an installation sign-off document
class InstallationSignoff {
  final String id;

  // Security & Access
  final String accessToken;
  final SignoffStatus status;

  // References
  final String orderId;
  final String appointmentId;

  // Customer Info
  final String customerName;
  final String email;
  final String phone;
  final String? deliveryAddress;

  // Items to verify
  final List<SignoffItem> items;

  // Signature Data
  final bool hasSigned;
  final String? digitalSignature; // Customer's typed name
  final String? digitalSignatureToken; // Unique UUID-based token: DST-{uuid}
  final DateTime? signedAt;
  final String? ipAddress;
  final String? userAgent;

  // Item confirmation tracking
  final Map<String, bool> itemsConfirmed; // itemName -> confirmed

  // Timestamps
  final DateTime createdAt;
  final DateTime? viewedAt;

  // Metadata
  final String createdBy;
  final String createdByName;

  InstallationSignoff({
    required this.id,
    required this.accessToken,
    required this.status,
    required this.orderId,
    required this.appointmentId,
    required this.customerName,
    required this.email,
    required this.phone,
    this.deliveryAddress,
    required this.items,
    this.hasSigned = false,
    this.digitalSignature,
    this.digitalSignatureToken,
    this.signedAt,
    this.ipAddress,
    this.userAgent,
    this.itemsConfirmed = const {},
    required this.createdAt,
    this.viewedAt,
    required this.createdBy,
    required this.createdByName,
  });

  /// Check if sign-off is accessible
  bool get isAccessible => true; // No voided status for sign-offs

  /// Check if sign-off can be signed
  bool get canSign => (status == SignoffStatus.pending || status == SignoffStatus.viewed) && !hasSigned;

  /// Get status badge color
  String get statusColor {
    switch (status) {
      case SignoffStatus.pending:
        return '#FFC107'; // amber
      case SignoffStatus.viewed:
        return '#2196F3'; // blue
      case SignoffStatus.signed:
        return '#4CAF50'; // green
    }
  }

  /// Check if all items are confirmed
  bool get allItemsConfirmed {
    if (items.isEmpty) return false;
    for (final item in items) {
      if (itemsConfirmed[item.name] != true) return false;
    }
    return true;
  }

  /// Check if there are issues (not all items confirmed)
  bool get hasIssues => !allItemsConfirmed;

  factory InstallationSignoff.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstallationSignoff.fromMap(data, doc.id);
  }

  factory InstallationSignoff.fromMap(Map<String, dynamic> map, String id) {
    return InstallationSignoff(
      id: id,
      accessToken: map['accessToken']?.toString() ?? '',
      status: SignoffStatus.fromString(map['status']?.toString() ?? 'pending'),
      orderId: map['orderId']?.toString() ?? '',
      appointmentId: map['appointmentId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      deliveryAddress: map['deliveryAddress']?.toString(),
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => SignoffItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      hasSigned: map['hasSigned'] == true,
      digitalSignature: map['digitalSignature']?.toString(),
      digitalSignatureToken: map['digitalSignatureToken']?.toString(),
      signedAt: (map['signedAt'] as Timestamp?)?.toDate(),
      ipAddress: map['ipAddress']?.toString(),
      userAgent: map['userAgent']?.toString(),
      itemsConfirmed: (map['itemsConfirmed'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as bool),
          ) ??
          {},
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewedAt: (map['viewedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'status': status.name,
      'orderId': orderId,
      'appointmentId': appointmentId,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'deliveryAddress': deliveryAddress,
      'items': items.map((i) => i.toMap()).toList(),
      'hasSigned': hasSigned,
      'digitalSignature': digitalSignature,
      'digitalSignatureToken': digitalSignatureToken,
      'signedAt': signedAt != null ? Timestamp.fromDate(signedAt!) : null,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'itemsConfirmed': itemsConfirmed,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewedAt': viewedAt != null ? Timestamp.fromDate(viewedAt!) : null,
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  InstallationSignoff copyWith({
    String? id,
    String? accessToken,
    SignoffStatus? status,
    String? orderId,
    String? appointmentId,
    String? customerName,
    String? email,
    String? phone,
    String? deliveryAddress,
    List<SignoffItem>? items,
    bool? hasSigned,
    String? digitalSignature,
    String? digitalSignatureToken,
    DateTime? signedAt,
    String? ipAddress,
    String? userAgent,
    Map<String, bool>? itemsConfirmed,
    DateTime? createdAt,
    DateTime? viewedAt,
    String? createdBy,
    String? createdByName,
  }) {
    return InstallationSignoff(
      id: id ?? this.id,
      accessToken: accessToken ?? this.accessToken,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      appointmentId: appointmentId ?? this.appointmentId,
      customerName: customerName ?? this.customerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      hasSigned: hasSigned ?? this.hasSigned,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      digitalSignatureToken: digitalSignatureToken ?? this.digitalSignatureToken,
      signedAt: signedAt ?? this.signedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      itemsConfirmed: itemsConfirmed ?? this.itemsConfirmed,
      createdAt: createdAt ?? this.createdAt,
      viewedAt: viewedAt ?? this.viewedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }

  @override
  String toString() {
    return 'InstallationSignoff(id: $id, customerName: $customerName, status: ${status.name}, hasSigned: $hasSigned)';
  }
}
