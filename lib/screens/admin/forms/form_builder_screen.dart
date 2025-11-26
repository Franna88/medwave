import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../models/form/lead_form.dart';
import '../../../models/form/form_column.dart';
import '../../../models/form/form_question.dart';
import '../../../services/firebase/form_service.dart';
import '../../../widgets/forms/form_column_widget.dart';
import '../../../widgets/forms/form_preview_widget.dart';
import 'package:uuid/uuid.dart';

class FormBuilderScreen extends StatefulWidget {
  final String formId;

  const FormBuilderScreen({super.key, required this.formId});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final FormService _formService = FormService();
  final TextEditingController _formNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  LeadForm? _form;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showPreview = false;

  // Track selected questions/options to determine which columns to show
  final List<String> _selectedPath = []; // Can be questionId or optionId

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _formNameController.dispose();
    _descriptionController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);
    try {
      final form = await _formService.getForm(widget.formId);
      if (form != null) {
        setState(() {
          _form = form;
          _formNameController.text = form.formName;
          _descriptionController.text = form.description ?? '';
          _isLoading = false;
        });

        // If form has no columns, create the first one with required fields
        if (_form!.columns.isEmpty) {
          _addFirstColumn();
          // Auto-save to persist the required fields
          _saveFormSilently();
        } else {
          // Ensure required fields exist in the first column
          final hadMissingFields = _ensureRequiredFields();
          // Auto-save if we added missing fields
          if (hadMissingFields) {
            _saveFormSilently();
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Form not found')));
          context.pop();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading form: $e')));
      }
    }
  }

  void _addFirstColumn() {
    if (_form == null) return;

    // Create required fields for the first column
    final requiredQuestions = [
      FormQuestion(
        questionId: 'firstName',
        questionText: 'First Name',
        questionType: QuestionType.text,
        required: true,
        placeholder: 'Enter your first name',
        orderIndex: 0,
      ),
      FormQuestion(
        questionId: 'lastName',
        questionText: 'Last Name',
        questionType: QuestionType.text,
        required: true,
        placeholder: 'Enter your last name',
        orderIndex: 1,
      ),
      FormQuestion(
        questionId: 'email',
        questionText: 'Email',
        questionType: QuestionType.email,
        required: true,
        placeholder: 'Enter your email address',
        orderIndex: 2,
      ),
      FormQuestion(
        questionId: 'phone',
        questionText: 'Phone Number',
        questionType: QuestionType.phone,
        required: true,
        placeholder: 'Enter your phone number',
        orderIndex: 3,
      ),
    ];

    final newColumn = FormColumn(
      columnId: _uuid.v4(),
      columnIndex: 0,
      parentQuestionId: null,
      parentAnswerId: null,
      questions: requiredQuestions,
    );

    setState(() {
      _form = _form!.copyWith(columns: [newColumn]);
    });
  }

  bool _ensureRequiredFields() {
    if (_form == null || _form!.columns.isEmpty) return false;

    final firstColumn = _form!.columns.firstWhere(
      (col) => col.isFirstColumn,
      orElse: () => _form!.columns.first,
    );

    final requiredFieldIds = {'firstName', 'lastName', 'email', 'phone'};
    final existingQuestionIds = firstColumn.questions
        .map((q) => q.questionId)
        .toSet();

    final missingFields = <FormQuestion>[];
    int maxOrderIndex = firstColumn.questions.isEmpty
        ? -1
        : firstColumn.questions
              .map((q) => q.orderIndex)
              .reduce((a, b) => a > b ? a : b);

    // Add missing required fields
    if (!existingQuestionIds.contains('firstName')) {
      missingFields.add(
        FormQuestion(
          questionId: 'firstName',
          questionText: 'First Name',
          questionType: QuestionType.text,
          required: true,
          placeholder: 'Enter your first name',
          orderIndex: ++maxOrderIndex,
        ),
      );
    }
    if (!existingQuestionIds.contains('lastName')) {
      missingFields.add(
        FormQuestion(
          questionId: 'lastName',
          questionText: 'Last Name',
          questionType: QuestionType.text,
          required: true,
          placeholder: 'Enter your last name',
          orderIndex: ++maxOrderIndex,
        ),
      );
    }
    if (!existingQuestionIds.contains('email')) {
      missingFields.add(
        FormQuestion(
          questionId: 'email',
          questionText: 'Email',
          questionType: QuestionType.email,
          required: true,
          placeholder: 'Enter your email address',
          orderIndex: ++maxOrderIndex,
        ),
      );
    }
    if (!existingQuestionIds.contains('phone')) {
      missingFields.add(
        FormQuestion(
          questionId: 'phone',
          questionText: 'Phone Number',
          questionType: QuestionType.phone,
          required: true,
          placeholder: 'Enter your phone number',
          orderIndex: ++maxOrderIndex,
        ),
      );
    }

    // Ensure existing required fields are marked as required
    final updatedQuestions = firstColumn.questions.map((q) {
      if (requiredFieldIds.contains(q.questionId) && !q.required) {
        return q.copyWith(required: true);
      }
      return q;
    }).toList();

    if (missingFields.isNotEmpty ||
        updatedQuestions.length != firstColumn.questions.length) {
      setState(() {
        _form = _form!.copyWith(
          columns: _form!.columns.map((col) {
            if (col.columnId == firstColumn.columnId) {
              return col.copyWith(
                questions: [...updatedQuestions, ...missingFields]
                  ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
              );
            }
            return col;
          }).toList(),
        );
      });
      return true; // Indicates fields were added/updated
    }
    return false; // No changes made
  }

  Future<void> _saveFormSilently() async {
    if (_form == null) return;

    try {
      final updatedForm = _form!.copyWith(
        formName: _formNameController.text,
        description: _descriptionController.text,
        updatedAt: DateTime.now(),
      );
      await _formService.updateForm(updatedForm);
      setState(() {
        _form = updatedForm;
      });
    } catch (e) {
      // Silently fail - user can save manually if needed
      if (kDebugMode) {
        print('Error auto-saving form: $e');
      }
    }
  }

  void _addColumn(String parentId) {
    if (_form == null) return;

    // Determine if parentId is a question or an option
    bool isOption = false;
    String? parentQuestionId;
    String? parentAnswerId;

    // Check all questions and their options
    for (final col in _form!.columns) {
      for (final question in col.questions) {
        if (question.questionId == parentId) {
          // It's a question
          parentQuestionId = parentId;
          break;
        }

        // Check options
        for (final option in question.options) {
          if (option.optionId == parentId) {
            // It's an option
            isOption = true;
            parentAnswerId = parentId;
            parentQuestionId =
                question.questionId; // Store the parent question too
            break;
          }
        }
        if (isOption) break;
      }
      if (parentQuestionId != null) break;
    }

    // Check if a column for this parent already exists
    final existingColumn = _form!.columns.firstWhere(
      (col) => isOption
          ? col.parentAnswerId == parentAnswerId
          : col.parentQuestionId == parentQuestionId &&
                col.parentAnswerId == null,
      orElse: () => FormColumn(columnId: '', columnIndex: -1),
    );

    if (existingColumn.columnIndex != -1) {
      // Column already exists, just select it
      return;
    }

    final newColumn = FormColumn(
      columnId: _uuid.v4(),
      columnIndex: _form!.columns.length,
      parentQuestionId: parentQuestionId,
      parentAnswerId: parentAnswerId,
      questions: [],
    );

    setState(() {
      _form = _form!.copyWith(columns: [..._form!.columns, newColumn]);
    });

    // Scroll to the new column
    Future.delayed(const Duration(milliseconds: 100), () {
      _horizontalScrollController.animateTo(
        _horizontalScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectItem(String itemId, int columnIndex) {
    // itemId can be either a questionId or optionId
    setState(() {
      // Truncate the path to the current column
      if (_selectedPath.length > columnIndex) {
        _selectedPath.removeRange(columnIndex, _selectedPath.length);
      }
      // Add the selected item
      if (_selectedPath.length == columnIndex) {
        _selectedPath.add(itemId);
      } else {
        _selectedPath.add(itemId);
      }
    });
  }

  List<FormColumn> _getVisibleColumns() {
    if (_form == null || _form!.columns.isEmpty) return [];

    final visibleColumns = <FormColumn>[];

    // Always show the first column
    final firstColumn = _form!.columns.firstWhere(
      (col) => col.isFirstColumn,
      orElse: () => _form!.columns.first,
    );
    visibleColumns.add(firstColumn);

    // Show subsequent columns based on selected path (questions or options)
    for (int i = 0; i < _selectedPath.length; i++) {
      final selectedId = _selectedPath[i];

      // Find the column that has this item as parent (could be question or option)
      final nextColumn = _form!.columns.firstWhere(
        (col) =>
            col.parentQuestionId == selectedId ||
            col.parentAnswerId == selectedId,
        orElse: () => FormColumn(columnId: '', columnIndex: -1),
      );

      if (nextColumn.columnIndex != -1) {
        visibleColumns.add(nextColumn);
      } else {
        // No column exists yet, stop here
        break;
      }
    }

    return visibleColumns;
  }

  void _deleteColumn(String columnId) {
    if (_form == null) return;

    // Don't allow deleting the first column
    final column = _form!.columns.firstWhere((col) => col.columnId == columnId);
    if (column.isFirstColumn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the first column')),
      );
      return;
    }

    // Remove the column and any columns that depend on it
    final columnsToRemove = <String>{columnId};
    _findDependentColumns(columnId, columnsToRemove);

    setState(() {
      _form = _form!.copyWith(
        columns: _form!.columns
            .where((col) => !columnsToRemove.contains(col.columnId))
            .toList(),
      );
    });

    // Also remove references from options
    _cleanupOrphanedReferences();
  }

  void _findDependentColumns(String columnId, Set<String> columnsToRemove) {
    // Find all questions in this column
    final column = _form!.columns.firstWhere((col) => col.columnId == columnId);
    final questionIds = column.questions.map((q) => q.questionId).toSet();

    // Find all columns that depend on questions in this column
    for (final col in _form!.columns) {
      if (questionIds.contains(col.parentQuestionId) &&
          !columnsToRemove.contains(col.columnId)) {
        columnsToRemove.add(col.columnId);
        _findDependentColumns(col.columnId, columnsToRemove);
      }
    }
  }

  void _cleanupOrphanedReferences() {
    if (_form == null) return;

    final validColumnIds = _form!.columns.map((col) => col.columnId).toSet();
    final updatedColumns = <FormColumn>[];

    for (final column in _form!.columns) {
      final updatedQuestions = <FormQuestion>[];
      for (final question in column.questions) {
        final updatedOptions = question.options.map((option) {
          if (option.leadsToColumnId != null &&
              !validColumnIds.contains(option.leadsToColumnId)) {
            return option.copyWith(leadsToColumnId: null);
          }
          return option;
        }).toList();

        updatedQuestions.add(question.copyWith(options: updatedOptions));
      }
      updatedColumns.add(column.copyWith(questions: updatedQuestions));
    }

    setState(() {
      _form = _form!.copyWith(columns: updatedColumns);
    });
  }

  void _updateColumn(FormColumn updatedColumn) {
    if (_form == null) return;

    setState(() {
      _form = _form!.copyWith(
        columns: _form!.columns.map((col) {
          return col.columnId == updatedColumn.columnId ? updatedColumn : col;
        }).toList(),
      );
    });
  }

  Future<void> _saveForm() async {
    if (_form == null) return;

    // No validation for saving - allow saving drafts at any time

    setState(() => _isSaving = true);
    try {
      final updatedForm = _form!.copyWith(
        formName: _formNameController.text,
        description: _descriptionController.text,
        updatedAt: DateTime.now(),
      );

      await _formService.updateForm(updatedForm);
      setState(() {
        _form = updatedForm;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form saved as draft successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving form: $e')));
      }
    }
  }

  String _getFormUrl() {
    if (kIsWeb) {
      final baseUrl = Uri.base.origin;
      return '$baseUrl/fb-form/${widget.formId}';
    }
    // For mobile, use a configurable base URL or default
    return 'https://yourdomain.com/fb-form/${widget.formId}';
  }

  Future<void> _copyFormUrl() async {
    final url = _getFormUrl();

    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Form URL copied to clipboard!'),
                    Text(
                      url,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _publishForm() async {
    if (_form == null) return;

    // Validate form
    if (!_formService.validateForm(_form!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please ensure all columns have questions and all questions have text',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedForm = _form!.copyWith(
        formName: _formNameController.text,
        description: _descriptionController.text,
        status: FormStatus.active,
        updatedAt: DateTime.now(),
      );

      await _formService.updateForm(updatedForm);
      setState(() {
        _form = updatedForm;
        _isSaving = false;
      });

      if (mounted) {
        // Show success dialog with URL
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Form Published!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your form is now live and ready to use.'),
                const SizedBox(height: 16),
                const Text(
                  'Form URL:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _getFormUrl(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          _copyFormUrl();
                          Navigator.of(context).pop();
                        },
                        tooltip: 'Copy URL',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add UTM parameters for Facebook ads:\n'
                  '?utm_source=facebook&utm_medium=cpc&...',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _copyFormUrl();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy URL'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error publishing form: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_form == null) {
      return const Scaffold(body: Center(child: Text('Form not found')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          if (_showPreview)
            Expanded(child: FormPreviewWidget(form: _form!))
          else
            Expanded(child: _buildFormBuilder()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _formNameController,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Form Name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    TextField(
                      controller: _descriptionController,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      decoration: InputDecoration(
                        hintText: 'Add a description...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showPreview = !_showPreview),
                icon: Icon(_showPreview ? Icons.edit : Icons.preview),
                label: Text(_showPreview ? 'Edit' : 'Preview'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isSaving ? null : _saveForm,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _publishForm,
                icon: const Icon(Icons.publish),
                label: const Text('Publish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormBuilder() {
    final visibleColumns = _getVisibleColumns();

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < visibleColumns.length; i++) ...[
              FormColumnWidget(
                column: visibleColumns[i],
                onUpdate: _updateColumn,
                onDelete: _deleteColumn,
                onAddColumn: _addColumn,
                onSelectQuestion: (itemId) => _selectItem(itemId, i),
                selectedQuestionId: i < _selectedPath.length
                    ? _selectedPath[i]
                    : null,
                allColumns: _form!.columns,
              ),
              if (i < visibleColumns.length - 1) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }
}
