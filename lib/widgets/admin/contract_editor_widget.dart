import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../theme/app_theme.dart';

/// Widget for editing contract content with rich text formatting
class ContractEditorWidget extends StatefulWidget {
  final List<dynamic>? initialContent;
  final Function(List<dynamic> content, String plainText)? onContentChanged;
  final bool readOnly;

  const ContractEditorWidget({
    super.key,
    this.initialContent,
    this.onContentChanged,
    this.readOnly = false,
  });

  @override
  State<ContractEditorWidget> createState() => ContractEditorWidgetState();
}

class ContractEditorWidgetState extends State<ContractEditorWidget> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    Document document;
    
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      try {
        document = Document.fromJson(widget.initialContent!);
      } catch (e) {
        // If parsing fails, create empty document
        document = Document();
      }
    } else {
      document = Document();
    }

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: widget.readOnly,
    );

    // Listen for changes
    _controller.document.changes.listen((event) {
      if (widget.onContentChanged != null) {
        final content = _controller.document.toDelta().toJson();
        final plainText = _controller.document.toPlainText();
        widget.onContentChanged!(content, plainText);
      }
    });
  }

  @override
  void didUpdateWidget(ContractEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update content if it changed externally
    if (widget.initialContent != oldWidget.initialContent) {
      _initializeController();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Get the current content as JSON
  List<dynamic> getContent() {
    return _controller.document.toDelta().toJson();
  }

  /// Get the current content as plain text
  String getPlainText() {
    return _controller.document.toPlainText();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Contract Content Editor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!widget.readOnly)
                  Text(
                    'Use the toolbar below to format your contract',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Toolbar (only in edit mode)
          if (!widget.readOnly)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: QuillSimpleToolbar(controller: _controller),
            ),
          
          // Editor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: QuillEditor.basic(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: _scrollController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stateless preview widget for displaying contract content
class ContractContentPreview extends StatelessWidget {
  final List<dynamic>? content;

  const ContractContentPreview({
    super.key,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (content == null || content!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No contract content',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contract content has not been configured yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ContractEditorWidget(
      initialContent: content,
      readOnly: true,
    );
  }
}
