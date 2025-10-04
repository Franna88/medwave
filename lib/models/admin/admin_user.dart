import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminRole {
  superAdmin('super_admin'),
  countryAdmin('country_admin');

  const AdminRole(this.value);
  final String value;

  static AdminRole fromString(String value) {
    return AdminRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => AdminRole.countryAdmin,
    );
  }

  String get displayName {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.countryAdmin:
        return 'Country Admin';
    }
  }
}

enum AdminUserStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  const AdminUserStatus(this.value);
  final String value;

  static AdminUserStatus fromString(String value) {
    return AdminUserStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AdminUserStatus.inactive,
    );
  }

  String get displayName {
    switch (this) {
      case AdminUserStatus.active:
        return 'Active';
      case AdminUserStatus.inactive:
        return 'Inactive';
      case AdminUserStatus.suspended:
        return 'Suspended';
    }
  }
}

class AdminUser {
  final String id;
  final String userId; // Firebase Auth UID
  final String email;
  final String firstName;
  final String lastName;
  final AdminRole role;
  final AdminUserStatus status;
  final String country;
  final String? countryName;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy; // ID of the admin who created this user
  final Map<String, dynamic> permissions;
  final String? notes;

  AdminUser({
    required this.id,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    required this.country,
    this.countryName,
    required this.createdAt,
    this.lastLogin,
    required this.createdBy,
    this.permissions = const {},
    this.notes,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    return '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}';
  }

  /// Create AdminUser from Firestore document
  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdminUser(
      id: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      role: AdminRole.fromString(data['role'] ?? 'country_admin'),
      status: AdminUserStatus.fromString(data['status'] ?? 'inactive'),
      country: data['country'] ?? '',
      countryName: data['countryName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      permissions: Map<String, dynamic>.from(data['permissions'] ?? {}),
      notes: data['notes'],
    );
  }

  /// Convert AdminUser to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.value,
      'status': status.value,
      'country': country,
      'countryName': countryName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'permissions': permissions,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  AdminUser copyWith({
    String? id,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    AdminRole? role,
    AdminUserStatus? status,
    String? country,
    String? countryName,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? createdBy,
    Map<String, dynamic>? permissions,
    String? notes,
  }) {
    return AdminUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      status: status ?? this.status,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      createdBy: createdBy ?? this.createdBy,
      permissions: permissions ?? this.permissions,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'AdminUser{id: $id, email: $email, fullName: $fullName, role: ${role.value}, status: ${status.value}}';
  }
}
