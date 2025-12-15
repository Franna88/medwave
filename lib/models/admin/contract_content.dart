import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for contract content stored in Firebase
/// The content is stored as Quill Delta JSON format for rich text editing
class ContractContent {
  final String id;
  final List<dynamic> content; // Quill Delta JSON
  final String plainText; // Plain text version for preview/search
  final DateTime lastModified;
  final String modifiedBy;
  final int version;

  ContractContent({
    required this.id,
    required this.content,
    required this.plainText,
    required this.lastModified,
    required this.modifiedBy,
    this.version = 1,
  });

  /// Create from Firestore document
  factory ContractContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      return ContractContent.empty();
    }
    
    return ContractContent(
      id: doc.id,
      content: data['content'] as List<dynamic>? ?? [],
      plainText: data['plainText'] as String? ?? '',
      lastModified: (data['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedBy: data['modifiedBy'] as String? ?? '',
      version: data['version'] as int? ?? 1,
    );
  }

  /// Create from Map
  factory ContractContent.fromMap(Map<String, dynamic> map, {String? id}) {
    return ContractContent(
      id: id ?? map['id'] as String? ?? 'contract_content',
      content: map['content'] as List<dynamic>? ?? [],
      plainText: map['plainText'] as String? ?? '',
      lastModified: map['lastModified'] is Timestamp
          ? (map['lastModified'] as Timestamp).toDate()
          : DateTime.tryParse(map['lastModified'] as String? ?? '') ?? DateTime.now(),
      modifiedBy: map['modifiedBy'] as String? ?? '',
      version: map['version'] as int? ?? 1,
    );
  }

  /// Create empty contract content
  factory ContractContent.empty() {
    return ContractContent(
      id: 'contract_content',
      content: [
        {'insert': '\n'}
      ],
      plainText: '',
      lastModified: DateTime.now(),
      modifiedBy: '',
      version: 0,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'plainText': plainText,
      'lastModified': Timestamp.fromDate(lastModified),
      'modifiedBy': modifiedBy,
      'version': version,
    };
  }

  /// Create a copy with updated fields
  ContractContent copyWith({
    String? id,
    List<dynamic>? content,
    String? plainText,
    DateTime? lastModified,
    String? modifiedBy,
    int? version,
  }) {
    return ContractContent(
      id: id ?? this.id,
      content: content ?? this.content,
      plainText: plainText ?? this.plainText,
      lastModified: lastModified ?? this.lastModified,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      version: version ?? this.version,
    );
  }

  /// Check if content is empty
  bool get isEmpty => content.isEmpty || (content.length == 1 && content[0]['insert'] == '\n');

  /// Check if content exists
  bool get hasContent => !isEmpty;

  @override
  String toString() {
    return 'ContractContent(id: $id, version: $version, lastModified: $lastModified)';
  }
}

