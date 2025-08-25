import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String id;
  
  // Basic patient details
  final String surname;
  final String fullNames;
  final String idNumber;
  final DateTime dateOfBirth;
  final String? workNameAndAddress;
  final String? workPostalAddress;
  final String? workTelNo;
  final String patientCell;
  final String? homeTelNo;
  final String email;
  final String? maritalStatus;
  final String? occupation;
  
  // Person responsible for account (Main Member)
  final String responsiblePersonSurname;
  final String responsiblePersonFullNames;
  final String responsiblePersonIdNumber;
  final DateTime responsiblePersonDateOfBirth;
  final String? responsiblePersonWorkNameAndAddress;
  final String? responsiblePersonWorkPostalAddress;
  final String? responsiblePersonWorkTelNo;
  final String responsiblePersonCell;
  final String? responsiblePersonHomeTelNo;
  final String? responsiblePersonEmail;
  final String? responsiblePersonMaritalStatus;
  final String? responsiblePersonOccupation;
  final String? relationToPatient;
  
  // Medical Aid Details
  final String medicalAidSchemeName;
  final String medicalAidNumber;
  final String? planAndDepNumber;
  final String mainMemberName;
  
  // Referring Doctor/Specialist
  final String? referringDoctorName;
  final String? referringDoctorCell;
  final String? additionalReferrerName;
  final String? additionalReferrerCell;
  
  // Medical History
  final Map<String, bool> medicalConditions; // Heart, Lungs, etc.
  final Map<String, String?> medicalConditionDetails; // Specify details for yes answers
  final String? currentMedications;
  final String? allergies;
  final bool isSmoker;
  final String? naturalTreatments;
  
  // Consent and Signatures
  final String? accountResponsibilitySignature;
  final DateTime? accountResponsibilitySignatureDate;
  final String? woundPhotographyConsentSignature;
  final String? witnessSignature;
  final DateTime? woundPhotographyConsentDate;
  final bool? trainingPhotosConsent;
  final DateTime? trainingPhotosConsentDate;
  
  final DateTime createdAt;
  final DateTime? lastUpdated;
  
  // Firebase-specific fields
  final String practitionerId; // Reference to the practitioner who created this patient
  final String? country; // Inherited from practitioner for analytics
  final String? countryName; // Inherited from practitioner for analytics
  final String? province; // Inherited from practitioner for analytics
  
  // Baseline measurements
  final double baselineWeight;
  final int baselineVasScore;
  final List<Wound> baselineWounds;
  final List<String> baselinePhotos;
  
  // Current measurements
  final double? currentWeight;
  final int? currentVasScore;
  final List<Wound> currentWounds;
  
  // Session history
  final List<Session> sessions;
  
  // Calculated progress
  final double? weightChange;
  final double? painReduction;
  final double? woundHealingProgress;

  const Patient({
    required this.id,
    // Basic patient details
    required this.surname,
    required this.fullNames,
    required this.idNumber,
    required this.dateOfBirth,
    this.workNameAndAddress,
    this.workPostalAddress,
    this.workTelNo,
    required this.patientCell,
    this.homeTelNo,
    required this.email,
    this.maritalStatus,
    this.occupation,
    // Person responsible for account
    required this.responsiblePersonSurname,
    required this.responsiblePersonFullNames,
    required this.responsiblePersonIdNumber,
    required this.responsiblePersonDateOfBirth,
    this.responsiblePersonWorkNameAndAddress,
    this.responsiblePersonWorkPostalAddress,
    this.responsiblePersonWorkTelNo,
    required this.responsiblePersonCell,
    this.responsiblePersonHomeTelNo,
    this.responsiblePersonEmail,
    this.responsiblePersonMaritalStatus,
    this.responsiblePersonOccupation,
    this.relationToPatient,
    // Medical Aid Details
    required this.medicalAidSchemeName,
    required this.medicalAidNumber,
    this.planAndDepNumber,
    required this.mainMemberName,
    // Referring Doctor/Specialist
    this.referringDoctorName,
    this.referringDoctorCell,
    this.additionalReferrerName,
    this.additionalReferrerCell,
    // Medical History
    required this.medicalConditions,
    required this.medicalConditionDetails,
    this.currentMedications,
    this.allergies,
    required this.isSmoker,
    this.naturalTreatments,
    // Consent and Signatures
    this.accountResponsibilitySignature,
    this.accountResponsibilitySignatureDate,
    this.woundPhotographyConsentSignature,
    this.witnessSignature,
    this.woundPhotographyConsentDate,
    this.trainingPhotosConsent,
    this.trainingPhotosConsentDate,
    required this.createdAt,
    this.lastUpdated,
    required this.practitionerId,
    this.country,
    this.countryName,
    this.province,
    required this.baselineWeight,
    required this.baselineVasScore,
    required this.baselineWounds,
    required this.baselinePhotos,
    this.currentWeight,
    this.currentVasScore,
    required this.currentWounds,
    required this.sessions,
    this.weightChange,
    this.painReduction,
    this.woundHealingProgress,
  });

  // Helper getters for backward compatibility
  String get name => '$fullNames $surname';
  int get age {
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }
  String get medicalAid => medicalAidSchemeName;
  String get contactInfo => email;
  String get phone => patientCell;

  // Calculate progress metrics
  double get weightChangePercentage {
    if (currentWeight == null || baselineWeight == 0) return 0;
    return ((currentWeight! - baselineWeight) / baselineWeight) * 100;
  }

  double get painReductionPercentage {
    if (currentVasScore == null || baselineVasScore == 0) return 0;
    return ((baselineVasScore - currentVasScore!) / baselineVasScore) * 100;
  }

  int get totalSessions => sessions.length;

  DateTime? get nextAppointment {
    // Logic to determine next appointment based on sessions
    if (sessions.isEmpty) return null;
    final lastSession = sessions.last;
    return lastSession.date.add(const Duration(days: 7)); // Weekly sessions
  }

  bool get hasImprovement {
    return painReductionPercentage > 20 || // 20% pain reduction
           (woundHealingProgress ?? 0) > 30; // 30% wound healing
  }

  Patient copyWith({
    String? id,
    String? surname,
    String? fullNames,
    String? idNumber,
    DateTime? dateOfBirth,
    String? workNameAndAddress,
    String? workPostalAddress,
    String? workTelNo,
    String? patientCell,
    String? homeTelNo,
    String? email,
    String? maritalStatus,
    String? occupation,
    String? responsiblePersonSurname,
    String? responsiblePersonFullNames,
    String? responsiblePersonIdNumber,
    DateTime? responsiblePersonDateOfBirth,
    String? responsiblePersonWorkNameAndAddress,
    String? responsiblePersonWorkPostalAddress,
    String? responsiblePersonWorkTelNo,
    String? responsiblePersonCell,
    String? responsiblePersonHomeTelNo,
    String? responsiblePersonEmail,
    String? responsiblePersonMaritalStatus,
    String? responsiblePersonOccupation,
    String? relationToPatient,
    String? medicalAidSchemeName,
    String? medicalAidNumber,
    String? planAndDepNumber,
    String? mainMemberName,
    String? referringDoctorName,
    String? referringDoctorCell,
    String? additionalReferrerName,
    String? additionalReferrerCell,
    Map<String, bool>? medicalConditions,
    Map<String, String?>? medicalConditionDetails,
    String? currentMedications,
    String? allergies,
    bool? isSmoker,
    String? naturalTreatments,
    String? accountResponsibilitySignature,
    DateTime? accountResponsibilitySignatureDate,
    String? woundPhotographyConsentSignature,
    String? witnessSignature,
    DateTime? woundPhotographyConsentDate,
    bool? trainingPhotosConsent,
    DateTime? trainingPhotosConsentDate,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? practitionerId,
    String? country,
    String? countryName,
    String? province,
    double? baselineWeight,
    int? baselineVasScore,
    List<Wound>? baselineWounds,
    List<String>? baselinePhotos,
    double? currentWeight,
    int? currentVasScore,
    List<Wound>? currentWounds,
    List<Session>? sessions,
    double? weightChange,
    double? painReduction,
    double? woundHealingProgress,
  }) {
    return Patient(
      id: id ?? this.id,
      surname: surname ?? this.surname,
      fullNames: fullNames ?? this.fullNames,
      idNumber: idNumber ?? this.idNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      workNameAndAddress: workNameAndAddress ?? this.workNameAndAddress,
      workPostalAddress: workPostalAddress ?? this.workPostalAddress,
      workTelNo: workTelNo ?? this.workTelNo,
      patientCell: patientCell ?? this.patientCell,
      homeTelNo: homeTelNo ?? this.homeTelNo,
      email: email ?? this.email,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      occupation: occupation ?? this.occupation,
      responsiblePersonSurname: responsiblePersonSurname ?? this.responsiblePersonSurname,
      responsiblePersonFullNames: responsiblePersonFullNames ?? this.responsiblePersonFullNames,
      responsiblePersonIdNumber: responsiblePersonIdNumber ?? this.responsiblePersonIdNumber,
      responsiblePersonDateOfBirth: responsiblePersonDateOfBirth ?? this.responsiblePersonDateOfBirth,
      responsiblePersonWorkNameAndAddress: responsiblePersonWorkNameAndAddress ?? this.responsiblePersonWorkNameAndAddress,
      responsiblePersonWorkPostalAddress: responsiblePersonWorkPostalAddress ?? this.responsiblePersonWorkPostalAddress,
      responsiblePersonWorkTelNo: responsiblePersonWorkTelNo ?? this.responsiblePersonWorkTelNo,
      responsiblePersonCell: responsiblePersonCell ?? this.responsiblePersonCell,
      responsiblePersonHomeTelNo: responsiblePersonHomeTelNo ?? this.responsiblePersonHomeTelNo,
      responsiblePersonEmail: responsiblePersonEmail ?? this.responsiblePersonEmail,
      responsiblePersonMaritalStatus: responsiblePersonMaritalStatus ?? this.responsiblePersonMaritalStatus,
      responsiblePersonOccupation: responsiblePersonOccupation ?? this.responsiblePersonOccupation,
      relationToPatient: relationToPatient ?? this.relationToPatient,
      medicalAidSchemeName: medicalAidSchemeName ?? this.medicalAidSchemeName,
      medicalAidNumber: medicalAidNumber ?? this.medicalAidNumber,
      planAndDepNumber: planAndDepNumber ?? this.planAndDepNumber,
      mainMemberName: mainMemberName ?? this.mainMemberName,
      referringDoctorName: referringDoctorName ?? this.referringDoctorName,
      referringDoctorCell: referringDoctorCell ?? this.referringDoctorCell,
      additionalReferrerName: additionalReferrerName ?? this.additionalReferrerName,
      additionalReferrerCell: additionalReferrerCell ?? this.additionalReferrerCell,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medicalConditionDetails: medicalConditionDetails ?? this.medicalConditionDetails,
      currentMedications: currentMedications ?? this.currentMedications,
      allergies: allergies ?? this.allergies,
      isSmoker: isSmoker ?? this.isSmoker,
      naturalTreatments: naturalTreatments ?? this.naturalTreatments,
      accountResponsibilitySignature: accountResponsibilitySignature ?? this.accountResponsibilitySignature,
      accountResponsibilitySignatureDate: accountResponsibilitySignatureDate ?? this.accountResponsibilitySignatureDate,
      woundPhotographyConsentSignature: woundPhotographyConsentSignature ?? this.woundPhotographyConsentSignature,
      witnessSignature: witnessSignature ?? this.witnessSignature,
      woundPhotographyConsentDate: woundPhotographyConsentDate ?? this.woundPhotographyConsentDate,
      trainingPhotosConsent: trainingPhotosConsent ?? this.trainingPhotosConsent,
      trainingPhotosConsentDate: trainingPhotosConsentDate ?? this.trainingPhotosConsentDate,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      practitionerId: practitionerId ?? this.practitionerId,
      country: country ?? this.country,
      countryName: countryName ?? this.countryName,
      province: province ?? this.province,
      baselineWeight: baselineWeight ?? this.baselineWeight,
      baselineVasScore: baselineVasScore ?? this.baselineVasScore,
      baselineWounds: baselineWounds ?? this.baselineWounds,
      baselinePhotos: baselinePhotos ?? this.baselinePhotos,
      currentWeight: currentWeight ?? this.currentWeight,
      currentVasScore: currentVasScore ?? this.currentVasScore,
      currentWounds: currentWounds ?? this.currentWounds,
      sessions: sessions ?? this.sessions,
      weightChange: weightChange ?? this.weightChange,
      painReduction: painReduction ?? this.painReduction,
      woundHealingProgress: woundHealingProgress ?? this.woundHealingProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surname': surname,
      'fullNames': fullNames,
      'idNumber': idNumber,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'workNameAndAddress': workNameAndAddress,
      'workPostalAddress': workPostalAddress,
      'workTelNo': workTelNo,
      'patientCell': patientCell,
      'homeTelNo': homeTelNo,
      'email': email,
      'maritalStatus': maritalStatus,
      'occupation': occupation,
      'responsiblePersonSurname': responsiblePersonSurname,
      'responsiblePersonFullNames': responsiblePersonFullNames,
      'responsiblePersonIdNumber': responsiblePersonIdNumber,
      'responsiblePersonDateOfBirth': responsiblePersonDateOfBirth.toIso8601String(),
      'responsiblePersonWorkNameAndAddress': responsiblePersonWorkNameAndAddress,
      'responsiblePersonWorkPostalAddress': responsiblePersonWorkPostalAddress,
      'responsiblePersonWorkTelNo': responsiblePersonWorkTelNo,
      'responsiblePersonCell': responsiblePersonCell,
      'responsiblePersonHomeTelNo': responsiblePersonHomeTelNo,
      'responsiblePersonEmail': responsiblePersonEmail,
      'responsiblePersonMaritalStatus': responsiblePersonMaritalStatus,
      'responsiblePersonOccupation': responsiblePersonOccupation,
      'relationToPatient': relationToPatient,
      'medicalAidSchemeName': medicalAidSchemeName,
      'medicalAidNumber': medicalAidNumber,
      'planAndDepNumber': planAndDepNumber,
      'mainMemberName': mainMemberName,
      'referringDoctorName': referringDoctorName,
      'referringDoctorCell': referringDoctorCell,
      'additionalReferrerName': additionalReferrerName,
      'additionalReferrerCell': additionalReferrerCell,
      'medicalConditions': medicalConditions,
      'medicalConditionDetails': medicalConditionDetails,
      'currentMedications': currentMedications,
      'allergies': allergies,
      'isSmoker': isSmoker,
      'naturalTreatments': naturalTreatments,
      'accountResponsibilitySignature': accountResponsibilitySignature,
      'accountResponsibilitySignatureDate': accountResponsibilitySignatureDate?.toIso8601String(),
      'woundPhotographyConsentSignature': woundPhotographyConsentSignature,
      'witnessSignature': witnessSignature,
      'woundPhotographyConsentDate': woundPhotographyConsentDate?.toIso8601String(),
      'trainingPhotosConsent': trainingPhotosConsent,
      'trainingPhotosConsentDate': trainingPhotosConsentDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'practitionerId': practitionerId,
      'country': country,
      'countryName': countryName,
      'province': province,
      'baselineWeight': baselineWeight,
      'baselineVasScore': baselineVasScore,
      'baselineWounds': baselineWounds.map((w) => w.toJson()).toList(),
      'baselinePhotos': baselinePhotos,
      'currentWeight': currentWeight,
      'currentVasScore': currentVasScore,
      'currentWounds': currentWounds.map((w) => w.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'weightChange': weightChange,
      'painReduction': painReduction,
      'woundHealingProgress': woundHealingProgress,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      surname: json['surname'],
      fullNames: json['fullNames'],
      idNumber: json['idNumber'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      workNameAndAddress: json['workNameAndAddress'],
      workPostalAddress: json['workPostalAddress'],
      workTelNo: json['workTelNo'],
      patientCell: json['patientCell'],
      homeTelNo: json['homeTelNo'],
      email: json['email'],
      maritalStatus: json['maritalStatus'],
      occupation: json['occupation'],
      responsiblePersonSurname: json['responsiblePersonSurname'],
      responsiblePersonFullNames: json['responsiblePersonFullNames'],
      responsiblePersonIdNumber: json['responsiblePersonIdNumber'],
      responsiblePersonDateOfBirth: DateTime.parse(json['responsiblePersonDateOfBirth']),
      responsiblePersonWorkNameAndAddress: json['responsiblePersonWorkNameAndAddress'],
      responsiblePersonWorkPostalAddress: json['responsiblePersonWorkPostalAddress'],
      responsiblePersonWorkTelNo: json['responsiblePersonWorkTelNo'],
      responsiblePersonCell: json['responsiblePersonCell'],
      responsiblePersonHomeTelNo: json['responsiblePersonHomeTelNo'],
      responsiblePersonEmail: json['responsiblePersonEmail'],
      responsiblePersonMaritalStatus: json['responsiblePersonMaritalStatus'],
      responsiblePersonOccupation: json['responsiblePersonOccupation'],
      relationToPatient: json['relationToPatient'],
      medicalAidSchemeName: json['medicalAidSchemeName'],
      medicalAidNumber: json['medicalAidNumber'],
      planAndDepNumber: json['planAndDepNumber'],
      mainMemberName: json['mainMemberName'],
      referringDoctorName: json['referringDoctorName'],
      referringDoctorCell: json['referringDoctorCell'],
      additionalReferrerName: json['additionalReferrerName'],
      additionalReferrerCell: json['additionalReferrerCell'],
      medicalConditions: Map<String, bool>.from(json['medicalConditions'] ?? {}),
      medicalConditionDetails: Map<String, String?>.from(json['medicalConditionDetails'] ?? {}),
      currentMedications: json['currentMedications'],
      allergies: json['allergies'],
      isSmoker: json['isSmoker'] ?? false,
      naturalTreatments: json['naturalTreatments'],
      accountResponsibilitySignature: json['accountResponsibilitySignature'],
      accountResponsibilitySignatureDate: json['accountResponsibilitySignatureDate'] != null 
          ? DateTime.parse(json['accountResponsibilitySignatureDate']) 
          : null,
      woundPhotographyConsentSignature: json['woundPhotographyConsentSignature'],
      witnessSignature: json['witnessSignature'],
      woundPhotographyConsentDate: json['woundPhotographyConsentDate'] != null 
          ? DateTime.parse(json['woundPhotographyConsentDate']) 
          : null,
      trainingPhotosConsent: json['trainingPhotosConsent'],
      trainingPhotosConsentDate: json['trainingPhotosConsentDate'] != null 
          ? DateTime.parse(json['trainingPhotosConsentDate']) 
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
      practitionerId: json['practitionerId'] ?? '',
      country: json['country'],
      countryName: json['countryName'],
      province: json['province'],
      baselineWeight: json['baselineWeight']?.toDouble(),
      baselineVasScore: json['baselineVasScore'],
      baselineWounds: (json['baselineWounds'] as List).map((w) => Wound.fromJson(w)).toList(),
      baselinePhotos: List<String>.from(json['baselinePhotos'] ?? []),
      currentWeight: json['currentWeight']?.toDouble(),
      currentVasScore: json['currentVasScore'],
      currentWounds: (json['currentWounds'] as List).map((w) => Wound.fromJson(w)).toList(),
      sessions: (json['sessions'] as List).map((s) => Session.fromJson(s)).toList(),
      weightChange: json['weightChange']?.toDouble(),
      painReduction: json['painReduction']?.toDouble(),
      woundHealingProgress: json['woundHealingProgress']?.toDouble(),
    );
  }

  // Firestore serialization methods
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'surname': surname,
      'fullNames': fullNames,
      'idNumber': idNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'workNameAndAddress': workNameAndAddress,
      'workPostalAddress': workPostalAddress,
      'workTelNo': workTelNo,
      'patientCell': patientCell,
      'homeTelNo': homeTelNo,
      'email': email,
      'maritalStatus': maritalStatus,
      'occupation': occupation,
      'responsiblePersonSurname': responsiblePersonSurname,
      'responsiblePersonFullNames': responsiblePersonFullNames,
      'responsiblePersonIdNumber': responsiblePersonIdNumber,
      'responsiblePersonDateOfBirth': Timestamp.fromDate(responsiblePersonDateOfBirth),
      'responsiblePersonWorkNameAndAddress': responsiblePersonWorkNameAndAddress,
      'responsiblePersonWorkPostalAddress': responsiblePersonWorkPostalAddress,
      'responsiblePersonWorkTelNo': responsiblePersonWorkTelNo,
      'responsiblePersonCell': responsiblePersonCell,
      'responsiblePersonHomeTelNo': responsiblePersonHomeTelNo,
      'responsiblePersonEmail': responsiblePersonEmail,
      'responsiblePersonMaritalStatus': responsiblePersonMaritalStatus,
      'responsiblePersonOccupation': responsiblePersonOccupation,
      'relationToPatient': relationToPatient,
      'medicalAidSchemeName': medicalAidSchemeName,
      'medicalAidNumber': medicalAidNumber,
      'planAndDepNumber': planAndDepNumber,
      'mainMemberName': mainMemberName,
      'referringDoctorName': referringDoctorName,
      'referringDoctorCell': referringDoctorCell,
      'additionalReferrerName': additionalReferrerName,
      'additionalReferrerCell': additionalReferrerCell,
      'medicalConditions': medicalConditions,
      'medicalConditionDetails': medicalConditionDetails,
      'currentMedications': currentMedications,
      'allergies': allergies,
      'isSmoker': isSmoker,
      'naturalTreatments': naturalTreatments,
      'accountResponsibilitySignature': accountResponsibilitySignature,
      'accountResponsibilitySignatureDate': accountResponsibilitySignatureDate != null 
          ? Timestamp.fromDate(accountResponsibilitySignatureDate!) 
          : null,
      'woundPhotographyConsentSignature': woundPhotographyConsentSignature,
      'witnessSignature': witnessSignature,
      'woundPhotographyConsentDate': woundPhotographyConsentDate != null 
          ? Timestamp.fromDate(woundPhotographyConsentDate!) 
          : null,
      'trainingPhotosConsent': trainingPhotosConsent,
      'trainingPhotosConsentDate': trainingPhotosConsentDate != null 
          ? Timestamp.fromDate(trainingPhotosConsentDate!) 
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'practitionerId': practitionerId,
      'country': country,
      'countryName': countryName,
      'province': province,
      'baselineWeight': baselineWeight,
      'baselineVasScore': baselineVasScore,
      'baselineWounds': baselineWounds.map((w) => w.toFirestore()).toList(),
      'baselinePhotos': baselinePhotos,
      'currentWeight': currentWeight,
      'currentVasScore': currentVasScore,
      'currentWounds': currentWounds.map((w) => w.toFirestore()).toList(),
      // Note: sessions are stored as a subcollection, not embedded
      'weightChange': weightChange,
      'painReduction': painReduction,
      'woundHealingProgress': woundHealingProgress,
    };
  }

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Patient(
      id: doc.id,
      surname: data['surname'] ?? '',
      fullNames: data['fullNames'] ?? '',
      idNumber: data['idNumber'] ?? '',
      dateOfBirth: data['dateOfBirth']?.toDate() ?? DateTime.now(),
      workNameAndAddress: data['workNameAndAddress'],
      workPostalAddress: data['workPostalAddress'],
      workTelNo: data['workTelNo'],
      patientCell: data['patientCell'] ?? '',
      homeTelNo: data['homeTelNo'],
      email: data['email'] ?? '',
      maritalStatus: data['maritalStatus'],
      occupation: data['occupation'],
      responsiblePersonSurname: data['responsiblePersonSurname'] ?? '',
      responsiblePersonFullNames: data['responsiblePersonFullNames'] ?? '',
      responsiblePersonIdNumber: data['responsiblePersonIdNumber'] ?? '',
      responsiblePersonDateOfBirth: data['responsiblePersonDateOfBirth']?.toDate() ?? DateTime.now(),
      responsiblePersonWorkNameAndAddress: data['responsiblePersonWorkNameAndAddress'],
      responsiblePersonWorkPostalAddress: data['responsiblePersonWorkPostalAddress'],
      responsiblePersonWorkTelNo: data['responsiblePersonWorkTelNo'],
      responsiblePersonCell: data['responsiblePersonCell'] ?? '',
      responsiblePersonHomeTelNo: data['responsiblePersonHomeTelNo'],
      responsiblePersonEmail: data['responsiblePersonEmail'],
      responsiblePersonMaritalStatus: data['responsiblePersonMaritalStatus'],
      responsiblePersonOccupation: data['responsiblePersonOccupation'],
      relationToPatient: data['relationToPatient'],
      medicalAidSchemeName: data['medicalAidSchemeName'] ?? '',
      medicalAidNumber: data['medicalAidNumber'] ?? '',
      planAndDepNumber: data['planAndDepNumber'],
      mainMemberName: data['mainMemberName'] ?? '',
      referringDoctorName: data['referringDoctorName'],
      referringDoctorCell: data['referringDoctorCell'],
      additionalReferrerName: data['additionalReferrerName'],
      additionalReferrerCell: data['additionalReferrerCell'],
      medicalConditions: Map<String, bool>.from(data['medicalConditions'] ?? {}),
      medicalConditionDetails: Map<String, String?>.from(data['medicalConditionDetails'] ?? {}),
      currentMedications: data['currentMedications'],
      allergies: data['allergies'],
      isSmoker: data['isSmoker'] ?? false,
      naturalTreatments: data['naturalTreatments'],
      accountResponsibilitySignature: data['accountResponsibilitySignature'],
      accountResponsibilitySignatureDate: data['accountResponsibilitySignatureDate']?.toDate(),
      woundPhotographyConsentSignature: data['woundPhotographyConsentSignature'],
      witnessSignature: data['witnessSignature'],
      woundPhotographyConsentDate: data['woundPhotographyConsentDate']?.toDate(),
      trainingPhotosConsent: data['trainingPhotosConsent'],
      trainingPhotosConsentDate: data['trainingPhotosConsentDate']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      lastUpdated: data['lastUpdated']?.toDate(),
      practitionerId: data['practitionerId'] ?? '',
      country: data['country'],
      countryName: data['countryName'],
      province: data['province'],
      baselineWeight: data['baselineWeight']?.toDouble() ?? 0.0,
      baselineVasScore: data['baselineVasScore'] ?? 0,
      baselineWounds: (data['baselineWounds'] as List? ?? [])
          .map((w) => Wound.fromFirestore(w))
          .toList(),
      baselinePhotos: List<String>.from(data['baselinePhotos'] ?? []),
      currentWeight: data['currentWeight']?.toDouble(),
      currentVasScore: data['currentVasScore'],
      currentWounds: (data['currentWounds'] as List? ?? [])
          .map((w) => Wound.fromFirestore(w))
          .toList(),
      sessions: [], // Sessions will be loaded separately from subcollection
      weightChange: data['weightChange']?.toDouble(),
      painReduction: data['painReduction']?.toDouble(),
      woundHealingProgress: data['woundHealingProgress']?.toDouble(),
    );
  }
}

