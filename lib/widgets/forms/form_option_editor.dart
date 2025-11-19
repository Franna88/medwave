import 'package:flutter/material.dart';
import '../../models/form/form_question.dart';
import '../../models/form/form_option.dart';
import '../../theme/app_theme.dart';
import 'package:uuid/uuid.dart';

class FormOptionEditor extends StatefulWidget {
  final FormQuestion question;
  final Function(List<FormOption>) onUpdateOptions;
  final Function(String, String) onAddColumn;

  const FormOptionEditor({
    super.key,
    required this.question,
    required this.onUpdateOptions,
    required this.onAddColumn,
  });

  @override
  State<FormOptionEditor> createState() => _FormOptionEditorState();
}

class _FormOptionEditorState extends State<FormOptionEditor> {
  final Uuid _uuid = const Uuid();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final option in widget.question.options) {
      _controllers[option.optionId] = TextEditingController(text: option.optionText);
    }
  }

  void _addOption() {
    final newOption = FormOption(
      optionId: _uuid.v4(),
      optionText: '',
      orderIndex: widget.question.options.length,
    );

    _controllers[newOption.optionId] = TextEditingController();
    widget.onUpdateOptions([...widget.question.options, newOption]);
  }

  void _updateOptionText(String optionId, String text) {
    final updatedOptions = widget.question.options.map((option) {
      return option.optionId == optionId
          ? option.copyWith(optionText: text)
          : option;
    }).toList();

    widget.onUpdateOptions(updatedOptions);
  }

  void _deleteOption(String optionId) {
    final updatedOptions = widget.question.options
        .where((option) => option.optionId != optionId)
        .toList();

    // Update order indices
    for (int i = 0; i < updatedOptions.length; i++) {
      updatedOptions[i] = updatedOptions[i].copyWith(orderIndex: i);
    }

    _controllers[optionId]?.dispose();
    _controllers.remove(optionId);

    widget.onUpdateOptions(updatedOptions);
  }

  void _createBranch(FormOption option) {
    // Create a new column that branches from this option
    widget.onAddColumn(widget.question.questionId, option.optionId);

    // Update the option to mark that it leads to a column
    // Note: The column ID will be set by the parent when the column is created
    // For now, we just trigger the column creation
  }

  void _reorderOptions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final options = List<FormOption>.from(widget.question.options);
    final option = options.removeAt(oldIndex);
    options.insert(newIndex, option);

    // Update order indices
    for (int i = 0; i < options.length; i++) {
      options[i] = options[i].copyWith(orderIndex: i);
    }

    widget.onUpdateOptions(options);
  }

  @override
  Widget build(BuildContext context) {
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
                color: Colors.grey[700],
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
        const SizedBox(height: 8),
        if (widget.question.options.isEmpty)
          _buildEmptyState()
        else
          _buildOptionsList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.list, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No options yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add answer options for users to choose from',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.question.options.length,
      onReorder: _reorderOptions,
      itemBuilder: (context, index) {
        final option = widget.question.options[index];
        return _buildOptionItem(option, index);
      },
    );
  }

  Widget _buildOptionItem(FormOption option, int index) {
    final controller = _controllers[option.optionId];
    final hasBranch = option.leadsToColumnId != null;

    return Container(
      key: ValueKey(option.optionId),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasBranch
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
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
                if (widget.question.branchingEnabled && !hasBranch)
                  IconButton(
                    icon: Icon(
                      Icons.call_split,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () => _createBranch(option),
                    tooltip: 'Create branch',
                  ),
                if (hasBranch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Branched',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteOption(option.optionId),
                  color: Colors.red,
                  tooltip: 'Delete option',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

