class PMBCondition {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icd10Code;
  final bool isActive;

  const PMBCondition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icd10Code,
    this.isActive = true,
  });

  PMBCondition copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? icd10Code,
    bool? isActive,
  }) {
    return PMBCondition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icd10Code: icd10Code ?? this.icd10Code,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'icd10Code': icd10Code,
      'isActive': isActive,
    };
  }

  factory PMBCondition.fromJson(Map<String, dynamic> json) {
    return PMBCondition(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      icd10Code: json['icd10Code'],
      isActive: json['isActive'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PMBCondition && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PMBCondition{id: $id, name: $name, category: $category}';
}
