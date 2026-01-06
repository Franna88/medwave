import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for installer accounts
enum InstallerStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  const InstallerStatus(this.value);
  final String value;

  static InstallerStatus fromString(String value) {
    return InstallerStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InstallerStatus.inactive,
    );
  }

  String get displayName {
    switch (this) {
      case InstallerStatus.active:
        return 'Active';
      case InstallerStatus.inactive:
        return 'Inactive';
      case InstallerStatus.suspended:
        return 'Suspended';
    }
  }
}

/// Model representing an installer profile
/// Installers are field technicians who install medical equipment
class Installer {
  final String id;
  final String userId; // Firebase Auth UID
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
  final String serviceArea; // Areas they cover (e.g., "Cape Town, Stellenbosch")
  final InstallerStatus status;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy; // ID of the admin who created this installer
  final String? notes;

  Installer({
    required this.id,
    required this.userId,
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
    required this.serviceArea,
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

  /// Create Installer from Firestore document
  factory Installer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Installer(
      id: doc.id,
      userId: data['userId'] ?? '',
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
      serviceArea: data['serviceArea'] ?? '',
      status: InstallerStatus.fromString(data['status'] ?? 'inactive'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'],
    );
  }

  /// Convert Installer to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
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
      'serviceArea': serviceArea,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  Installer copyWith({
    String? id,
    String? userId,
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
    String? serviceArea,
    InstallerStatus? status,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? createdBy,
    String? notes,
  }) {
    return Installer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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
      serviceArea: serviceArea ?? this.serviceArea,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Installer{id: $id, email: $email, fullName: $fullName, status: ${status.value}, serviceArea: $serviceArea}';
  }
}

