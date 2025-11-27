import 'package:flutter/material.dart';
import '../../models/form/lead_form.dart';
import '../../models/form/form_column.dart';
import '../../models/form/form_question.dart';

/// Widget that renders a form dynamically based on LeadForm schema
class DynamicFormRenderer extends StatefulWidget {
  final LeadForm form;
  final Function(Map<String, dynamic> responses) onSubmit;

  const DynamicFormRenderer({
    super.key,
    required this.form,
    required this.onSubmit,
  });

  @override
  State<DynamicFormRenderer> createState() => _DynamicFormRendererState();
}

class _DynamicFormRendererState extends State<DynamicFormRenderer> {
  final Map<String, dynamic> _responses = {};
  final Map<String, TextEditingController> _textControllers = {};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _currentColumnIndex = 0;
  final List<String> _selectedPath = []; // Tracks selected questions/options for branching

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<FormColumn> _getVisibleColumns() {
    if (widget.form.columns.isEmpty) return [];

    final visibleColumns = <FormColumn>[];

    // Always show the first column
    final firstColumn = widget.form.columns.firstWhere(
      (col) => col.isFirstColumn,
      orElse: () => widget.form.columns.first,
    );
    visibleColumns.add(firstColumn);

    // Show subsequent columns based on selected path
    for (int i = 0; i < _selectedPath.length; i++) {
      final selectedId = _selectedPath[i];

      final nextColumn = widget.form.columns.firstWhere(
        (col) => col.parentQuestionId == selectedId || col.parentAnswerId == selectedId,
        orElse: () => FormColumn(columnId: '', columnIndex: -1),
      );

      if (nextColumn.columnIndex != -1) {
        visibleColumns.add(nextColumn);
      } else {
        break;
      }
    }

    return visibleColumns;
  }

  void _handleQuestionAnswer(FormQuestion question, dynamic answer) {
    setState(() {
      _responses[question.questionId] = answer;

      // Update selected path for branching
      if (_selectedPath.length > _currentColumnIndex) {
        _selectedPath.removeRange(_currentColumnIndex, _selectedPath.length);
      }
      _selectedPath.add(question.questionId);

      // If it's a choice question, also track the selected option
      if (question.isChoiceType && answer is String) {
        _selectedPath.add(answer);
      }
    });
  }

  void _handleOptionSelection(FormQuestion question, String optionId) {
    setState(() {
      if (question.questionType == QuestionType.singleChoice) {
        _responses[question.questionId] = optionId;
      } else if (question.questionType == QuestionType.multipleChoice) {
        final currentAnswers = List<String>.from(
          _responses[question.questionId] as List? ?? [],
        );
        if (currentAnswers.contains(optionId)) {
          currentAnswers.remove(optionId);
        } else {
          currentAnswers.add(optionId);
        }
        _responses[question.questionId] = currentAnswers;
      }

      // Update selected path
      if (_selectedPath.length > _currentColumnIndex) {
        _selectedPath.removeRange(_currentColumnIndex, _selectedPath.length);
      }
      _selectedPath.add(question.questionId);
      _selectedPath.add(optionId);
    });
  }

  void _goToNextColumn() {
    final visibleColumns = _getVisibleColumns();
    if (_currentColumnIndex < visibleColumns.length - 1) {
      setState(() {
        _currentColumnIndex++;
      });
    }
  }

  void _goToPreviousColumn() {
    if (_currentColumnIndex > 0) {
      setState(() {
        _currentColumnIndex--;
        // Truncate selected path
        if (_selectedPath.length > _currentColumnIndex) {
          _selectedPath.removeRange(_currentColumnIndex, _selectedPath.length);
        }
      });
    }
  }

  bool _isCurrentColumnComplete() {
    final visibleColumns = _getVisibleColumns();
    if (_currentColumnIndex >= visibleColumns.length) return false;

    final currentColumn = visibleColumns[_currentColumnIndex];
    for (final question in currentColumn.questions) {
      if (question.required && !_responses.containsKey(question.questionId)) {
        return false;
      }
    }
    return true;
  }

  bool _isFormComplete() {
    final visibleColumns = _getVisibleColumns();
    for (final column in visibleColumns) {
      for (final question in column.questions) {
        if (question.required && !_responses.containsKey(question.questionId)) {
          return false;
        }
      }
    }
    return true;
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSubmit(_responses);
  }

  Widget _buildQuestionField(FormQuestion question) {
    if (!_textControllers.containsKey(question.questionId)) {
      _textControllers[question.questionId] = TextEditingController(
        text: _responses[question.questionId]?.toString() ?? '',
      );
    }

    final controller = _textControllers[question.questionId]!;

    switch (question.questionType) {
      case QuestionType.text:
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: question.questionText,
            hintText: question.placeholder ?? 'Enter your answer',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (question.required && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
          onChanged: (value) {
            _handleQuestionAnswer(question, value);
          },
        );

      case QuestionType.email:
        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: question.questionText,
            hintText: question.placeholder ?? 'Enter your email',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (question.required && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            if (value != null && value.isNotEmpty && !value.contains('@')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          onChanged: (value) {
            _handleQuestionAnswer(question, value);
          },
        );

      case QuestionType.phone:
        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: question.questionText,
            hintText: question.placeholder ?? 'Enter your phone number',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (question.required && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
          onChanged: (value) {
            _handleQuestionAnswer(question, value);
          },
        );

      case QuestionType.singleChoice:
        final selectedOption = _responses[question.questionId] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (question.required)
              const Text(
                '* Required',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 8),
            ...question.options.map((option) {
              return RadioListTile<String>(
                title: Text(option.optionText),
                value: option.optionId,
                groupValue: selectedOption,
                onChanged: (value) {
                  if (value != null) {
                    _handleOptionSelection(question, value);
                  }
                },
              );
            }),
            if (question.required && selectedOption == null)
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'Please select an option',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );

      case QuestionType.multipleChoice:
        final selectedOptions = List<String>.from(
          _responses[question.questionId] as List? ?? [],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (question.required)
              const Text(
                '* Required',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 8),
            ...question.options.map((option) {
              return CheckboxListTile(
                title: Text(option.optionText),
                value: selectedOptions.contains(option.optionId),
                onChanged: (checked) {
                  _handleOptionSelection(question, option.optionId);
                },
              );
            }),
            if (question.required && selectedOptions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  'Please select at least one option',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleColumns = _getVisibleColumns();
    if (visibleColumns.isEmpty) {
      return const Center(
        child: Text('No questions available'),
      );
    }

    final currentColumn = visibleColumns[_currentColumnIndex];
    final isLastColumn = _currentColumnIndex == visibleColumns.length - 1;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(
              value: ((_currentColumnIndex + 1) / visibleColumns.length),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Step ${_currentColumnIndex + 1} of ${visibleColumns.length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Questions in current column
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: currentColumn.questions
                    .map((question) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _buildQuestionField(question),
                        ))
                    .toList(),
              ),
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentColumnIndex > 0)
                  OutlinedButton(
                    onPressed: _goToPreviousColumn,
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                if (!isLastColumn)
                  ElevatedButton(
                    onPressed: _isCurrentColumnComplete() ? _goToNextColumn : null,
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Submit'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

