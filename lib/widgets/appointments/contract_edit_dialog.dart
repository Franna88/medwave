import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contracts/contract.dart';
import '../../models/streams/appointment.dart';
import '../../models/admin/product_item.dart';
import '../../models/admin/product_package.dart';
import '../../providers/product_items_provider.dart';
import '../../providers/product_packages_provider.dart';
import 'package:intl/intl.dart';
import '../../providers/contract_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase/sales_appointment_service.dart';
import '../../utils/role_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/contract_editor_widget.dart';

/// Line type for invoice display and PDF hierarchy.
const String _kLineTypeStandalone = 'standalone';
const String _kLineTypePackageHeader = 'packageHeader';
const String _kLineTypePackageItem = 'packageItem';
const String _kLineTypeAddedService = 'addedService';
const String _kLineTypeDiscount = 'discount';

/// One editable line on the invoice (product, package, or custom).
class _InvoiceLineItem {
  final String id;
  String name;
  int quantity;
  double price;
  final bool isCustom;

  /// For sub-rows under a package (packageItem, addedService).
  final String? parentId;

  /// One of: standalone, packageHeader, packageItem, addedService.
  final String lineType;

  _InvoiceLineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.isCustom = false,
    this.parentId,
    this.lineType = _kLineTypeStandalone,
  });
}

/// Dialog for editing contract details and creating a revision
class ContractEditDialog extends StatefulWidget {
  final Contract contract;
  final SalesAppointment appointment;

  const ContractEditDialog({
    super.key,
    required this.contract,
    required this.appointment,
  });

  @override
  State<ContractEditDialog> createState() => _ContractEditDialogState();
}

class _ContractEditDialogState extends State<ContractEditDialog> {
  // Invoice line items (source of truth for PDF) – edited in preview dialog
  late List<_InvoiceLineItem> _invoiceLineItems;

  // Customer info
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  final TextEditingController _editReasonController = TextEditingController();

  // Payment type
  String _paymentType = 'deposit';