class Wound {
  final String id;
  final String location;
  final String type;
  final double length; // in cm
  final double width; // in cm
  final double depth; // in cm
  final String description;
  final List<String> photos;
  final DateTime assessedAt;
  final WoundStage stage;

  const Wound({
    required this.id,
    required this.location,
    required this.type,
    required this.length,
    required this.width,
    required this.depth,
    required this.description,
    required this.photos,
    required this.assessedAt,
    required this.stage,
  });

  double get area => length * width;

  double get volume => length * width * depth;

  Wound copyWith({
    String? id,
    String? location,
    String? type,
    double? length,
    double? width,
    double? depth,
    String? description,
    List<String>? photos,
    DateTime? assessedAt,
    WoundStage? stage,
  }) {
    return Wound(
      id: id ?? this.id,
      location: location ?? this.location,
      type: type ?? this.type,
      length: length ?? this.length,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      assessedAt: assessedAt ?? this.assessedAt,
      stage: stage ?? this.stage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'type': type,
      'length': length,
      'width': width,
      'depth': depth,
      'description': description,
      'photos': photos,
      'assessedAt': assessedAt.toIso8601String(),
      'stage': stage.name,
    };
  }

  factory Wound.fromJson(Map<String, dynamic> json) {
    return Wound(
      id: json['id'],
      location: json['location'],
      type: json['type'],
      length: json['length'],
      width: json['width'],
      depth: json['depth'],
      description: json['description'],
      photos: List<String>.from(json['photos']),
      assessedAt: DateTime.parse(json['assessedAt']),
      stage: WoundStage.values.firstWhere((e) => e.name == json['stage']),
    );
  }

