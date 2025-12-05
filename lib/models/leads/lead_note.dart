import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for notes/comments on lead stage transitions
/// The text field can be either a String (legacy format) or Map<String, dynamic> (questionnaire format)
class LeadNote {
  final dynamic text; // Can be String or Map<String, dynamic>
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;
  final String? stageTransition; // e.g., "New Lead -> Contacted"

  LeadNote({
    required this.text,
    required this.createdAt,
    required this.createdBy,
    this.createdByName,
    this.stageTransition,
  });

  /// Check if this note contains structured questionnaire data
  bool get isQuestionnaire => text is Map;

  /// Get questionnaire data safely
  /// Returns null if this is not a questionnaire note
  Map<String, dynamic>? get questionnaireData {
    if (isQuestionnaire) {
      return Map<String, dynamic>.from(text as Map);
    }
    return null;
  }

  /// Get text as string (for legacy notes or display)
  String get textAsString {
    if (text is String) {
      return text as String;
    }
    // If it's a map, we'll handle display in the UI
    return '';
  }

  factory LeadNote.fromMap(Map<String, dynamic> map) {
    // Handle both String and Map formats for backward compatibility
    dynamic textValue = map['text'];
    
    // If text is a Map, preserve it as Map
    if (textValue is Map) {
      textValue = Map<String, dynamic>.from(textValue);
    } else {
      // Otherwise treat as String
      textValue = textValue?.toString() ?? '';
    }

    return LeadNote(
      text: textValue,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      stageTransition: map['stageTransition']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text, // Store as-is (String or Map)
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'stageTransition': stageTransition,
    };
  }

  LeadNote copyWith({
    dynamic text,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    String? stageTransition,
  }) {
    return LeadNote(
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      stageTransition: stageTransition ?? this.stageTransition,
    );
  }
}

