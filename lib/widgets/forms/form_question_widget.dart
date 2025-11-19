import 'package:flutter/material.dart';
import '../../models/form/form_question.dart';
import '../../models/form/form_option.dart';
import '../../theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class FormQuestionWidget extends StatefulWidget {
  final FormQuestion question;
  final Function(FormQuestion) onUpdate;
  final Function(String) onDelete;
  final Function(String) onAddColumn;
  final VoidCallback onSelect;
  final Function(String)? onSelectQuestion; // New callback for selecting options
  final bool isSelected;
  final String? selectedItemId; // ID of selected question or option
  final bool hasFollowUpColumn;
  final String columnId;
  final List<dynamic> allColumns;

  const FormQuestionWidget({
    super.key,
    required this.question,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddColumn,
    required this.onSelect,
    this.onSelectQuestion,
    required this.isSelected,
    this.selectedItemId,
    required this.hasFollowUpColumn,
    required this.columnId,
    required this.allColumns,
  });

  @override
  State<FormQuestionWidget> createState() => _FormQuestionWidgetState();
}

class _FormQuestionWidgetState extends State<FormQuestionWidget> {
  late TextEditingController _questionController;
  late TextEditingController _placeholderController;
  bool _isExpanded = false;
  final Uuid _uuid = const Uuid();
  final Map<String, TextEditingController> _optionControllers = {};

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question.questionText);
    _placeholderController = TextEditingController(text: widget.question.placeholder ?? '');
  }

  @override
  void dispose() {
    _questionController.dispose();
    _placeholderController.dispose();
    for (final controller in _optionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initializeOptionControllers() {
    for (final option in widget.question.options) {
      if (!_optionControllers.containsKey(option.optionId)) {
        _optionControllers[option.optionId] = TextEditingController(text: option.optionText);
      }
    }
  }

  void _updateQuestionText(String text) {
    widget.onUpdate(widget.question.copyWith(questionText: text));
  }

  void _updateQuestionType(QuestionType type) {
    widget.onUpdate(widget.question.copyWith(
      questionType: type,
      options: type == QuestionType.singleChoice || type == QuestionType.multipleChoice
          ? widget.question.options
          : [],
    ));
  }

  void _toggleRequired() {
    widget.onUpdate(widget.question.copyWith(required: !widget.question.required));
  }
  
  void _toggleFinalQuestion() {
    widget.onUpdate(widget.question.copyWith(isFinalQuestion: !widget.question.isFinalQuestion));
  }

  void _updatePlaceholder(String text) {
    widget.onUpdate(widget.question.copyWith(placeholder: text));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      // Compact card view
      return InkWell(
        onTap: () => widget.onSelect(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected 
                  ? AppTheme.primaryColor
                  : Colors.grey[300]!,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question.questionText.isEmpty
                          ? 'New Question'
                          : widget.question.questionText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.question.questionText.isEmpty
                            ? Colors.grey[400]
                            : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                    onPressed: () => setState(() => _isExpanded = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                    onPressed: () => widget.onDelete(widget.question.questionId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(
                    widget.question.questionType.displayName,
                    Colors.grey[100]!,
                    Colors.grey[700]!,
                  ),
                  if (widget.question.required)
                    _buildBadge('Required', Colors.red.withOpacity(0.1), Colors.red),
                  if (widget.question.isFinalQuestion)
                    _buildBadgeWithIcon(
                      'Final Question',
                      Colors.orange.withOpacity(0.1),
                      Colors.orange,
                      Icons.flag,
                    ),
                  if (widget.isSelected)
                    _buildBadge('Selected', AppTheme.primaryColor, Colors.white),
                  if (widget.hasFollowUpColumn)
                    _buildBadge('Has Follow-ups', Colors.green.withOpacity(0.1), Colors.green),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    // Expanded edit view
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildExpandedHeader(),
          Flexible(
            child: SingleChildScrollView(
              child: _buildQuestionContent(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
  
  Widget _buildBadgeWithIcon(String text, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Edit Question',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _isExpanded = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }


  Widget _buildQuestionContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Question Text',
              hintText: 'Enter your question...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: _updateQuestionText,
          ),
          const SizedBox(height: 16),

          // Question type
          DropdownButtonFormField<QuestionType>(
            value: widget.question.questionType,
            decoration: const InputDecoration(
              labelText: 'Question Type',
              border: OutlineInputBorder(),
            ),
            items: QuestionType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: (type) {
              if (type != null) _updateQuestionType(type);
            },
          ),
          const SizedBox(height: 16),

          // Placeholder (for text-based questions)
          if (!widget.question.isChoiceType) ...[
            TextField(
              controller: _placeholderController,
              decoration: const InputDecoration(
                labelText: 'Placeholder Text (Optional)',
                hintText: 'e.g., Enter your answer...',
                border: OutlineInputBorder(),
              ),
              onChanged: _updatePlaceholder,
            ),
            const SizedBox(height: 16),
          ],

          // Answer Options (for choice questions)
          if (widget.question.isChoiceType) ...[
            _buildAnswerOptions(),
            const SizedBox(height: 16),
          ],
          
          // Settings
          CheckboxListTile(
            title: const Text('Required'),
            subtitle: const Text('User must answer this question'),
            value: widget.question.required,
            onChanged: (_) => _toggleRequired(),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          
          CheckboxListTile(
            title: Row(
              children: [
                const Text('Final Question'),
                const SizedBox(width: 8),
                Icon(
                  Icons.flag,
                  size: 18,
                  color: widget.question.isFinalQuestion ? Colors.orange : Colors.grey,
                ),
              ],
            ),
            subtitle: const Text('Mark this as the last question in this path'),
            value: widget.question.isFinalQuestion,
            onChanged: (_) => _toggleFinalQuestion(),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          
          const SizedBox(height: 16),
          
          // General follow-up section (for all question types)
          if (!widget.question.isFinalQuestion) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_forward, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'General Follow-up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.question.isChoiceType
                        ? 'Add questions that appear after ANY answer is selected'
                        : 'Add questions that appear after this question',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!widget.hasFollowUpColumn)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onSelect(); // Select this question first
                          widget.onAddColumn(widget.question.questionId); // Then add the column
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add General Follow-up Questions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => widget.onSelect(), // Make it clickable to show the follow-up column
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'General follow-up questions exist - Click to view',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward, color: Colors.green[700], size: 14),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAnswerOptions() {
    _initializeOptionControllers();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Answer Options',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Option'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.question.options.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                'No options yet. Add answer options for users to choose from.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...widget.question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return _buildOptionItem(option, index);
          }).toList(),
      ],
    );
  }
  
  Widget _buildOptionItem(FormOption option, int index) {
    final controller = _optionControllers[option.optionId];
    
    // Check if this option has a follow-up column
    final hasFollowUp = widget.allColumns.any(
      (col) => col.parentAnswerId == option.optionId,
    );
    
    // Check if this option is currently selected
    final isSelected = widget.selectedItemId == option.optionId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Option ${index + 1}',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (text) => _updateOptionText(option.optionId, text),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                onPressed: () => _deleteOption(option.optionId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete option',
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Final Answer checkbox
          CheckboxListTile(
            title: Row(
              children: [
                const Text('Final Answer', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Icon(
                  Icons.stop_circle,
                  size: 14,
                  color: option.isFinalAnswer ? Colors.red : Colors.grey,
                ),
              ],
            ),
            subtitle: const Text(
              'End form when this option is selected',
              style: TextStyle(fontSize: 10),
            ),
            value: option.isFinalAnswer,
            onChanged: (value) => _toggleOptionFinalAnswer(option.optionId),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          const SizedBox(height: 8),
          
          // Add follow-up button for this specific option (only if not final answer)
          if (!option.isFinalAnswer) ...[
            if (!hasFollowUp)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onAddColumn(option.optionId); // Add the column
                  },
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Add Follow-up Questions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              )
            else
              InkWell(
                onTap: () {
                  // Select this option to show its follow-up column
                  widget.onSelectQuestion?.call(option.optionId);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Has follow-up questions - Click to view',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: Colors.green[700], size: 14),
                    ],
                  ),
                ),
              ),
          ] else
            // Show final answer indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_circle, color: Colors.red[700], size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Form ends here when this option is selected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  void _addOption() {
    final newOption = FormOption(
      optionId: _uuid.v4(),
      optionText: '',
      orderIndex: widget.question.options.length,
    );
    
    _optionControllers[newOption.optionId] = TextEditingController();
    
    final updatedOptions = [...widget.question.options, newOption];
    widget.onUpdate(widget.question.copyWith(options: updatedOptions));
  }
  
  void _updateOptionText(String optionId, String text) {
    final updatedOptions = widget.question.options.map((option) {
      return option.optionId == optionId
          ? option.copyWith(optionText: text)
          : option;
    }).toList();
    
    widget.onUpdate(widget.question.copyWith(options: updatedOptions));
  }
  
  void _deleteOption(String optionId) {
    final updatedOptions = widget.question.options
        .where((option) => option.optionId != optionId)
        .toList();
    
    // Update order indices
    for (int i = 0; i < updatedOptions.length; i++) {
      updatedOptions[i] = updatedOptions[i].copyWith(orderIndex: i);
    }
    
    _optionControllers[optionId]?.dispose();
    _optionControllers.remove(optionId);
    
    widget.onUpdate(widget.question.copyWith(options: updatedOptions));
  }
  
  void _toggleOptionFinalAnswer(String optionId) {
    final updatedOptions = widget.question.options.map((option) {
      return option.optionId == optionId
          ? option.copyWith(isFinalAnswer: !option.isFinalAnswer)
          : option;
    }).toList();
    
    widget.onUpdate(widget.question.copyWith(options: updatedOptions));
  }
}

