import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/admin/product_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_items_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/role_manager.dart';

class AdminProductManagementScreen extends StatefulWidget {
  const AdminProductManagementScreen({super.key});

  @override
  State<AdminProductManagementScreen> createState() =>
      _AdminProductManagementScreenState();
}

class _AdminProductManagementScreenState
    extends State<AdminProductManagementScreen> {
  static const List<Map<String, String>> _countryOptions = [
    {'code': 'ZA', 'name': 'South Africa'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'NZ', 'name': 'New Zealand'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'NL', 'name': 'Netherlands'},
    {'code': 'BE', 'name': 'Belgium'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (_canAccess(authProvider.userRole)) {
        context.read<ProductItemsProvider>().listenToProducts();
      }
    });
  }

  bool _canAccess(UserRole role) {
    return RoleManager.canManageProducts(role);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!_canAccess(authProvider.userRole)) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Only Super Administrators and Country Administrators can manage products.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<ProductItemsProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading && productProvider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    productProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<ProductItemsProvider>().listenToProducts(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildProductsTable(context, productProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage products across countries with pricing and status controls.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showProductDialog(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(
    BuildContext context,
    ProductItemsProvider provider,
  ) {
    if (provider.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first product to start managing pricing and availability.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Container(
            height: 520,
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
            child: DataTable2(
              horizontalMargin: 16,
              columnSpacing: 16,
              headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn2(label: Text('Product Name'), size: ColumnSize.L),
                DataColumn2(label: Text('Description'), size: ColumnSize.L),
                DataColumn2(label: Text('Country')),
                DataColumn2(label: Text('Status')),
                DataColumn2(label: Text('Price')),
                DataColumn2(label: Text('Actions'), fixedWidth: 130),
              ],
              rows: provider.items.map((product) {
                return DataRow(
                  cells: [
                    DataCell(Text(product.name)),
                    DataCell(
                      Text(
                        product.description.isEmpty ? '-' : product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(Text(product.country)),
                    DataCell(_buildStatusChip(product.isActive)),
                    DataCell(Text('R ${product.price.toStringAsFixed(2)}')),
                    DataCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit',
                            color: Colors.blue,
                            onPressed: () =>
                                _showProductDialog(context, product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            tooltip: 'Delete',
                            color: Colors.red,
                            onPressed: () => _confirmDelete(context, product),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Chip(
      backgroundColor: isActive
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
      label: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? Colors.green[700] : Colors.red[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, ProductItem? product) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    final priceController = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    bool isActive = product?.isActive ?? true;
    String selectedCountry = _countryOptions.first['name']!;
    if (product?.country.isNotEmpty == true &&
        _countryOptions.any((c) => c['name'] == product!.country)) {
      selectedCountry = product!.country;
    }
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Product' : 'Add Product'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a product name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Product Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCountry,
                          items: _countryOptions
                              .map(
                                (country) => DropdownMenuItem(
                                  value: country['name'],
                                  child: Text(country['name']!),
                                ),
                              )
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedCountry = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a country';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            prefixText: 'R ',
                            border: OutlineInputBorder(),
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a price';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: isActive,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Toggle to mark the product active/inactive',
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final price =
                        double.tryParse(priceController.text.trim()) ?? 0.0;

                    try {
                      final provider = context.read<ProductItemsProvider>();

                      if (isEdit) {
                        final updated = product.copyWith(
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          country: selectedCountry,
                          price: price,
                          isActive: isActive,
                        );
                        await provider.updateProductItem(updated);
                      } else {
                        await provider.addProductItem(
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          country: selectedCountry,
                          isActive: isActive,
                          price: price,
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? 'Product updated successfully'
                                  : 'Product added successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save product: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ProductItem product) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ProductItemsProvider>().deleteProductItem(
                    product.id,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product deleted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete product: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
