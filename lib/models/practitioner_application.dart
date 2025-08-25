import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending('pending'),
  underReview('under_review'),
  approved('approved'),
  rejected('rejected');

  const ApplicationStatus(this.value);
  final String value;

  static ApplicationStatus fromString(String value) {
    return ApplicationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

class PractitionerApplication {
  final String id;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  
  // Professional Information
  final String licenseNumber;
  final String specialization;
  final int yearsOfExperience;
  final String practiceLocation;
  
  // Location Information
  final String country;
  final String countryName;
  final String province;
  final String city;
  
  // Application Status
  final ApplicationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final String? rejectionReason;
  
  // Supporting Documents (Firebase Storage references)
  final Map<String, String> documents;
  
  // Verification Status
  final bool documentsVerified;
  final bool licenseVerified;
  final bool referencesVerified;

  PractitionerApplication({
    required this.id,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    required this.specialization,
    required this.yearsOfExperience,
    required this.practiceLocation,
    required this.country,
    required this.countryName,
    required this.province,
    required this.city,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.rejectionReason,
    required this.documents,
    required this.documentsVerified,
    required this.licenseVerified,
    required this.referencesVerified,
  });

  String get fullName => '$firstName $lastName';

  bool get isPending => status == ApplicationStatus.pending;
  bool get isUnderReview => status == ApplicationStatus.underReview;
  bool get isApproved => status == ApplicationStatus.approved;
  bool get isRejected => status == ApplicationStatus.rejected;

  bool get hasAllDocuments {
    final requiredDocs = ['licenseDocument', 'idDocument', 'qualificationCertificate'];
    return requiredDocs.every((doc) => documents[doc]?.isNotEmpty == true);
  }

  bool get isFullyVerified {
    return documentsVerified && licenseVerified && referencesVerified;
  }

  factory PractitionerApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PractitionerApplication(
      id: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      specialization: data['specialization'] ?? '',
      yearsOfExperience: data['yearsOfExperience'] ?? 0,
      practiceLocation: data['practiceLocation'] ?? '',
      country: data['country'] ?? '',
      countryName: data['countryName'] ?? '',
      province: data['province'] ?? '',
      city: data['city'] ?? '',
      status: ApplicationStatus.fromString(data['status'] ?? 'pending'),
      submittedAt: data['submittedAt']?.toDate() ?? DateTime.now(),
      reviewedAt: data['reviewedAt']?.toDate(),
      reviewedBy: data['reviewedBy'],
      reviewNotes: data['reviewNotes'],
      rejectionReason: data['rejectionReason'],
      documents: Map<String, String>.from(data['documents'] ?? {}),
      documentsVerified: data['documentsVerified'] ?? false,
      licenseVerified: data['licenseVerified'] ?? false,
      referencesVerified: data['referencesVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'licenseNumber': licenseNumber,
      'specialization': specialization,
      'yearsOfExperience': yearsOfExperience,
      'practiceLocation': practiceLocation,
      'country': country,
      'countryName': countryName,
      'province': province,
      'city': city,
      'status': status.value,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'rejectionReason': rejectionReason,
      'documents': documents,
      'documentsVerified': documentsVerified,
      'licenseVerified': licenseVerified,
      'referencesVerified': referencesVerified,
    };
  }

  PractitionerApplication copyWith({
    String? id,
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? licenseNumber,
    String? specialization,
    int? yearsOfExperience,
    String? practiceLocation,
    String? country,
    String? countryName,
    String? province,
    String? city,
    ApplicationStatus? status,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewNotes,
    String? rejectionReason,
    Map<String, String>? documents,
    bool? documentsVerified,
    bool? licenseVerified,
    bool? referencesVerified,
  }) {
    return PractitionerApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      practiceLocation: practiceLocation ?? this.practiceLocation,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      province: province ?? this.province,
      city: city ?? this.city,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      documents: documents ?? this.documents,
      documentsVerified: documentsVerified ?? this.documentsVerified,
      licenseVerified: licenseVerified ?? this.licenseVerified,
      referencesVerified: referencesVerified ?? this.referencesVerified,
    );
  }
}
