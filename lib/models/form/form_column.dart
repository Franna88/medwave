import 'form_question.dart';

/// Represents a column of questions in the form builder
class FormColumn {
  final String columnId;
  final int columnIndex;
  final String? parentQuestionId; // null for first column
  final String? parentAnswerId; // null for first column
  final List<FormQuestion> questions;

  FormColumn({
    required this.columnId,
    required this.columnIndex,
    this.parentQuestionId,
    this.parentAnswerId,
    this.questions = const [],
  });

  bool get isFirstColumn => parentQuestionId == null && parentAnswerId == null;

  Map<String, dynamic> toMap() {
    return {
      'columnId': columnId,
      'columnIndex': columnIndex,
      'parentQuestionId': parentQuestionId,
      'parentAnswerId': parentAnswerId,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory FormColumn.fromMap(Map<String, dynamic> map) {
    return FormColumn(
      columnId: map['columnId'] as String,
      columnIndex: map['columnIndex'] as int,
      parentQuestionId: map['parentQuestionId'] as String?,
      parentAnswerId: map['parentAnswerId'] as String?,
      questions: (map['questions'] as List<dynamic>?)
              ?.map((q) => FormQuestion.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  FormColumn copyWith({
    String? columnId,
    int? columnIndex,
    String? parentQuestionId,
    String? parentAnswerId,
    List<FormQuestion>? questions,
  }) {
    return FormColumn(
      columnId: columnId ?? this.columnId,
      columnIndex: columnIndex ?? this.columnIndex,
      parentQuestionId: parentQuestionId ?? this.parentQuestionId,
      parentAnswerId: parentAnswerId ?? this.parentAnswerId,
      questions: questions ?? this.questions,
    );
  }
}

