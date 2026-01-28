import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contracts/contract.dart';
import '../../models/streams/appointment.dart';
import '../../models/admin/product_item.dart';
import '../../providers/product_items_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/role_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/contract_editor_widget.dart';

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
  // Product selection with quantities
  final Map<String, int> _selectedProductQuantities = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

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
  }

  void _initializeFields() {
    // Initialize customer info from contract
    _customerNameController.text = widget.contract.customerName;
    _emailController.text = widget.contract.email;
    _phoneController.text = widget.contract.phone;
    _shippingAddressController.text = widget.contract.shippingAddress ?? '';
    _paymentType = widget.contract.paymentType;

    // Initialize products from contract
    // Get quantities from appointment.optInProducts if available
    final productProvider = context.read<ProductItemsProvider>();
    final availableProducts = productProvider.items
        .where((p) => p.isActive)
        .toList();

    // Pre-select products that are in the contract
    for (final contractProduct in widget.contract.products) {
      final product = availableProducts.firstWhere(
        (p) => p.id == contractProduct.id,
        orElse: () => ProductItem(
          id: contractProduct.id,
          name: contractProduct.name,
          price: contractProduct.price,
          description: '',
          country: '',
          isActive: true,
        ),
      );

      // Get quantity from appointment.optInProducts if product exists there
      final optInProduct = widget.appointment.optInProducts.firstWhere(
        (p) => p.id == contractProduct.id,
        orElse: () => OptInProduct(
          id: contractProduct.id,
          name: contractProduct.name,
          price: contractProduct.price,
          quantity: 1, // Default to 1 if not found
        ),
      );
      final quantity = optInProduct.quantity;

      _selectedProductQuantities[product.id] = quantity;
      _quantityControllers[product.id] = TextEditingController(
        text: quantity.toString(),
      );
      _priceControllers[product.id] = TextEditingController(
        text: product.price.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shippingAddressController.dispose();
    _editReasonController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveRevision() async {
    if (_selectedProductQuantities.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one product';
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
      final products = productProvider.items.where((p) => p.isActive).toList();

      // Build list of ContractProducts from selected products
      final contractProducts = _selectedProductQuantities.entries.map((entry) {
        final product = products.firstWhere((p) => p.id == entry.key);
        // Price should be unit price (will be multiplied by quantity in calculation)
        return ContractProduct(
          id: product.id,
          name: product.name,
          price: product.price,
        );
      }).toList();

      // Calculate subtotal with quantities
      final calculatedSubtotal = _calculateSubtotal();

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
    final productProvider = context.read<ProductItemsProvider>();
    final products = productProvider.items.where((p) => p.isActive).toList();
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

                    // Products
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: products.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No products available'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final isSelected = _selectedProductQuantities
                                    .containsKey(product.id);
                                final quantityController =
                                    _quantityControllers[product.id] ??
                                    TextEditingController(text: '1');
                                final priceController =
                                    _priceControllers[product.id] ??
                                    TextEditingController(
                                      text: product.price.toStringAsFixed(2),
                                    );

                                if (!_quantityControllers.containsKey(
                                  product.id,
                                )) {
                                  _quantityControllers[product.id] =
                                      quantityController;
                                }
                                if (!_priceControllers.containsKey(
                                  product.id,
                                )) {
                                  _priceControllers[product.id] =
                                      priceController;
                                }

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedProductQuantities[product.id] =
                                            1;
                                        quantityController.text = '1';
                                      } else {
                                        _selectedProductQuantities.remove(
                                          product.id,
                                        );
                                      }
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(product.name)),
                                      if (isSelected) ...[
                                        SizedBox(
                                          width: 100,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                onPressed: () {
                                                  final currentQty =
                                                      _selectedProductQuantities[product
                                                          .id] ??
                                                      1;
                                                  if (currentQty > 1) {
                                                    setState(() {
                                                      _selectedProductQuantities[product
                                                              .id] =
                                                          currentQty - 1;
                                                      quantityController.text =
                                                          (currentQty - 1)
                                                              .toString();
                                                    });
                                                  }
                                                },
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      quantityController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  onChanged: (value) {
                                                    final qty =
                                                        int.tryParse(value) ??
                                                        1;
                                                    if (qty >= 1) {
                                                      setState(() {
                                                        _selectedProductQuantities[product
                                                                .id] =
                                                            qty;
                                                      });
                                                    }
                                                  },
                                                  decoration:
                                                      const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                              vertical: 4,
                                                            ),
                                                        isDense: true,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                onPressed: () {
                                                  final currentQty =
                                                      _selectedProductQuantities[product
                                                          .id] ??
                                                      1;
                                                  setState(() {
                                                    _selectedProductQuantities[product
                                                            .id] =
                                                        currentQty + 1;
                                                    quantityController.text =
                                                        (currentQty + 1)
                                                            .toString();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (isAdmin)
                                          SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller: priceController,
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.right,
                                              onChanged: (value) {
                                                // Price updated - trigger recalculation
                                                setState(() {});
                                              },
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
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
                            _buildTotalRow('Subtotal', _calculateSubtotal()),
                            const SizedBox(height: 8),
                            _buildTotalRow(
                              'Deposit (40%)',
                              _calculateSubtotal() * 0.40,
                            ),
                            const SizedBox(height: 8),
                            _buildTotalRow(
                              'Remaining (60%)',
                              _calculateSubtotal() * 0.60,
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

  double _calculateSubtotal() {
    final productProvider = context.read<ProductItemsProvider>();
    final products = productProvider.items.where((p) => p.isActive).toList();

    double total = 0;
    for (final entry in _selectedProductQuantities.entries) {
      final product = products.firstWhere((p) => p.id == entry.key);
      final price = isAdmin
          ? (double.tryParse(
                  _priceControllers[product.id]?.text ??
                      product.price.toString(),
                ) ??
                product.price)
          : product.price;
      total += price * entry.value;
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
}
