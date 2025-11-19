import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_column.dart';

/// Form status
enum FormStatus {
  draft,
  active,
  inactive;

  String get displayName {
    switch (this) {
      case FormStatus.draft:
        return 'Draft';
      case FormStatus.active:
        return 'Active';
      case FormStatus.inactive:
        return 'Inactive';
    }
  }

  static FormStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return FormStatus.draft;
      case 'active':
        return FormStatus.active;
      case 'inactive':
        return FormStatus.inactive;
      default:
        return FormStatus.draft;
    }
  }

  String toStringValue() {
    switch (this) {
      case FormStatus.draft:
        return 'draft';
      case FormStatus.active:
        return 'active';
      case FormStatus.inactive:
        return 'inactive';
    }
  }
}

/// Main form model for Facebook lead forms
class LeadForm {
  final String formId;
  final String formName;
  final String? description;
  final FormStatus status;
  final List<FormColumn> columns;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  LeadForm({
    required this.formId,
    required this.formName,
    this.description,
    this.status = FormStatus.draft,
    this.columns = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'formId': formId,
      'formName': formName,
      'description': description,
      'status': status.toStringValue(),
      'columns': columns.map((c) => c.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  factory LeadForm.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeadForm.fromMap(data, doc.id);
  }

  factory LeadForm.fromMap(Map<String, dynamic> map, String id) {
    return LeadForm(
      formId: id,
      formName: map['formName'] as String,
      description: map['description'] as String?,
      status: FormStatus.fromString(map['status'] as String? ?? 'draft'),
      columns: (map['columns'] as List<dynamic>?)
              ?.map((c) => FormColumn.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  LeadForm copyWith({
    String? formId,
    String? formName,
    String? description,
    FormStatus? status,
    List<FormColumn>? columns,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return LeadForm(
      formId: formId ?? this.formId,
      formName: formName ?? this.formName,
      description: description ?? this.description,
      status: status ?? this.status,
      columns: columns ?? this.columns,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

