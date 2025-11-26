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
  dynamic _currentAnswer; // Stores the pending answer before navigating
  TextEditingController? _textController;

  @override
  void initState() {
    super.initState();
    _buildQuestionPath();
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  bool get _hasAnswer {
    if (_currentQuestionIndex >= _questionPath.length) return false;
    final question = _questionPath[_currentQuestionIndex];
    
    // Check if there's a current answer being entered
    if (_currentAnswer != null) {
      if (_currentAnswer is String && (_currentAnswer as String).isNotEmpty) {
        return true;
      }
      if (_currentAnswer is List && (_currentAnswer as List).isNotEmpty) {
        return true;
      }
    }
    
    // Check if this question was already answered
    return _responses.containsKey(question.questionId);
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

    setState(() {
      _currentAnswer = answer;
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex >= _questionPath.length) return;
    if (_currentAnswer == null) return;

    final currentQuestion = _questionPath[_currentQuestionIndex];
    setState(() {
      _responses[currentQuestion.questionId] = _currentAnswer;
    });

    // Determine next question
    _navigateToNextQuestion(currentQuestion, _currentAnswer);
    
    // Clear current answer and text controller for next question
    _textController?.dispose();
    _textController = null;
    setState(() {
      _currentAnswer = null;
    });
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

    // This is the last question in the column, check for follow-up columns
    FormColumn? nextColumn;
    
    // If this is a choice type question, check for answer-specific follow-ups first
    if (currentQuestion.isChoiceType) {
      String? selectedOptionId;
      if (answer is String) {
        selectedOptionId = answer;
      } else if (answer is List && answer.isNotEmpty) {
        selectedOptionId = answer.first;
      }

      if (selectedOptionId != null) {
        // First check if there's a column specifically for this answer
        try {
          final answerSpecificColumn = widget.form.columns.firstWhere(
            (col) => col.parentAnswerId == selectedOptionId,
          );
          nextColumn = answerSpecificColumn;
        } catch (_) {
          // No answer-specific column found
        }
      }
    }
    
    // If no answer-specific column, check for a general follow-up column for this question
    if (nextColumn == null) {
      try {
        nextColumn = widget.form.columns.firstWhere(
          (col) => col.parentQuestionId == currentQuestion.questionId && col.parentAnswerId == null,
        );
      } catch (_) {
        // No follow-up column found
      }
    }

    // If we found a follow-up column, navigate to it
    if (nextColumn != null && nextColumn.questions.isNotEmpty) {
      setState(() {
        _currentQuestionIndex++;
        _questionPath.add(nextColumn!.questions.first);
      });
      return;
    }

    // No more questions - form is complete
    setState(() {
      _currentQuestionIndex++;
    });
  }

  void _goBack() {
    if (_currentQuestionIndex > 0) {
      _textController?.dispose();
      _textController = null;
      setState(() {
        _currentQuestionIndex--;
        _currentAnswer = null;
        if (_questionPath.length > _currentQuestionIndex + 1) {
          _questionPath.removeRange(_currentQuestionIndex + 1, _questionPath.length);
        }
        // Load the previous answer if it exists
        if (_currentQuestionIndex < _questionPath.length) {
          final previousQuestion = _questionPath[_currentQuestionIndex];
          _currentAnswer = _responses[previousQuestion.questionId];
        }
      });
    }
  }

  void _restart() {
    _textController?.dispose();
    _textController = null;
    setState(() {
      _responses.clear();
      _currentQuestionIndex = 0;
      _currentAnswer = null;
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
          if (_questionPath.isNotEmpty && _currentQuestionIndex < _questionPath.length) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / (_questionPath.length + 1),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Question ${_currentQuestionIndex + 1}',
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
    
    // Initialize text controller for text input questions
    if (question.questionType == QuestionType.text ||
        question.questionType == QuestionType.email ||
        question.questionType == QuestionType.phone) {
      if (_textController == null) {
        _textController = TextEditingController(
          text: _currentAnswer is String ? _currentAnswer as String : '',
        );
      }
    } else {
      // Dispose text controller if not a text input question
      _textController?.dispose();
      _textController = null;
    }
    
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: question.placeholder ?? 'Enter your answer...',
                border: const OutlineInputBorder(),
              ),
              keyboardType: question.questionType == QuestionType.email
                  ? TextInputType.emailAddress
                  : question.questionType == QuestionType.phone
                      ? TextInputType.phone
                      : TextInputType.text,
              onChanged: (value) => _handleAnswer(value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _hasAnswer ? _goToNextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

      case QuestionType.singleChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...question.options.map((option) {
              final isSelected = _currentAnswer == option.optionId;
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _hasAnswer ? _goToNextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

      case QuestionType.multipleChoice:
        final currentSelections = _currentAnswer as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...question.options.map((option) {
              final isSelected = currentSelections.contains(option.optionId);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    final updatedSelections = List.from(currentSelections);
                    if (isSelected) {
                      updatedSelections.remove(option.optionId);
                    } else {
                      updatedSelections.add(option.optionId);
                    }
                    _handleAnswer(updatedSelections);
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _hasAnswer ? _goToNextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
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

