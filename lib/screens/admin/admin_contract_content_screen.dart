import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contract_content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/contract_editor_widget.dart';

/// Screen for managing contract content (Super Admin only)
class AdminContractContentScreen extends StatefulWidget {
  const AdminContractContentScreen({super.key});

  @override
  State<AdminContractContentScreen> createState() =>
      _AdminContractContentScreenState();
}

class _AdminContractContentScreenState
    extends State<AdminContractContentScreen> {
  final GlobalKey<ContractEditorWidgetState> _editorKey =
      GlobalKey<ContractEditorWidgetState>();
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Load contract content when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContractContentProvider>().initialize();
    });
  }

  void _handleContentChanged(List<dynamic> content, String plainText) {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveContent() async {
    final provider = context.read<ContractContentProvider>();
    final authProvider = context.read<AuthProvider>();

    // Get content from editor
    final editorState = _editorKey.currentState;
    if (editorState == null) return;

    final content = editorState.getContent();
    final plainText = editorState.getPlainText();

    final success = await provider.saveContractContent(
      content: content,
      plainText: plainText,
      modifiedBy: authProvider.user?.uid ?? 'unknown',
    );

    if (mounted) {
      if (success) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contract content saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to save contract content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Contract Content'),
        content: const Text(
          'Are you sure you want to clear all contract content? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<ContractContentProvider>();
      final success = await provider.deleteContractContent();

      if (mounted) {
        if (success) {
          setState(() {
            _hasUnsavedChanges = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contract content cleared'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<ContractContentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Header
              _buildHeader(provider),
              
              // Editor
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructions card
                      _buildInstructionsCard(),
                      const SizedBox(height: 24),
                      
                      // Editor widget
                      SizedBox(
                        height: 600,
                        child: ContractEditorWidget(
                          key: _editorKey,
                          initialContent: provider.contractContent?.content,
                          onContentChanged: _handleContentChanged,
                          readOnly: false,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Version info
                      if (provider.contractContent != null &&
                          provider.contractContent!.version > 0)
                        _buildVersionInfo(provider),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ContractContentProvider provider) {
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
          Icon(
            Icons.description,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contract Content Setup',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure the contract content that will be used for customer agreements',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange[800]),
                  const SizedBox(width: 6),
                  Text(
                    'Unsaved changes',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: provider.isSaving ? null : _saveContent,
            icon: provider.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(provider.isSaving ? 'Saving...' : 'Save Contract'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use the Contract Editor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use the toolbar to format your contract content. You can add headings, lists, bold/italic text, and more. '
                  'Copy and paste your contract text into the editor, then format it as needed. '
                  'Click "Save Contract" when you\'re done.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo(ContractContentProvider provider) {
    final contract = provider.contractContent!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            'Version ${contract.version}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 24),
          Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Last modified: ${_formatDate(contract.lastModified)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

