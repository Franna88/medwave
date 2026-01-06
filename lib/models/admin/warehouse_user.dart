import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for warehouse user accounts
enum WarehouseUserStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  const WarehouseUserStatus(this.value);
  final String value;

  static WarehouseUserStatus fromString(String value) {
    return WarehouseUserStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WarehouseUserStatus.inactive,
    );
  }

  String get displayName {
    switch (this) {
      case WarehouseUserStatus.active:
        return 'Active';
      case WarehouseUserStatus.inactive:
        return 'Inactive';
      case WarehouseUserStatus.suspended:
        return 'Suspended';
    }
  }
}

/// Model representing a warehouse user profile
/// Warehouse users manage inventory and stock operations
class WarehouseUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final String? countryName;
  final WarehouseUserStatus status;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy; // ID of the admin who created this user
  final String? notes;

  WarehouseUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.country,
    this.countryName,
    required this.status,
    required this.createdAt,
    this.lastLogin,
    required this.createdBy,
    this.notes,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    return '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';
  }

  String get fullAddress {
    final parts = <String>[];
    if (address.isNotEmpty) parts.add(address);
    if (city.isNotEmpty) parts.add(city);
    if (province.isNotEmpty) parts.add(province);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    return parts.join(', ');
  }

  /// Create WarehouseUser from Firestore document (users collection)
  factory WarehouseUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Determine status from accountStatus field
    WarehouseUserStatus status;
    final accountStatus = data['accountStatus'] ?? 'pending';
    if (accountStatus == 'approved') {
      status = WarehouseUserStatus.active;
    } else if (accountStatus == 'suspended') {
      status = WarehouseUserStatus.suspended;
    } else {
      status = WarehouseUserStatus.inactive;
    }

    return WarehouseUser(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? '',
      countryName: data['countryName'],
      status: status,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'],
    );
  }

  /// Convert WarehouseUser to Firestore document for users collection
  Map<String, dynamic> toFirestore() {
    // Convert status to accountStatus for users collection
    String accountStatus;
    switch (status) {
      case WarehouseUserStatus.active:
        accountStatus = 'approved';
      case WarehouseUserStatus.suspended:
        accountStatus = 'suspended';
      case WarehouseUserStatus.inactive:
        accountStatus = 'pending';
    }

    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'address': address,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'country': country,
      'countryName': countryName,
      'accountStatus': accountStatus,
      'role': 'warehouse',
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  WarehouseUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    String? countryName,
    WarehouseUserStatus? status,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? createdBy,
    String? notes,
  }) {
    return WarehouseUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'WarehouseUser{id: $id, email: $email, fullName: $fullName, status: ${status.value}}';
  }
}

