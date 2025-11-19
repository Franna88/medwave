import 'package:flutter/material.dart';
import '../../models/form/form_column.dart';
import '../../models/form/form_question.dart';
import '../../theme/app_theme.dart';
import 'form_question_widget.dart';
import 'package:uuid/uuid.dart';

class FormColumnWidget extends StatefulWidget {
  final FormColumn column;
  final Function(FormColumn) onUpdate;
  final Function(String) onDelete;
  final Function(String) onAddColumn;
  final Function(String) onSelectQuestion;
  final String? selectedQuestionId;
  final List<FormColumn> allColumns;

  const FormColumnWidget({
    super.key,
    required this.column,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddColumn,
    required this.onSelectQuestion,
    required this.selectedQuestionId,
    required this.allColumns,
  });

  @override
  State<FormColumnWidget> createState() => _FormColumnWidgetState();
}

class _FormColumnWidgetState extends State<FormColumnWidget> {
  final Uuid _uuid = const Uuid();

  void _addQuestion() {
    final newQuestion = FormQuestion(
      questionId: _uuid.v4(),
      questionText: '',
      questionType: QuestionType.text,
      required: false,
      orderIndex: widget.column.questions.length,
    );

    final updatedColumn = widget.column.copyWith(
      questions: [...widget.column.questions, newQuestion],
    );

    widget.onUpdate(updatedColumn);
  }

  void _updateQuestion(FormQuestion updatedQuestion) {
    final updatedQuestions = widget.column.questions.map((q) {
      return q.questionId == updatedQuestion.questionId ? updatedQuestion : q;
    }).toList();

    widget.onUpdate(widget.column.copyWith(questions: updatedQuestions));
  }

  void _deleteQuestion(String questionId) {
    final updatedQuestions = widget.column.questions
        .where((q) => q.questionId != questionId)
        .toList();

    // Update order indices
    for (int i = 0; i < updatedQuestions.length; i++) {
      updatedQuestions[i] = updatedQuestions[i].copyWith(orderIndex: i);
    }

    widget.onUpdate(widget.column.copyWith(questions: updatedQuestions));
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: MediaQuery.of(context).size.height - 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: widget.column.questions.isEmpty
                ? _buildEmptyState()
                : _buildQuestionsList(),
          ),
          // Only show add question button if column is empty
          if (widget.column.questions.isEmpty)
            _buildAddQuestionButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String headerTitle = 'Starting Questions';
    
    if (!widget.column.isFirstColumn) {
      // Find parent option or question
      bool found = false;
      
      // Check if it's a follow-up to an option (parentAnswerId takes priority)
      if (widget.column.parentAnswerId != null) {
        for (final col in widget.allColumns) {
          for (final question in col.questions) {
            for (final option in question.options) {
              if (option.optionId == widget.column.parentAnswerId) {
                headerTitle = option.optionText.isEmpty 
                    ? 'Follow-up Questions' 
                    : option.optionText;
                found = true;
                break;
              }
            }
            if (found) break;
          }
          if (found) break;
        }
      }
      
      // If not found and no parentAnswerId, check if it's a follow-up to a question
      if (!found && widget.column.parentQuestionId != null) {
        for (final col in widget.allColumns) {
          for (final question in col.questions) {
            if (question.questionId == widget.column.parentQuestionId) {
              headerTitle = question.questionText.isEmpty 
                  ? 'Follow-up Questions' 
                  : question.questionText;
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!widget.column.isFirstColumn) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Follow-up questions',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.column.isFirstColumn)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => widget.onDelete(widget.column.columnId),
              tooltip: 'Delete column',
              color: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No question yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a question to this column',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    // Since we only allow one question per column, just display it
    final question = widget.column.questions.first;
    final isSelected = widget.selectedQuestionId == question.questionId;
    
    // Check if this question has a follow-up column
    final hasFollowUpColumn = widget.allColumns.any(
      (col) => col.parentQuestionId == question.questionId,
    );
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FormQuestionWidget(
        question: question,
        onUpdate: _updateQuestion,
        onDelete: _deleteQuestion,
        onAddColumn: widget.onAddColumn,
        onSelect: () => widget.onSelectQuestion(question.questionId),
        onSelectQuestion: widget.onSelectQuestion, // Pass through for option selection
        isSelected: isSelected,
        selectedItemId: widget.selectedQuestionId, // Pass the selected item ID
        hasFollowUpColumn: hasFollowUpColumn,
        columnId: widget.column.columnId,
        allColumns: widget.allColumns,
      ),
    );
  }

  Widget _buildAddQuestionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addQuestion,
          icon: const Icon(Icons.add),
          label: const Text('Add Question'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}


