/// GoHighLevel Lead model representing a contact/lead in the CRM
class GHLLead {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? source;
  final String? status;
  final List<String> tags;
  final Map<String, dynamic> customFields;
  final DateTime? dateAdded;
  final DateTime? lastActivity;
  final String? assignedTo; // Sales agent ID
  final String? assignedToName; // Sales agent name
  final GHLLeadClassification classification;
  final GHLLeadTracking tracking;

  GHLLead({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.source,
    this.status,
    this.tags = const [],
    this.customFields = const {},
    this.dateAdded,
    this.lastActivity,
    this.assignedTo,
    this.assignedToName,
    required this.classification,
    required this.tracking,
  });

  /// Get full name of the lead
  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim();
  }

  /// Check if lead is from Erich Pipeline
  bool get isErichPipeline => classification.pipeline == 'Erich Pipeline';

  /// Check if lead is HQL (High Quality Lead)
  bool get isHQL => classification.leadType == GHLLeadType.hql;

  /// Check if lead is Ave Lead (Average Lead)
  bool get isAveLead => classification.leadType == GHLLeadType.aveLead;

  /// Get lead quality display name
  String get leadQualityDisplay {
    switch (classification.leadType) {
      case GHLLeadType.hql:
        return 'HQL';
      case GHLLeadType.aveLead:
        return 'Ave Lead';
      case GHLLeadType.other:
        return 'Other';
    }
  }

  factory GHLLead.fromJson(Map<String, dynamic> json) {
    return GHLLead(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      source: json['source']?.toString(),
      status: json['status']?.toString(),
      tags: List<String>.from(json['tags'] ?? []),
      customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
      dateAdded: json['dateAdded'] != null ? DateTime.tryParse(json['dateAdded']) : null,
      lastActivity: json['lastActivity'] != null ? DateTime.tryParse(json['lastActivity']) : null,
      assignedTo: json['assignedTo']?.toString(),
      assignedToName: json['assignedToName']?.toString(),
      classification: GHLLeadClassification.fromJson(json['classification'] ?? {}),
      tracking: GHLLeadTracking.fromJson(json['tracking'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'source': source,
      'status': status,
      'tags': tags,
      'customFields': customFields,
      'dateAdded': dateAdded?.toIso8601String(),
      'lastActivity': lastActivity?.toIso8601String(),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'classification': classification.toJson(),
      'tracking': tracking.toJson(),
    };
  }

  GHLLead copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? source,
    String? status,
    List<String>? tags,
    Map<String, dynamic>? customFields,
    DateTime? dateAdded,
    DateTime? lastActivity,
    String? assignedTo,
    String? assignedToName,
    GHLLeadClassification? classification,
    GHLLeadTracking? tracking,
  }) {
    return GHLLead(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      source: source ?? this.source,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      customFields: customFields ?? this.customFields,
      dateAdded: dateAdded ?? this.dateAdded,
      lastActivity: lastActivity ?? this.lastActivity,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      classification: classification ?? this.classification,
      tracking: tracking ?? this.tracking,
    );
  }
}

/// Lead classification information
class GHLLeadClassification {
  final String pipeline;
  final String? stage;
  final GHLLeadType leadType;
  final double? leadScore;

  GHLLeadClassification({
    required this.pipeline,
    this.stage,
    required this.leadType,
    this.leadScore,
  });

  factory GHLLeadClassification.fromJson(Map<String, dynamic> json) {
    return GHLLeadClassification(
      pipeline: json['pipeline']?.toString() ?? 'Unknown',
      stage: json['stage']?.toString(),
      leadType: _parseLeadType(json['leadType']),
      leadScore: json['leadScore']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pipeline': pipeline,
      'stage': stage,
      'leadType': leadType.name,
      'leadScore': leadScore,
    };
  }

  static GHLLeadType _parseLeadType(dynamic value) {
    if (value == null) return GHLLeadType.other;
    final str = value.toString().toLowerCase();
    if (str.contains('hql')) return GHLLeadType.hql;
    if (str.contains('ave')) return GHLLeadType.aveLead;
    return GHLLeadType.other;
  }
}

/// Lead tracking information for the specific metrics we need
class GHLLeadTracking {
  final bool hasAppointment;
  final DateTime? appointmentDate;
  final bool isOptedIn;
  final bool isNoShow;
  final bool hasSale;
  final bool hasDeposit;
  final double? depositAmount;
  final bool isInstalled;
  final DateTime? installationDate;
  final double? cashCollected;
  final DateTime? saleDate;
  final String? saleStatus;

  GHLLeadTracking({
    this.hasAppointment = false,
    this.appointmentDate,
    this.isOptedIn = false,
    this.isNoShow = false,
    this.hasSale = false,
    this.hasDeposit = false,
    this.depositAmount,
    this.isInstalled = false,
    this.installationDate,
    this.cashCollected,
    this.saleDate,
    this.saleStatus,
  });

  /// Get appointment status display
  String get appointmentStatus {
    if (!hasAppointment) return 'No Appointment';
    if (isNoShow) return 'No Show';
    if (isOptedIn) return 'Opted In';
    return 'Appointment Set';
  }

  /// Get sale status display
  String get saleStatusDisplay {
    if (!hasSale) return 'No Sale';
    return saleStatus ?? 'Sale';
  }

  factory GHLLeadTracking.fromJson(Map<String, dynamic> json) {
    return GHLLeadTracking(
      hasAppointment: json['hasAppointment'] == true,
      appointmentDate: json['appointmentDate'] != null ? DateTime.tryParse(json['appointmentDate']) : null,
      isOptedIn: json['isOptedIn'] == true,
      isNoShow: json['isNoShow'] == true,
      hasSale: json['hasSale'] == true,
      hasDeposit: json['hasDeposit'] == true,
      depositAmount: json['depositAmount']?.toDouble(),
      isInstalled: json['isInstalled'] == true,
      installationDate: json['installationDate'] != null ? DateTime.tryParse(json['installationDate']) : null,
      cashCollected: json['cashCollected']?.toDouble(),
      saleDate: json['saleDate'] != null ? DateTime.tryParse(json['saleDate']) : null,
      saleStatus: json['saleStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasAppointment': hasAppointment,
      'appointmentDate': appointmentDate?.toIso8601String(),
      'isOptedIn': isOptedIn,
      'isNoShow': isNoShow,
      'hasSale': hasSale,
      'hasDeposit': hasDeposit,
      'depositAmount': depositAmount,
      'isInstalled': isInstalled,
      'installationDate': installationDate?.toIso8601String(),
      'cashCollected': cashCollected,
      'saleDate': saleDate?.toIso8601String(),
      'saleStatus': saleStatus,
    };
  }
}

/// Enum for lead types
enum GHLLeadType {
  hql,
  aveLead,
  other,
}