  // Firestore serialization methods
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'location': location,
      'type': type,
      'length': length,
      'width': width,
      'depth': depth,
      'description': description,
      'photos': photos,
      'assessedAt': Timestamp.fromDate(assessedAt),
      'stage': stage.name,
    };
  }

  factory Wound.fromFirestore(Map<String, dynamic> data) {
    return Wound(
      id: data['id'] ?? '',
      location: data['location'] ?? '',
      type: data['type'] ?? '',
      length: data['length']?.toDouble() ?? 0.0,
      width: data['width']?.toDouble() ?? 0.0,
      depth: data['depth']?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      assessedAt: data['assessedAt']?.toDate() ?? DateTime.now(),
      stage: WoundStage.values.firstWhere(
        (e) => e.name == data['stage'],
        orElse: () => WoundStage.stage1,
      ),
    );
  }
}

enum WoundStage {
  stage1('Stage 1 - Intact skin with redness'),
  stage2('Stage 2 - Partial thickness loss'),
  stage3('Stage 3 - Full thickness loss'),
  stage4('Stage 4 - Full thickness with exposed bone/muscle'),
  unstageable('Unstageable'),
  deepTissueInjury('Deep Tissue Injury');

  const WoundStage(this.description);
  final String description;
}

class Session {
  final String id;
  final String patientId;
  final int sessionNumber;
  final DateTime date;
  final double weight;
  final int vasScore;
  final List<Wound> wounds;
  final String notes;
  final List<String> photos;
  final String practitionerId;

