import 'form_option.dart';

/// Question types supported in forms
enum QuestionType {
  text,
  email,
  phone,
  singleChoice,
  multipleChoice;

  String get displayName {
    switch (this) {
      case QuestionType.text:
        return 'Text Input';
      case QuestionType.email:
        return 'Email';
      case QuestionType.phone:
        return 'Phone Number';
      case QuestionType.singleChoice:
        return 'Single Choice';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
    }
  }

  static QuestionType fromString(String value) {
    switch (value) {
      case 'text':
        return QuestionType.text;
      case 'email':
        return QuestionType.email;
      case 'phone':
        return QuestionType.phone;
      case 'singleChoice':
        return QuestionType.singleChoice;
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      default:
        return QuestionType.text;
    }
  }

  String toString() {
    switch (this) {
      case QuestionType.text:
        return 'text';
      case QuestionType.email:
        return 'email';
      case QuestionType.phone:
        return 'phone';
      case QuestionType.singleChoice:
        return 'singleChoice';
      case QuestionType.multipleChoice:
        return 'multipleChoice';
    }
  }
}

/// Represents a single question in a form
class FormQuestion {
  final String questionId;
  final String questionText;
  final QuestionType questionType;
  final bool required;
  final String? placeholder;
  final List<FormOption> options;
  final bool branchingEnabled;
  final bool isFinalQuestion; // Marks this as the last question in the form path
  final int orderIndex;

  FormQuestion({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    this.required = false,
    this.placeholder,
    this.options = const [],
    this.branchingEnabled = false,
    this.isFinalQuestion = false,
    required this.orderIndex,
  });

  bool get isChoiceType =>
      questionType == QuestionType.singleChoice ||
      questionType == QuestionType.multipleChoice;

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionText': questionText,
      'questionType': questionType.toString(),
      'required': required,
      'placeholder': placeholder,
      'options': options.map((o) => o.toMap()).toList(),
      'branchingEnabled': branchingEnabled,
      'isFinalQuestion': isFinalQuestion,
      'orderIndex': orderIndex,
    };
  }

  factory FormQuestion.fromMap(Map<String, dynamic> map) {
    return FormQuestion(
      questionId: map['questionId'] as String,
      questionText: map['questionText'] as String,
      questionType: QuestionType.fromString(map['questionType'] as String),
      required: map['required'] as bool? ?? false,
      placeholder: map['placeholder'] as String?,
      options: (map['options'] as List<dynamic>?)
              ?.map((o) => FormOption.fromMap(o as Map<String, dynamic>))
              .toList() ??
          [],
      branchingEnabled: map['branchingEnabled'] as bool? ?? false,
      isFinalQuestion: map['isFinalQuestion'] as bool? ?? false,
      orderIndex: map['orderIndex'] as int,
    );
  }

  FormQuestion copyWith({
    String? questionId,
    String? questionText,
    QuestionType? questionType,
    bool? required,
    String? placeholder,
    List<FormOption>? options,
    bool? branchingEnabled,
    bool? isFinalQuestion,
    int? orderIndex,
  }) {
    return FormQuestion(
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      required: required ?? this.required,
      placeholder: placeholder ?? this.placeholder,
      options: options ?? this.options,
      branchingEnabled: branchingEnabled ?? this.branchingEnabled,
      isFinalQuestion: isFinalQuestion ?? this.isFinalQuestion,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