  // Contract content editor
  final GlobalKey<ContractEditorWidgetState> _contractEditorKey =
      GlobalKey<ContractEditorWidgetState>();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    // Load packages so "Add package" in invoice preview has data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductPackagesProvider>().listenToPackages();
      }
    });
  }

  /// Builds header + package items + included services for a package (same as "Add package" in preview).
  List<_InvoiceLineItem> _expandPackageToLines(
    ProductPackage pkg,
    List<ProductItem> products,
  ) {
    final lines = <_InvoiceLineItem>[];
    lines.add(
      _InvoiceLineItem(
        id: pkg.id,
        name: pkg.name,
        quantity: 1,
        price: pkg.price,
        isCustom: false,
        parentId: null,
        lineType: _kLineTypePackageHeader,
      ),
    );
    for (final entry in pkg.packageItems) {
      final productMatch = products
          .where((p) => p.id == entry.productId)
          .toList();
      final resolvedName = productMatch.isEmpty
          ? 'Product ${entry.productId}'
          : productMatch.first.name;
      lines.add(
        _InvoiceLineItem(
          id: '${pkg.id}-item-${entry.productId}',
          name: '${entry.quantity}x $resolvedName',
          quantity: entry.quantity,
          price: 0,
          isCustom: false,
          parentId: pkg.id,
          lineType: _kLineTypePackageItem,
        ),
      );
    }
    final labels = pkg.includedServiceLabels ?? [];
    for (var i = 0; i < labels.length; i++) {
      lines.add(
        _InvoiceLineItem(
          id: '${pkg.id}-svc-$i',
          name: labels[i],
          quantity: 1,
          price: 0,
          isCustom: false,
          parentId: pkg.id,
          lineType: _kLineTypeAddedService,
        ),
      );
    }
    return lines;
  }

  /// Replaces any package header line (id in packages) with full expansion: header + items + services.
  List<_InvoiceLineItem> _expandPackageLinesInList(
    List<_InvoiceLineItem> items,
  ) {
    final packageProvider = context.read<ProductPackagesProvider>();
    final productProvider = context.read<ProductItemsProvider>();
    final packages = packageProvider.packages;
    final products = productProvider.items.where((p) => p.isActive).toList();
    final result = <_InvoiceLineItem>[];
    for (final line in items) {
      final matching = packages.where((p) => p.id == line.id).toList();
      if (matching.isNotEmpty &&
          (line.lineType == _kLineTypePackageHeader ||
              line.lineType == _kLineTypeStandalone)) {
        result.addAll(_expandPackageToLines(matching.first, products));
      } else {
        result.add(line);
      }
    }
    return result;
  }

  void _initializeFields() {
    // Initialize customer info from contract
    _customerNameController.text = widget.contract.customerName;
    _emailController.text = widget.contract.email;
    _phoneController.text = widget.contract.phone;
    _shippingAddressController.text = widget.contract.shippingAddress ?? '';
    _paymentType = widget.contract.paymentType;

    // Invoice line items: from contract, or seed from appointment when contract has no products
    if (widget.contract.products.isNotEmpty) {
      _invoiceLineItems = widget.contract.products
          .map(
            (p) => _InvoiceLineItem(
              id: p.id,
              name: p.name,
              quantity: p.quantity,
              price: p.price,
              isCustom: false,
              parentId: p.parentId,
              lineType:
                  p.lineType ??
                  (p.isSubItem ? _kLineTypePackageItem : _kLineTypeStandalone),
            ),
          )
          .toList();
      _invoiceLineItems = _expandPackageLinesInList(_invoiceLineItems);
    } else if (widget.appointment.optInProducts.isNotEmpty ||
        widget.appointment.optInPackages.isNotEmpty) {
      final packageProvider = context.read<ProductPackagesProvider>();
      final productProvider = context.read<ProductItemsProvider>();
      final packages = packageProvider.packages;
      final products = productProvider.items.where((p) => p.isActive).toList();
      final seedList = <_InvoiceLineItem>[];
      for (final p in widget.appointment.optInProducts) {
        seedList.add(
          _InvoiceLineItem(
            id: p.id,
            name: p.name,
            quantity: p.quantity,
            price: p.price,
            lineType: _kLineTypeStandalone,
          ),
        );
      }
      for (final p in widget.appointment.optInPackages) {
        final pkg = packages.where((x) => x.id == p.id).toList();
        if (pkg.isNotEmpty) {
          seedList.addAll(_expandPackageToLines(pkg.first, products));
        } else {
          seedList.add(
            _InvoiceLineItem(
              id: p.id,
              name: p.name,
              quantity: p.quantity,
              price: p.price,
              lineType: _kLineTypePackageHeader,
            ),
          );
        }
      }
      _invoiceLineItems = seedList;
    } else {
      _invoiceLineItems = widget.contract.products
          .map(
            (p) => _InvoiceLineItem(
              id: p.id,
              name: p.name,
              quantity: p.quantity,
              price: p.price,
              isCustom: false,
              parentId: p.parentId,
              lineType:
                  p.lineType ??
                  (p.isSubItem ? _kLineTypePackageItem : _kLineTypeStandalone),
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shippingAddressController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  Future<void> _saveRevision() async {
    if (_invoiceLineItems.isEmpty) {
      setState(() {
        _errorMessage =
            'Please add at least one line item in the invoice preview.';
      });
      return;
    }

    if (_shippingAddressController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Shipping address is required';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final productProvider = context.read<ProductItemsProvider>();
      final packageProvider = context.read<ProductPackagesProvider>();
      final productIds = productProvider.items
          .where((p) => p.isActive)
          .map((p) => p.id)
          .toSet();
      final packageIds = packageProvider.packages
          .where((p) => p.isActive)
          .map((p) => p.id)
          .toSet();

      // Build contract products from invoice line items (source of truth)
      final contractProducts = _invoiceLineItems
          .map(
            (l) => ContractProduct(
              id: l.id,
              name: l.name,
              price: l.price,
              quantity: l.quantity,
              isSubItem:
                  l.lineType == _kLineTypePackageItem ||
                  l.lineType == _kLineTypeAddedService,
              parentId: l.parentId,
              lineType: l.lineType,
            ),
          )
          .toList();

      // Derive optInProducts and optInPackages from invoice lines for downstream flows
      final updatedOptInProducts = _invoiceLineItems
          .where((l) => productIds.contains(l.id))
          .map(
            (l) => OptInProduct(
              id: l.id,
              name: l.name,
              price: l.price,
              quantity: l.quantity,
            ),
          )
          .toList();
      final updatedOptInPackages = _invoiceLineItems
          .where((l) => packageIds.contains(l.id))
          .map(
            (l) => OptInProduct(
              id: l.id,
              name: l.name,
              price: l.price,
              quantity: l.quantity,
            ),
          )
          .toList();

      final salesAppointmentService = SalesAppointmentService();
      final updatedAppointment = widget.appointment.copyWith(
        optInProducts: updatedOptInProducts,
        optInPackages: updatedOptInPackages,
        updatedAt: DateTime.now(),
      );
      await salesAppointmentService.updateAppointment(updatedAppointment);

      final calculatedSubtotal = _calculateSubtotalFromInvoiceLines();

      final authProvider = context.read<AuthProvider>();
      final provider = context.read<ContractProvider>();

      // Get edited contract content from editor
      Map<String, dynamic>? editedContractContent;
      final editorState = _contractEditorKey.currentState;
      if (editorState != null) {
        final editedContent = editorState.getContent();
        final editedPlainText = editorState.getPlainText();
        editedContractContent = {
          'content': editedContent,
          'plainText': editedPlainText,
        };
      }

      final revision = await provider.createContractRevision(
        originalContract: widget.contract,
        appointment: widget.appointment,
        createdBy: authProvider.user?.uid ?? '',
        createdByName: authProvider.userName ?? 'Unknown',
        editReason: _editReasonController.text.trim().isEmpty
            ? null
            : _editReasonController.text.trim(),
        products: contractProducts,
        customerName: _customerNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        shippingAddress: _shippingAddressController.text.trim(),
        paymentType: _paymentType,
        editedContractContent: editedContractContent,
        subtotal: calculatedSubtotal,
      );

      if (revision != null && mounted) {
        Navigator.of(context).pop(revision);
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage =
              provider.error ?? 'Failed to create contract revision';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isAdmin =
        authProvider.userRole == UserRole.superAdmin ||
        authProvider.userRole == UserRole.countryAdmin;

    return Dialog(
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Contract',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit reason
                    TextField(
                      controller: _editReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Edit Reason (optional)',
                        hintText: 'Why are you editing this contract?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Customer Information
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shippingAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Shipping Address *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Payment Type
                    const Text(
                      'Payment Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Deposit'),
                            value: 'deposit',
                            groupValue: _paymentType,
                            onChanged: (value) {
                              setState(() {
                                _paymentType = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Full Payment',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            value: 'full_payment',
                            groupValue: _paymentType,
                            onChanged: (value) {
                              setState(() {
                                _paymentType = value!;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Invoice
                    const Text(
                      'Invoice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openInvoicePreviewEditDialog,
                      icon: const Icon(Icons.receipt_long, size: 20),
                      label: const Text('Preview & edit invoice'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _invoiceLineItems.isEmpty
                          ? 'No line items yet. Open the preview to add and edit lines.'
                          : '${_invoiceLineItems.length} line item${_invoiceLineItems.length == 1 ? '' : 's'} · Subtotal R ${_calculateSubtotalFromInvoiceLines().toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),

                    // Calculated totals - only visible to admins
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildTotalRow(
                              'Subtotal',
                              _calculateSubtotalFromInvoiceLines(),
                            ),
                            const SizedBox(height: 8),
                            _buildTotalRow(
                              'Deposit (10%)',
                              _calculateSubtotalFromInvoiceLines() * 0.10,
                            ),
                            const SizedBox(height: 8),
                            _buildTotalRow(
                              'Remaining (60%)',
                              _calculateSubtotalFromInvoiceLines() * 0.60,
                            ),
                          ],
                        ),
                      ),
                    if (isAdmin) const SizedBox(height: 24),

                    // Contract Terms/Content Editor
                    const Text(
                      'Contract Terms',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Edit the contract terms and conditions below. Changes will be reflected in the revised contract.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ContractEditorWidget(
                        key: _contractEditorKey,
                        initialContent:
                            widget.contract.contractContentData['content']
                                as List<dynamic>?,
                        readOnly: false,
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRevision,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save Revision'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateSubtotalFromInvoiceLines() {
    double total = 0;
    for (final line in _invoiceLineItems) {
      total += line.quantity * line.price;
    }
    return total;
  }

  Widget _buildTotalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          'R ${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  bool get isAdmin {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.userRole == UserRole.superAdmin ||
          authProvider.userRole == UserRole.countryAdmin;
    } catch (e) {
      return false;
    }
  }

  void _openInvoicePreviewEditDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => InvoicePreviewEditDialog(
        lineItems: _invoiceLineItems,
        customerName: _customerNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        shippingAddress: _shippingAddressController.text,
        date: widget.contract.createdAt,
        onClose: () => setState(() {}),
      ),
    );
  }
}

/// Dialog that shows the invoice exactly as it will be sent with the contract (full replica of PDF page 2), with editable line items.
class InvoicePreviewEditDialog extends StatefulWidget {
  final List<_InvoiceLineItem> lineItems;
  final String customerName;
  final String email;
  final String phone;
  final String shippingAddress;
  final DateTime date;
  final VoidCallback? onClose;

  const InvoicePreviewEditDialog({
    super.key,
    required this.lineItems,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.shippingAddress,
    required this.date,
    this.onClose,
  });

  @override
  State<InvoicePreviewEditDialog> createState() =>
      _InvoicePreviewEditDialogState();
}

class _InvoicePreviewEditDialogState extends State<InvoicePreviewEditDialog> {
  final Map<String, List<TextEditingController>> _controllers = {};

  @override
  void dispose() {
    for (final list in _controllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _disposeControllers(String id) {
    final list = _controllers.remove(id);
    if (list != null) {
      for (final c in list) {
        c.dispose();
      }
    }
  }

  double _subtotal() {
    double total = 0;
    for (final line in widget.lineItems) {
      total += line.quantity * line.price;
    }
    return total;
  }

  double _subtotalBeforeDiscount() {
    double total = 0;
    for (final line in widget.lineItems) {
      if (line.lineType != _kLineTypeDiscount) {
        total += line.quantity * line.price;
      }
    }
    return total;
  }

  double _discountAmount() {
    double total = 0;
    for (final line in widget.lineItems) {
      if (line.lineType == _kLineTypeDiscount) {
        total += line.quantity * line.price;
      }
    }
    return -total; // positive value for display (discount lines have negative price)
  }

  void _addDiscount() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add discount'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (R)',
              hintText: 'e.g. 50',
            ),
            onSubmitted: (value) {
              final a = double.tryParse(value);
              if (a != null && a > 0) Navigator.of(context).pop(a);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final a = double.tryParse(controller.text.trim());
                if (a != null && a > 0) {
                  Navigator.of(context).pop(a);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (amount != null && amount > 0 && mounted) {
      final id = 'discount-${DateTime.now().millisecondsSinceEpoch}';
      widget.lineItems.add(
        _InvoiceLineItem(
          id: id,
          name: 'Discount',
          quantity: 1,
          price: -amount,
          isCustom: true,
          lineType: _kLineTypeDiscount,
        ),
      );
      setState(() {});
    }
  }

  void _addLine() {
    final id = 'custom-${DateTime.now().millisecondsSinceEpoch}';
    widget.lineItems.add(
      _InvoiceLineItem(
        id: id,
        name: '',
        quantity: 1,
        price: 0,
        isCustom: true,
        lineType: _kLineTypeStandalone,
      ),
    );
    setState(() {});
  }

  void _addProduct() async {
    final productProvider = context.read<ProductItemsProvider>();
    final products = productProvider.items.where((p) => p.isActive).toList();
    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No products available')));
      }
      return;
    }
    final ProductItem? selected = await showDialog<ProductItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add item'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('R ${product.price.toStringAsFixed(2)}'),
                onTap: () => Navigator.of(context).pop(product),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    widget.lineItems.add(
      _InvoiceLineItem(
        id: selected.id,
        name: selected.name,
        quantity: 1,
        price: selected.price,
        isCustom: false,
        lineType: _kLineTypeStandalone,
      ),
    );
    setState(() {});
  }

  void _addPackage() async {
    final packageProvider = context.read<ProductPackagesProvider>();
    final productProvider = context.read<ProductItemsProvider>();
    final packages = packageProvider.packages.where((p) => p.isActive).toList();
    if (packages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No packages available')));
      }
      return;
    }
    final ProductPackage? selected = await showDialog<ProductPackage>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add package'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final pkg = packages[index];
              return ListTile(
                title: Text(pkg.name),
                subtitle: Text('R ${pkg.price.toStringAsFixed(2)}'),
                onTap: () => Navigator.of(context).pop(pkg),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final products = productProvider.items.where((p) => p.isActive).toList();
    // Package header
    widget.lineItems.add(
      _InvoiceLineItem(
        id: selected.id,
        name: selected.name,
        quantity: 1,
        price: selected.price,
        isCustom: false,
        parentId: null,
        lineType: _kLineTypePackageHeader,
      ),
    );
    // Package item lines (resolve productId to name; price 0 so only package header counts toward total)
    for (final entry in selected.packageItems) {
      final productMatch = products
          .where((p) => p.id == entry.productId)
          .toList();
      final resolvedName = productMatch.isEmpty
          ? 'Product ${entry.productId}'
          : productMatch.first.name;
      widget.lineItems.add(
        _InvoiceLineItem(
          id: '${selected.id}-item-${entry.productId}',
          name: '${entry.quantity}x $resolvedName',
          quantity: entry.quantity,
          price: 0, // descriptive only; package price is on the header line
          isCustom: false,
          parentId: selected.id,
          lineType: _kLineTypePackageItem,
        ),
      );
    }
    // Added service lines
    final labels = selected.includedServiceLabels ?? [];
    for (var i = 0; i < labels.length; i++) {
      widget.lineItems.add(
        _InvoiceLineItem(
          id: '${selected.id}-svc-$i',
          name: labels[i],
          quantity: 1,
          price: 0,
          isCustom: false,
          parentId: selected.id,
          lineType: _kLineTypeAddedService,
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top bar with close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Invoice – as it will be sent to the client',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      widget.onClose?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // Invoice content (replica of contract PDF page 2)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Image.asset(
                        'images/medwave_logo_grey.png',
                        width: 150,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 150, height: 50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'MedWave',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '™',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' Device Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Two-column: Company | Customer
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MedWave™ RSA PTY LTD',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Blaaukrans Office Park',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Jeffreys Bay, 6330',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Call: +27 79 427 2486',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'info@medwavegroup.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'www.medwavegroup.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoLine(
                                'Date:',
                                DateFormat('yyyy-MM-dd').format(widget.date),
                              ),
                              const SizedBox(height: 4),
                              _buildInfoLine(
                                'Customer Name:',
                                widget.customerName,
                              ),
                              const SizedBox(height: 4),
                              _buildInfoLine('Customer Phone:', widget.phone),
                              const SizedBox(height: 4),
                              _buildInfoLine('Customer Email:', widget.email),
                              if (widget.shippingAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _buildInfoLine(
                                  'Shipping Address:',
                                  widget.shippingAddress,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quote table (Name | QTY | Price | Total, editable)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 4,
                                  child: Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    'QTY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    'Price',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    'Total',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 44),
                              ],
                            ),
                          ),
                          ...List.generate(widget.lineItems.length, (index) {
                            final line = widget.lineItems[index];
                            List<TextEditingController> controllers =
                                _controllers[line.id] ??= [
                                  TextEditingController(text: line.name),
                                  TextEditingController(
                                    text: line.quantity.toString(),
                                  ),
                                  TextEditingController(
                                    text: line.price.toStringAsFixed(2),
                                  ),
                                ];
                            final isSubItem =
                                line.lineType == _kLineTypePackageItem ||
                                line.lineType == _kLineTypeAddedService;
                            final isHeader =
                                line.lineType == _kLineTypePackageHeader;
                            return Container(
                              padding: EdgeInsets.only(
                                left: 8 + (isSubItem ? 20.0 : 0),
                                right: 8,
                                top: 6,
                                bottom: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                color: isHeader ? Colors.grey[100] : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: TextField(
                                      controller: controllers[0],
                                      style: TextStyle(
                                        fontWeight: isHeader
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        line.name = value;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 56,
                                    child: TextField(
                                      controller: controllers[1],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final qty = int.tryParse(value) ?? 1;
                                        if (qty >= 1) {
                                          line.quantity = qty;
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 72,
                                    child: TextField(
                                      controller: controllers[2],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final price =
                                            double.tryParse(value) ?? 0.0;
                                        line.price = price;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      'R ${(line.quantity * line.price).toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _disposeControllers(line.id);
                                      widget.lineItems.removeAt(index);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Totals inside table (match PDF)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildTotalRow(
                                  'Subtotal',
                                  _subtotalBeforeDiscount(),
                                ),
                                if (_discountAmount() > 0) ...[
                                  const SizedBox(height: 4),
                                  _buildTotalRow(
                                    'Discount',
                                    -_discountAmount(),
                                    isBold: true,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                _buildTotalRow(
                                  'Deposit Allocate',
                                  _subtotal() * 0.10,
                                  isBold: true,
                                ),
                                const Divider(),
                                _buildTotalRow(
                                  'Total',
                                  _subtotal(),
                                  isBold: true,
                                  isLarge: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.inventory, size: 18),
                          label: const Text('Add package'),
                          onPressed: _addPackage,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.shopping_bag, size: 18),
                          label: const Text('Add item'),
                          onPressed: _addProduct,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add line item'),
                          onPressed: _addLine,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.discount, size: 18),
                          label: const Text('Add discount'),
                          onPressed: _addDiscount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Payment text
                    Text(
                      'Please complete the deposit payment to proceed with your order. Payment instructions and confirmation will be sent via email.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 24),
                    // Bank details (match PDF)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[350]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBankLine(
                            'Account holder:',
                            'MEDWAVE RSA PTY LTD',
                          ),
                          const SizedBox(height: 4),
                          _buildBankLine('ID/Reg Number:', '2024/700802/07'),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Standard Bank',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildBankLine('Branch:', 'JEFFREY\'S BAY'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBankLine('Account type:', 'CURRENT'),
                                    const SizedBox(height: 4),
                                    _buildBankLine('Branch code:', '000315'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBankLine(
                                      'Account number:',
                                      '10 23 582 938 0',
                                    ),
                                    const SizedBox(height: 4),
                                    _buildBankLine('SWIFT code:', 'SBZAZAJJ'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Footer
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          Divider(height: 1, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MedWave RSA PTY LTD',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'www.medwavegroup.com',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Done button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      widget.onClose?.call();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildBankLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 10, color: Colors.grey[800]),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: Colors.grey[700]),
          ),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isLarge ? 16 : 13,
          ),
        ),
        Text(
          'R ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isLarge ? 16 : 13,
          ),
        ),
      ],
    );
  }
}
