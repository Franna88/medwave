/// GoHighLevel Pipeline model
class GHLPipeline {
  final String id;
  final String name;
  final List<GHLPipelineStage> stages;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  GHLPipeline({
    required this.id,
    required this.name,
    this.stages = const [],
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  /// Check if this is the Erich Pipeline
  bool get isErichPipeline => name.toLowerCase().contains('erich');

  factory GHLPipeline.fromJson(Map<String, dynamic> json) {
    return GHLPipeline(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      stages: (json['stages'] as List?)
          ?.map((stage) => GHLPipelineStage.fromJson(stage))
          .toList() ?? [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      isActive: json['isActive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stages': stages.map((stage) => stage.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}

/// Pipeline stage model
class GHLPipelineStage {
  final String id;
  final String name;
  final int position;
  final String? color;

  GHLPipelineStage({
    required this.id,
    required this.name,
    required this.position,
    this.color,
  });

  factory GHLPipelineStage.fromJson(Map<String, dynamic> json) {
    return GHLPipelineStage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      position: json['position']?.toInt() ?? 0,
      color: json['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'color': color,
    };
  }
}
