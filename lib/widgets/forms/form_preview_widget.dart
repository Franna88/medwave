import 'package:flutter/material.dart';
import '../../models/form/lead_form.dart';
import '../../models/form/form_column.dart';
import '../../models/form/form_question.dart';
import '../../theme/app_theme.dart';

class FormPreviewWidget extends StatefulWidget {
  final LeadForm form;

  const FormPreviewWidget({
    super.key,
    required this.form,
  });

  @override
  State<FormPreviewWidget> createState() => _FormPreviewWidgetState();
}

class _FormPreviewWidgetState extends State<FormPreviewWidget> {
  final Map<String, dynamic> _responses = {};
  final List<FormQuestion> _questionPath = [];
  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildQuestionPath();
  }

  void _buildQuestionPath() {
    _questionPath.clear();
    
    if (widget.form.columns.isEmpty) return;

    // Start with first column
    final firstColumn = widget.form.columns.firstWhere(
      (col) => col.isFirstColumn,
      orElse: () => widget.form.columns.first,
    );

    if (firstColumn.questions.isNotEmpty) {
      _questionPath.add(firstColumn.questions.first);
    }
  }

  void _handleAnswer(dynamic answer) {
    if (_currentQuestionIndex >= _questionPath.length) return;

    final currentQuestion = _questionPath[_currentQuestionIndex];
    setState(() {
      _responses[currentQuestion.questionId] = answer;
    });

    // Determine next question
    _navigateToNextQuestion(currentQuestion, answer);
  }

  void _navigateToNextQuestion(FormQuestion currentQuestion, dynamic answer) {
    // Find current column
    FormColumn? currentColumn;
    for (final col in widget.form.columns) {
      if (col.questions.any((q) => q.questionId == currentQuestion.questionId)) {
        currentColumn = col;
        break;
      }
    }

    if (currentColumn == null) return;

    // Check if there's a next question in the same column
    final currentQuestionIndexInColumn = currentColumn.questions
        .indexWhere((q) => q.questionId == currentQuestion.questionId);
    
    if (currentQuestionIndexInColumn < currentColumn.questions.length - 1) {
      // Move to next question in same column
      setState(() {
        _currentQuestionIndex++;
        _questionPath.add(currentColumn!.questions[currentQuestionIndexInColumn + 1]);
      });
      return;
    }

    // Check if this question has branching
    if (currentQuestion.branchingEnabled && currentQuestion.isChoiceType) {
      // Find the selected option
      String? selectedOptionId;
      if (answer is String) {
        selectedOptionId = answer;
      } else if (answer is List && answer.isNotEmpty) {
        selectedOptionId = answer.first;
      }

      if (selectedOptionId != null) {
        // Find the option
        final option = currentQuestion.options.firstWhere(
          (opt) => opt.optionId == selectedOptionId,
          orElse: () => currentQuestion.options.first,
        );

        // Find the column this option leads to
        if (option.leadsToColumnId != null) {
          final nextColumn = widget.form.columns.firstWhere(
            (col) => col.columnId == option.leadsToColumnId,
            orElse: () => FormColumn(columnId: '', columnIndex: -1),
          );

          if (nextColumn.columnIndex != -1 && nextColumn.questions.isNotEmpty) {
            setState(() {
              _currentQuestionIndex++;
              _questionPath.add(nextColumn.questions.first);
            });
            return;
          }
        }
      }
    }

    // No more questions - form is complete
    setState(() {
      _currentQuestionIndex++;
    });
  }

  void _goBack() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        if (_questionPath.length > _currentQuestionIndex + 1) {
          _questionPath.removeRange(_currentQuestionIndex + 1, _questionPath.length);
        }
      });
    }
  }

  void _restart() {
    setState(() {
      _responses.clear();
      _currentQuestionIndex = 0;
      _buildQuestionPath();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildPreviewHeader(),
                Expanded(
                  child: _currentQuestionIndex < _questionPath.length
                      ? _buildQuestionView()
                      : _buildCompletionView(),
                ),
                _buildPreviewFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.preview,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Form Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _restart,
                tooltip: 'Restart',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.form.formName,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          if (_questionPath.isNotEmpty) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _currentQuestionIndex / _questionPath.length,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Question ${_currentQuestionIndex + 1} of ${_questionPath.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    final question = _questionPath[_currentQuestionIndex];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.questionText.isEmpty
                      ? 'Question text not set'
                      : question.questionText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: question.questionText.isEmpty
                        ? Colors.grey[400]
                        : Colors.black87,
                  ),
                ),
              ),
              if (question.required)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuestionInput(question),
        ],
      ),
    );
  }

  Widget _buildQuestionInput(FormQuestion question) {
    switch (question.questionType) {
      case QuestionType.text:
      case QuestionType.email:
      case QuestionType.phone:
        return TextField(
          decoration: InputDecoration(
            hintText: question.placeholder ?? 'Enter your answer...',
            border: const OutlineInputBorder(),
          ),
          keyboardType: question.questionType == QuestionType.email
              ? TextInputType.emailAddress
              : question.questionType == QuestionType.phone
                  ? TextInputType.phone
                  : TextInputType.text,
          onSubmitted: (value) => _handleAnswer(value),
        );

      case QuestionType.singleChoice:
        return Column(
          children: question.options.map((option) {
            final isSelected = _responses[question.questionId] == option.optionId;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _handleAnswer(option.optionId),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.optionText.isEmpty
                              ? 'Option ${option.orderIndex + 1}'
                              : option.optionText,
                          style: TextStyle(
                            fontSize: 16,
                            color: option.optionText.isEmpty
                                ? Colors.grey[400]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.multipleChoice:
        return Column(
          children: question.options.map((option) {
            final selectedOptions = _responses[question.questionId] as List? ?? [];
            final isSelected = selectedOptions.contains(option.optionId);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  final currentSelections = List.from(selectedOptions);
                  if (isSelected) {
                    currentSelections.remove(option.optionId);
                  } else {
                    currentSelections.add(option.optionId);
                  }
                  setState(() {
                    _responses[question.questionId] = currentSelections;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.optionText.isEmpty
                              ? 'Option ${option.orderIndex + 1}'
                              : option.optionText,
                          style: TextStyle(
                            fontSize: 16,
                            color: option.optionText.isEmpty
                                ? Colors.grey[400]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
    }
  }

  Widget _buildCompletionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Form Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You answered ${_responses.length} questions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Start Over'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            OutlinedButton.icon(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          const Spacer(),
          Text(
            'This is a preview - no data will be saved',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