  const Session({
    required this.id,
    required this.patientId,
    required this.sessionNumber,
    required this.date,
    required this.weight,
    required this.vasScore,
    required this.wounds,
    required this.notes,
    required this.photos,
    required this.practitionerId,
  });

  Session copyWith({
    String? id,
    String? patientId,
    int? sessionNumber,
    DateTime? date,
    double? weight,
    int? vasScore,
    List<Wound>? wounds,
    String? notes,
    List<String>? photos,
    String? practitionerId,
  }) {
    return Session(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      vasScore: vasScore ?? this.vasScore,
      wounds: wounds ?? this.wounds,
      notes: notes ?? this.notes,
      photos: photos ?? this.photos,
      practitionerId: practitionerId ?? this.practitionerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'sessionNumber': sessionNumber,
      'date': date.toIso8601String(),
      'weight': weight,
      'vasScore': vasScore,
      'wounds': wounds.map((w) => w.toJson()).toList(),
      'notes': notes,
      'photos': photos,
      'practitionerId': practitionerId,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      patientId: json['patientId'],
      sessionNumber: json['sessionNumber'],
      date: DateTime.parse(json['date']),
      weight: json['weight'],
      vasScore: json['vasScore'],
      wounds: (json['wounds'] as List).map((w) => Wound.fromJson(w)).toList(),
      notes: json['notes'],
      photos: List<String>.from(json['photos']),
      practitionerId: json['practitionerId'],
    );
  }

  // Firestore serialization methods
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'patientId': patientId,
      'sessionNumber': sessionNumber,
      'date': Timestamp.fromDate(date),
      'weight': weight,
      'vasScore': vasScore,
      'wounds': wounds.map((w) => w.toFirestore()).toList(),
      'notes': notes,
      'photos': photos,
      'practitionerId': practitionerId,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    };
  }

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Session(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      sessionNumber: data['sessionNumber'] ?? 0,
      date: data['date']?.toDate() ?? DateTime.now(),
      weight: data['weight']?.toDouble() ?? 0.0,
      vasScore: data['vasScore'] ?? 0,
      wounds: (data['wounds'] as List? ?? [])
          .map((w) => Wound.fromFirestore(w))
          .toList(),
      notes: data['notes'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      practitionerId: data['practitionerId'] ?? '',
    );
  }
}
