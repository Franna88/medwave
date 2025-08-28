import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing different types of ICD-10 codes for wound care
enum ICD10CodeType {
  primary,
  secondary,
  externalCause;

  String get displayName {
    switch (this) {
      case ICD10CodeType.primary:
        return 'Primary';
      case ICD10CodeType.secondary:
        return 'Secondary';
      case ICD10CodeType.externalCause:
        return 'External Cause';
    }
  }
}

/// Model representing an ICD-10 code from the South African Master Industry Table
class ICD10Code {
  final String icd10Code;
  final String whoFullDescription;
  final String chapterNumber;
  final String chapterDescription;
  final String groupCode;
  final String groupDescription;
  final bool validForClinicalUse;
  final bool validForPrimary;
  final bool isPmbEligible;
  final String? pmbDescription;

  const ICD10Code({
    required this.icd10Code,
    required this.whoFullDescription,
    required this.chapterNumber,
    required this.chapterDescription,
    required this.groupCode,
    required this.groupDescription,
    required this.validForClinicalUse,
    required this.validForPrimary,
    this.isPmbEligible = false,
    this.pmbDescription,
  });

  /// Create ICD10Code from Firestore document
  factory ICD10Code.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ICD10Code(
      icd10Code: data['icd10_code'] ?? '',
      whoFullDescription: data['who_full_description'] ?? '',
      chapterNumber: data['chapter_number'] ?? '',
      chapterDescription: data['chapter_description'] ?? '',
      groupCode: data['group_code'] ?? '',
      groupDescription: data['group_description'] ?? '',
      validForClinicalUse: data['valid_for_clinical_use'] ?? false,
      validForPrimary: data['valid_for_primary'] ?? false,
      isPmbEligible: data['is_pmb_eligible'] ?? false,
      pmbDescription: data['pmb_description'],
    );
  }

  /// Create ICD10Code from JSON (for API responses or local data)
  factory ICD10Code.fromJson(Map<String, dynamic> json) {
    return ICD10Code(
      icd10Code: json['icd10_code'] ?? '',
      whoFullDescription: json['who_full_description'] ?? '',
      chapterNumber: json['chapter_number'] ?? '',
      chapterDescription: json['chapter_description'] ?? '',
      groupCode: json['group_code'] ?? '',
      groupDescription: json['group_description'] ?? '',
      validForClinicalUse: json['valid_for_clinical_use'] ?? false,
      validForPrimary: json['valid_for_primary'] ?? false,
      isPmbEligible: json['is_pmb_eligible'] ?? false,
      pmbDescription: json['pmb_description'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'icd10_code': icd10Code,
      'who_full_description': whoFullDescription,
      'chapter_number': chapterNumber,
      'chapter_description': chapterDescription,
      'group_code': groupCode,
      'group_description': groupDescription,
      'valid_for_clinical_use': validForClinicalUse,
      'valid_for_primary': validForPrimary,
      'is_pmb_eligible': isPmbEligible,
      'pmb_description': pmbDescription,
    };
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  @override
  String toString() {
    return '$icd10Code: $whoFullDescription';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ICD10Code &&
          runtimeType == other.runtimeType &&
          icd10Code == other.icd10Code;

  @override
  int get hashCode => icd10Code.hashCode;
}

/// Model representing a selected ICD-10 code for a specific wound care case
class SelectedICD10Code {
  final ICD10Code code;
  final ICD10CodeType type;
  final String? justification;
  final double? confidence;
  final DateTime selectedAt;

  const SelectedICD10Code({
    required this.code,
    required this.type,
    this.justification,
    this.confidence,
    required this.selectedAt,
  });

  /// Create SelectedICD10Code from Firestore document
  factory SelectedICD10Code.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SelectedICD10Code(
      code: ICD10Code.fromJson(data['code'] ?? {}),
      type: ICD10CodeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ICD10CodeType.primary,
      ),
      justification: data['justification'],
      confidence: data['confidence']?.toDouble(),
      selectedAt: (data['selected_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create SelectedICD10Code from JSON
  factory SelectedICD10Code.fromJson(Map<String, dynamic> json) {
    return SelectedICD10Code(
      code: ICD10Code.fromJson(json['code'] ?? {}),
      type: ICD10CodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ICD10CodeType.primary,
      ),
      justification: json['justification'],
      confidence: json['confidence']?.toDouble(),
      selectedAt: DateTime.parse(json['selected_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code.toJson(),
      'type': type.name,
      'justification': justification,
      'confidence': confidence,
      'selected_at': selectedAt.toIso8601String(),
    };
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'code': code.toFirestore(),
      'type': type.name,
      'justification': justification,
      'confidence': confidence,
      'selected_at': Timestamp.fromDate(selectedAt),
    };
  }

  @override
  String toString() {
    return '${code.icd10Code} (${type.displayName}): ${code.whoFullDescription}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedICD10Code &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          type == other.type;

  @override
  int get hashCode => Object.hash(code, type);
}

/// Model for ICD-10 search results from AI analysis
class ICD10SearchResult {
  final ICD10Code code;
  final double confidence;
  final List<String> matchedKeywords;
  final String? explanation;

  const ICD10SearchResult({
    required this.code,
    required this.confidence,
    required this.matchedKeywords,
    this.explanation,
  });

  factory ICD10SearchResult.fromJson(Map<String, dynamic> json) {
    return ICD10SearchResult(
      code: ICD10Code.fromJson(json['code'] ?? {}),
      confidence: json['confidence']?.toDouble() ?? 0.0,
      matchedKeywords: List<String>.from(json['matched_keywords'] ?? []),
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code.toJson(),
      'confidence': confidence,
      'matched_keywords': matchedKeywords,
      'explanation': explanation,
    };
  }
}

/// Helper class for ICD-10 code validation and utilities
class ICD10CodeValidator {
  /// Validate if a code is suitable for primary diagnosis
  static bool isValidPrimary(ICD10Code code) {
    return code.validForPrimary && code.validForClinicalUse;
  }

  /// Validate if a code is suitable for secondary diagnosis
  static bool isValidSecondary(ICD10Code code) {
    return code.validForClinicalUse;
  }

  /// Check if a code is an external cause code (Chapter XX)
  static bool isExternalCause(ICD10Code code) {
    return code.chapterNumber == 'XX' || 
           code.icd10Code.startsWith('V') || 
           code.icd10Code.startsWith('W') || 
           code.icd10Code.startsWith('X') || 
           code.icd10Code.startsWith('Y');
  }

  /// Check if a code is wound-related (primarily Chapter XII)
  static bool isWoundRelated(ICD10Code code) {
    return code.chapterNumber == 'XII' || 
           code.icd10Code.startsWith('L') ||
           code.whoFullDescription.toLowerCase().contains('wound') ||
           code.whoFullDescription.toLowerCase().contains('ulcer') ||
           code.whoFullDescription.toLowerCase().contains('pressure') ||
           code.whoFullDescription.toLowerCase().contains('injury');
  }

  /// Format code for display in reports
  static String formatForReport(SelectedICD10Code selectedCode) {
    final pmb = selectedCode.code.isPmbEligible ? ' (PMB)' : '';
    return '${selectedCode.code.icd10Code}: ${selectedCode.code.whoFullDescription}$pmb';
  }
}
