/// Represents an answer option for choice-type questions
class FormOption {
  final String optionId;
  final String optionText;
  final String? leadsToColumnId; // null if this is an end point
  final bool isFinalAnswer; // Marks this option as ending the form
  final int orderIndex;

  FormOption({
    required this.optionId,
    required this.optionText,
    this.leadsToColumnId,
    this.isFinalAnswer = false,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'optionId': optionId,
      'optionText': optionText,
      'leadsToColumnId': leadsToColumnId,
      'isFinalAnswer': isFinalAnswer,
      'orderIndex': orderIndex,
    };
  }

  factory FormOption.fromMap(Map<String, dynamic> map) {
    return FormOption(
      optionId: map['optionId'] as String,
      optionText: map['optionText'] as String,
      leadsToColumnId: map['leadsToColumnId'] as String?,
      isFinalAnswer: map['isFinalAnswer'] as bool? ?? false,
      orderIndex: map['orderIndex'] as int,
    );
  }

  FormOption copyWith({
    String? optionId,
    String? optionText,
    String? leadsToColumnId,
    bool? isFinalAnswer,
    int? orderIndex,
  }) {
    return FormOption(
      optionId: optionId ?? this.optionId,
      optionText: optionText ?? this.optionText,
      leadsToColumnId: leadsToColumnId ?? this.leadsToColumnId,
      isFinalAnswer: isFinalAnswer ?? this.isFinalAnswer,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

