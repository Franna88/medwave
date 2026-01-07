import 'package:flutter/material.dart';
import '../../config/sales_questionnaire.dart';
import '../../theme/app_theme.dart';
import 'stage_transition_dialog.dart';

/// Dialog for collecting structured sales questionnaire when moving to Contacted stage
class ContactedQuestionnaireDialog extends StatefulWidget {
  final String fromStage;
  final String toStage;

  const ContactedQuestionnaireDialog({
    super.key,
    required this.fromStage,
    required this.toStage,
  });

  @override
  State<ContactedQuestionnaireDialog> createState() =>
      _ContactedQuestionnaireDialogState();
}

class _ContactedQuestionnaireDialogState
    extends State<ContactedQuestionnaireDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _questions = [];
  final List<String> _customQuestions = [];
  
  // Checklist state management
  final Map<String, bool> _checklistItems = {};
  final List<String> _checklistLabels = [];

  @override
  void initState() {
    super.initState();
    // Initialize with all questions (default + qualification)
    _questions.addAll(SalesQuestionnaireConfig.getAllQuestions());

    // Create controllers for each question
    for (var question in _questions) {
      _controllers[question] = TextEditingController();
    }

    // Initialize checklist items
    _checklistLabels.addAll(SalesQuestionnaireConfig.getRapportChecklistItems());
    for (var item in _checklistLabels) {
      _checklistItems[item] = false;
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCustomQuestion() {
    showDialog(
      context: context,
      builder: (context) {
        final questionController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Custom Question'),
          content: TextField(
            controller: questionController,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'e.g., Preferred contact time?',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final question = questionController.text.trim();
                if (question.isNotEmpty && !_questions.contains(question)) {
                  setState(() {
                    _questions.add(question);
                    _customQuestions.add(question);
                    _controllers[question] = TextEditingController();
                  });
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeCustomQuestion(String question) {
    setState(() {
      _questions.remove(question);
      _customQuestions.remove(question);
      _controllers[question]?.dispose();
      _controllers.remove(question);
    });
  }

  Widget _buildChecklistSection() {
    final checkedCount = _checklistItems.values.where((v) => v).length;
    final totalCount = _checklistItems.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and progress
          Row(
            children: [
              Icon(
                Icons.checklist_rtl,
                color: Colors.amber[700],
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Call Checklist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Optional - Track your sales process',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: checkedCount == totalCount 
                      ? Colors.green[100] 
                      : Colors.amber[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$checkedCount / $totalCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: checkedCount == totalCount 
                        ? Colors.green[700] 
                        : Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Checklist items
          ...(_checklistLabels.map((item) => _buildChecklistItem(item))),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label) {
    return InkWell(
      onTap: () {
        setState(() {
          _checklistItems[label] = !(_checklistItems[label] ?? false);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _checklistItems[label] ?? false,
                onChanged: (value) {
                  setState(() {
                    _checklistItems[label] = value ?? false;
                  });
                },
                activeColor: Colors.green[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: (_checklistItems[label] ?? false)
                      ? Colors.grey[600]
                      : Colors.black87,
                  decoration: (_checklistItems[label] ?? false)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.contact_phone,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sales Questionnaire',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stage transition visual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.fromStage,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.toStage,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sales Call Checklist Section
                      _buildChecklistSection(),
                      const SizedBox(height: 20),

                      // Instructions
                      Text(
                        'Please complete the following sales questionnaire:',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),

                      // Questionnaire fields
                      for (var i = 0; i < _questions.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _controllers[_questions[i]],
                                decoration: InputDecoration(
                                  labelText: _questions[i],
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  suffixIcon:
                                      _customQuestions.contains(_questions[i])
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _removeCustomQuestion(
                                                _questions[i],
                                              ),
                                          tooltip: 'Remove custom question',
                                        )
                                      : null,
                                ),
                                maxLines:
                                    _questions[i].contains('Pain Points') ||
                                        _questions[i].contains('Requirements') ||
                                        _questions[i].contains('challenges')
                                    ? 2
                                    : 1,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'This field is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Add custom question button
                      OutlinedButton.icon(
                        onPressed: _addCustomQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Question'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Collect all responses into a map
                        final Map<String, dynamic> responses = {};
                        for (var question in _questions) {
                          responses[question] = _controllers[question]!.text
                              .trim();
                        }

                        // Add checklist completion data
                        final completedChecklist = _checklistItems.entries
                            .where((e) => e.value)
                            .map((e) => e.key)
                            .toList();
                        responses['_checklist_completed'] = completedChecklist;
                        responses['_checklist_count'] = 
                            '${completedChecklist.length}/${_checklistItems.length}';

                        // Return as StageTransitionResult with map as note
                        final result = StageTransitionResult(note: responses);
                        Navigator.of(context).pop(result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Confirm Move'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
