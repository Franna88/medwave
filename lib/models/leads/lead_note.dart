import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for notes/comments on lead stage transitions
class LeadNote {
  final String text;
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

  factory LeadNote.fromMap(Map<String, dynamic> map) {
    return LeadNote(
      text: map['text']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      stageTransition: map['stageTransition']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'stageTransition': stageTransition,
    };
  }

  LeadNote copyWith({
    String? text,
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

