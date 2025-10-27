import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String licenseNumber;
  final String specialization;
  final int yearsOfExperience;
  final String practiceLocation;
  
  // Location Information
  final String country;
  final String countryName;
  final String province;
  final String city;
  final String address;
  final String postalCode;
  
  // Approval Workflow
  final String accountStatus; // 'pending', 'approved', 'rejected', 'suspended'
  final DateTime? applicationDate;
  final DateTime? approvalDate;
  final String? approvedBy;
  final String? rejectionReason;
  
  // Professional Verification
  final bool licenseVerified;
  final DateTime? licenseVerificationDate;
  final List<ProfessionalReference> professionalReferences;
  
  // App Settings
  final UserSettings settings;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final DateTime? lastLogin;
  final String role; // 'practitioner', 'super_admin', 'country_admin'
  
  // Analytics Support
  final int totalPatients;
  final int totalSessions;
  final DateTime? lastActivityDate;
  
  // Google Calendar Integration
  final bool googleCalendarConnected;
  final String? googleCalendarId;
  final DateTime? lastSyncTime;
  final bool syncEnabled;
  final String? googleRefreshToken;
  final DateTime? tokenExpiresAt;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.licenseNumber,
    required this.specialization,
    required this.yearsOfExperience,
    required this.practiceLocation,
    required this.country,
    required this.countryName,
    required this.province,
    required this.city,
    required this.address,
    required this.postalCode,
    required this.accountStatus,
    this.applicationDate,
    this.approvalDate,
    this.approvedBy,
    this.rejectionReason,
    required this.licenseVerified,
    this.licenseVerificationDate,
    required this.professionalReferences,
    required this.settings,
    required this.createdAt,
    this.lastUpdated,
    this.lastLogin,
    required this.role,
    required this.totalPatients,
    required this.totalSessions,
    this.lastActivityDate,
    this.googleCalendarConnected = false,
    this.googleCalendarId,
    this.lastSyncTime,
    this.syncEnabled = false,
    this.googleRefreshToken,
    this.tokenExpiresAt,
  });

  String get fullName => '$firstName $lastName';

  bool get isApproved => accountStatus == 'approved';
  bool get isPending => accountStatus == 'pending';
  bool get isRejected => accountStatus == 'rejected';
  bool get isSuspended => accountStatus == 'suspended';
  
  bool get isSuperAdmin => role == 'super_admin';
  bool get isPractitioner => role == 'practitioner';
  bool get isCountryAdmin => role == 'country_admin';

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserProfile(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      specialization: data['specialization'] ?? '',
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      practiceLocation: data['practiceLocation'] ?? '',
      country: data['country'] ?? '',
      countryName: data['countryName'] ?? '',
      province: data['province'] ?? '',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      postalCode: data['postalCode'] ?? '',
      accountStatus: data['accountStatus'] ?? 'pending',
      applicationDate: data['applicationDate']?.toDate(),
      approvalDate: data['approvalDate']?.toDate(),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      licenseVerified: data['licenseVerified'] ?? false,
      licenseVerificationDate: data['licenseVerificationDate']?.toDate(),
      professionalReferences: (data['professionalReferences'] as List<dynamic>?)
          ?.map((ref) => ProfessionalReference.fromMap(ref))
          .toList() ?? [],
      settings: UserSettings.fromMap(data['settings'] ?? {}),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      lastUpdated: data['lastUpdated']?.toDate(),
      lastLogin: data['lastLogin']?.toDate(),
      role: data['role'] ?? 'practitioner',
      totalPatients: data['totalPatients'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      lastActivityDate: data['lastActivityDate']?.toDate(),
      googleCalendarConnected: data['googleCalendarConnected'] ?? false,
      googleCalendarId: data['googleCalendarId'],
      lastSyncTime: data['lastSyncTime']?.toDate(),
      syncEnabled: data['syncEnabled'] ?? false,
      googleRefreshToken: data['googleRefreshToken'],
      tokenExpiresAt: data['tokenExpiresAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'licenseNumber': licenseNumber,
      'specialization': specialization,
      'yearsOfExperience': yearsOfExperience,
      'practiceLocation': practiceLocation,
      'country': country,
      'countryName': countryName,
      'province': province,
      'city': city,
      'address': address,
      'postalCode': postalCode,
      'accountStatus': accountStatus,
      'applicationDate': applicationDate != null ? Timestamp.fromDate(applicationDate!) : null,
      'approvalDate': approvalDate != null ? Timestamp.fromDate(approvalDate!) : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'licenseVerified': licenseVerified,
      'licenseVerificationDate': licenseVerificationDate != null ? Timestamp.fromDate(licenseVerificationDate!) : null,
      'professionalReferences': professionalReferences.map((ref) => ref.toMap()).toList(),
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'role': role,
      'totalPatients': totalPatients,
      'totalSessions': totalSessions,
      'lastActivityDate': lastActivityDate != null ? Timestamp.fromDate(lastActivityDate!) : null,
      'googleCalendarConnected': googleCalendarConnected,
      'googleCalendarId': googleCalendarId,
      'lastSyncTime': lastSyncTime != null ? Timestamp.fromDate(lastSyncTime!) : null,
      'syncEnabled': syncEnabled,
      'googleRefreshToken': googleRefreshToken,
      'tokenExpiresAt': tokenExpiresAt != null ? Timestamp.fromDate(tokenExpiresAt!) : null,
    };
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? licenseNumber,
    String? specialization,
    int? yearsOfExperience,
    String? practiceLocation,
    String? country,
    String? countryName,
    String? province,
    String? city,
    String? address,
    String? postalCode,
    String? accountStatus,
    DateTime? applicationDate,
    DateTime? approvalDate,
    String? approvedBy,
    String? rejectionReason,
    bool? licenseVerified,
    DateTime? licenseVerificationDate,
    List<ProfessionalReference>? professionalReferences,
    UserSettings? settings,
    DateTime? lastUpdated,
    DateTime? lastLogin,
    String? role,
    int? totalPatients,
    int? totalSessions,
    DateTime? lastActivityDate,
    bool? googleCalendarConnected,
    String? googleCalendarId,
    DateTime? lastSyncTime,
    bool? syncEnabled,
    String? googleRefreshToken,
    DateTime? tokenExpiresAt,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      practiceLocation: practiceLocation ?? this.practiceLocation,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      province: province ?? this.province,
      city: city ?? this.city,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      accountStatus: accountStatus ?? this.accountStatus,
      applicationDate: applicationDate ?? this.applicationDate,
      approvalDate: approvalDate ?? this.approvalDate,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      licenseVerified: licenseVerified ?? this.licenseVerified,
      licenseVerificationDate: licenseVerificationDate ?? this.licenseVerificationDate,
      professionalReferences: professionalReferences ?? this.professionalReferences,
      settings: settings ?? this.settings,
      createdAt: createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastLogin: lastLogin ?? this.lastLogin,
      role: role ?? this.role,
      totalPatients: totalPatients ?? this.totalPatients,
      totalSessions: totalSessions ?? this.totalSessions,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      googleCalendarConnected: googleCalendarConnected ?? this.googleCalendarConnected,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      googleRefreshToken: googleRefreshToken ?? this.googleRefreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }
}

class ProfessionalReference {
  final String name;
  final String organization;
  final String email;
  final String phone;
  final String relationship;

  ProfessionalReference({
    required this.name,
    required this.organization,
    required this.email,
    required this.phone,
    required this.relationship,
  });

  factory ProfessionalReference.fromMap(Map<String, dynamic> map) {
    return ProfessionalReference(
      name: map['name'] ?? '',
      organization: map['organization'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'organization': organization,
      'email': email,
      'phone': phone,
      'relationship': relationship,
    };
  }
}

class UserSettings {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final bool biometricEnabled;
  final String language;
  final String timezone;

  UserSettings({
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.biometricEnabled,
    required this.language,
    required this.timezone,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      darkModeEnabled: map['darkModeEnabled'] ?? false,
      biometricEnabled: map['biometricEnabled'] ?? false,
      language: map['language'] ?? 'en',
      timezone: map['timezone'] ?? 'UTC',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'biometricEnabled': biometricEnabled,
      'language': language,
      'timezone': timezone,
    };
  }

  UserSettings copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    bool? biometricEnabled,
    String? language,
    String? timezone,
  }) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
    );
  }
}
