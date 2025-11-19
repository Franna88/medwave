import 'package:cloud_firestore/cloud_firestore.dart';
import 'lead_stage.dart';

/// Model for a lead channel (pipeline)
class LeadChannel {
  final String id;
  final String name;
  final List<LeadStage> stages;
  final DateTime createdAt;
  final bool isActive;

  LeadChannel({
    required this.id,
    required this.name,
    required this.stages,
    required this.createdAt,
    this.isActive = true,
  });

  factory LeadChannel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeadChannel.fromMap(data, doc.id);
  }

  factory LeadChannel.fromMap(Map<String, dynamic> map, String id) {
    return LeadChannel(
      id: id,
      name: map['name']?.toString() ?? '',
      stages: (map['stages'] as List<dynamic>?)
              ?.map((s) => LeadStage.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stages': stages.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  LeadChannel copyWith({
    String? id,
    String? name,
    List<LeadStage>? stages,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return LeadChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      stages: stages ?? this.stages,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get stage by ID
  LeadStage? getStageById(String stageId) {
    try {
      return stages.firstWhere((s) => s.id == stageId);
    } catch (e) {
      return null;
    }
  }

  /// Get the follow-up stage if it exists
  LeadStage? get followUpStage {
    try {
      return stages.firstWhere((s) => s.isFollowUpStage);
    } catch (e) {
      return null;
    }
  }

  /// Create default "New Leads" channel
  static LeadChannel createDefault() {
    return LeadChannel(
      id: 'new_leads',
      name: 'New Leads',
      stages: LeadStage.getDefaultStages(),
      createdAt: DateTime.now(),
      isActive: true,
    );
  }
}

