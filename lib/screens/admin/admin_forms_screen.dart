import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/form/lead_form.dart';
import '../../services/firebase/form_service.dart';
import '../../services/firebase/form_submission_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminFormsScreen extends StatefulWidget {
  const AdminFormsScreen({super.key});

  @override
  State<AdminFormsScreen> createState() => _AdminFormsScreenState();
}

class _AdminFormsScreenState extends State<AdminFormsScreen> {
  final FormService _formService = FormService();
  final FormSubmissionService _submissionService = FormSubmissionService();
  final TextEditingController _searchController = TextEditingController();

  List<LeadForm> _forms = [];
  List<LeadForm> _filteredForms = [];
  bool _isLoading = true;
  FormStatus? _filterStatus;
  Map<String, int> _submissionCounts = {};

  @override
  void initState() {
    super.initState();
    _loadForms();
    _searchController.addListener(_filterForms);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadForms() async {
    setState(() => _isLoading = true);
    try {
      final forms = await _formService.getAllForms();

      // Load submission counts for each form
      final counts = <String, int>{};
      for (final form in forms) {
        final count = await _submissionService.getSubmissionCount(form.formId);
        counts[form.formId] = count;
      }

      setState(() {
        _forms = forms;
        _filteredForms = forms;
        _submissionCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading forms: $e')));
      }
    }
  }

  void _filterForms() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredForms = _forms.where((form) {
        final matchesSearch =
            form.formName.toLowerCase().contains(searchTerm) ||
            (form.description?.toLowerCase().contains(searchTerm) ?? false);
        final matchesStatus =
            _filterStatus == null || form.status == _filterStatus;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _setStatusFilter(FormStatus? status) {
    setState(() {
      _filterStatus = status;
      _filterForms();
    });
  }

  String _getFormUrl(String formId) {
    if (kIsWeb) {
      final baseUrl = Uri.base.origin;
      return '$baseUrl/fb-form/$formId';
    }
    // For mobile, use a configurable base URL or default
    // You might want to store this in a config file
    return 'https://yourdomain.com/fb-form/$formId';
  }

  Future<void> _copyFormUrl(LeadForm form) async {
    final url = _getFormUrl(form.formId);

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

  Future<void> _createNewForm() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';

    final newForm = LeadForm(
      formId: '',
      formName: 'New Form ${DateTime.now().millisecondsSinceEpoch}',
      description: '',
      status: FormStatus.draft,
      columns: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: userId,
    );

    try {
      final formId = await _formService.createForm(newForm);
      if (mounted) {
        context.push('/admin/forms/builder/$formId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating form: $e')));
      }
    }
  }

  Future<void> _duplicateForm(LeadForm form) async {
    final newName = '${form.formName} (Copy)';
    try {
      await _formService.duplicateForm(form.formId, newName);
      await _loadForms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form duplicated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error duplicating form: $e')));
      }
    }
  }

  Future<void> _deleteForm(LeadForm form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Form'),
        content: Text('Are you sure you want to delete "${form.formName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _formService.deleteForm(form.formId);
        await _loadForms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting form: $e')));
        }
      }
    }
  }

  Future<void> _toggleFormStatus(LeadForm form) async {
    final newStatus = form.status == FormStatus.active
        ? FormStatus.inactive
        : FormStatus.active;

    try {
      await _formService.updateFormStatus(form.formId, newStatus);
      await _loadForms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Form ${newStatus.displayName.toLowerCase()}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating form status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredForms.isEmpty
                ? _buildEmptyState()
                : _buildFormsList(),
          ),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forms',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create and manage Facebook lead forms',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _createNewForm,
            icon: const Icon(Icons.add),
            label: const Text('Create Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search forms...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildStatusFilter(),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return PopupMenuButton<FormStatus?>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              _filterStatus?.displayName ?? 'All Status',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All Status')),
        PopupMenuItem(
          value: FormStatus.active,
          child: Text(FormStatus.active.displayName),
        ),
        PopupMenuItem(
          value: FormStatus.inactive,
          child: Text(FormStatus.inactive.displayName),
        ),
        PopupMenuItem(
          value: FormStatus.draft,
          child: Text(FormStatus.draft.displayName),
        ),
      ],
      onSelected: _setStatusFilter,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty && _filterStatus == null
                ? 'No forms yet'
                : 'No forms found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty && _filterStatus == null
                ? 'Create your first form to get started'
                : 'Try adjusting your search or filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (_searchController.text.isEmpty && _filterStatus == null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewForm,
              icon: const Icon(Icons.add),
              label: const Text('Create Form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredForms.length,
      itemBuilder: (context, index) {
        final form = _filteredForms[index];
        return _buildFormCard(form);
      },
    );
  }

  Widget _buildFormCard(LeadForm form) {
    final submissionCount = _submissionCounts[form.formId] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/admin/forms/builder/${form.formId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          form.formName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (form.description != null &&
                            form.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            form.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusBadge(form.status),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (form.status == FormStatus.active)
                        const PopupMenuItem(
                          value: 'copyUrl',
                          child: Row(
                            children: [
                              Icon(Icons.link, size: 20),
                              SizedBox(width: 12),
                              Text('Copy Form URL'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 20),
                            SizedBox(width: 12),
                            Text('Duplicate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              form.status == FormStatus.active
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              form.status == FormStatus.active
                                  ? 'Deactivate'
                                  : 'Activate',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          context.push('/admin/forms/builder/${form.formId}');
                          break;
                        case 'copyUrl':
                          _copyFormUrl(form);
                          break;
                        case 'duplicate':
                          _duplicateForm(form);
                          break;
                        case 'toggle':
                          _toggleFormStatus(form);
                          break;
                        case 'delete':
                          _deleteForm(form);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.view_column,
                    '${form.columns.length} columns',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.help_outline,
                    '${form.columns.fold<int>(0, (sum, col) => sum + col.questions.length)} questions',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.inbox, '$submissionCount submissions'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_formatDate(form.updatedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              if (form.status == FormStatus.active) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFormUrl(form.formId),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () => _copyFormUrl(form),
                        tooltip: 'Copy URL',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.blue[700],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FormStatus status) {
    Color color;
    switch (status) {
      case FormStatus.active:
        color = Colors.green;
        break;
      case FormStatus.inactive:
        color = Colors.orange;
        break;
      case FormStatus.draft:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
