import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/streams/appointment.dart' as models;
import '../../../models/streams/stream_stage.dart';
import '../../../models/inventory/inventory_stock.dart';
import '../../../services/firebase/sales_appointment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/product_items_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/role_manager.dart';
import '../../../utils/stream_utils.dart';
import '../../../widgets/common/score_badge.dart';
import '../../../widgets/appointments/appointment_detail_dialog.dart';

class SalesStreamScreen extends StatefulWidget {
  const SalesStreamScreen({super.key});

  @override
  State<SalesStreamScreen> createState() => _SalesStreamScreenState();
}

class _SalesStreamScreenState extends State<SalesStreamScreen> {
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  final TextEditingController _searchController = TextEditingController();

  List<models.SalesAppointment> _allAppointments = [];
  List<models.SalesAppointment> _filteredAppointments = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<StreamStage> _stages = StreamStage.getSalesStages();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_onSearchChanged);
    // Load admin users for assignment feature (Super Admin only)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userRole == UserRole.superAdmin) {
        context.read<AdminProvider>().loadAdminUsers();
      }
      // Load product items for Opt In stage selections
      context.read<ProductItemsProvider>().listenToProducts();
      // Load inventory stock for View Stock feature
      context.read<InventoryProvider>().listenToInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAppointments() {
    _appointmentService.appointmentsStream().listen((appointments) {
      setState(() {
        _allAppointments = appointments;
        _filterAppointments();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterAppointments();
    });
  }

  void _filterAppointments() {
    List<models.SalesAppointment> currentFilteredAppointments =
        _allAppointments;

    // 1. Apply assignment filtering based on user role
    final authProvider = context.read<AuthProvider>();
    final currentUserRole = authProvider.userRole;
    final currentUserId = authProvider.user?.uid;

    if (currentUserRole == UserRole.salesAdmin) {
      currentFilteredAppointments = currentFilteredAppointments.where((apt) {
        return apt.assignedTo == currentUserId || apt.assignedTo == null;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      currentFilteredAppointments = currentFilteredAppointments.where((apt) {
        return apt.customerName.toLowerCase().contains(_searchQuery) ||
            apt.email.toLowerCase().contains(_searchQuery) ||
            apt.phone.contains(_searchQuery);
      }).toList();
    }

    _filteredAppointments = currentFilteredAppointments;
  }

  List<models.SalesAppointment> _getAppointmentsForStage(String stageId) {
    return _filteredAppointments
        .where((apt) => apt.currentStage == stageId)
        .toList();
  }

  Future<void> _moveAppointmentToStage(
    models.SalesAppointment appointment,
    String newStageId,
  ) async {
    final newStage = _stages.firstWhere((s) => s.id == newStageId);
    final oldStage = _stages.firstWhere(
      (s) => s.id == appointment.currentStage,
    );

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    final noteController = TextEditingController();
    final isOptIn = newStageId == 'opt_in';
    final productProvider = context.read<ProductItemsProvider>();
    final products =
        productProvider.items.where((p) => p.isActive).toList(growable: false);
    final selectedProductIds = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Move ${appointment.customerName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: ${oldStage.name}'),
                Text('To: ${newStage.name}'),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                if (isOptIn) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Select product(s)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    width: 720,
                    child: products.isEmpty
                        ? const Text('No products available')
                        : Column(
                            children: [
                              // Header row
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: const [
                                    SizedBox(width: 24), // checkbox space
                                    SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Product',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Description',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Country',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        'Price',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.separated(
                                  primary: false,
                                  shrinkWrap: false,
                                  itemCount: products.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    final isSelected =
                                        selectedProductIds.contains(product.id);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (checked) {
                                              setState(() {
                                                if (checked == true) {
                                                  selectedProductIds
                                                      .add(product.id);
                                                } else {
                                                  selectedProductIds
                                                      .remove(product.id);
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              product.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              product.country,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              'R ${product.price.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Move'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        String? assignedToUserId;
        String? assignedToUserName;

        if (authProvider.userRole == UserRole.salesAdmin) {
          assignedToUserId = userId;
          assignedToUserName = userName;
        }

        List<models.OptInProduct>? optInSelections;
        if (isOptIn && selectedProductIds.isNotEmpty) {
          optInSelections = selectedProductIds.map((id) {
            final product = products.firstWhere((p) => p.id == id);
            return models.OptInProduct(
              id: product.id,
              name: product.name,
              price: product.price,
            );
          }).toList();
        }

        final noteText = noteController.text.isEmpty
            ? 'Moved to ${newStage.name}'
            : noteController.text;

        await _appointmentService.moveAppointmentToStage(
          appointmentId: appointment.id,
          newStage: newStageId,
          note: noteText,
          userId: userId,
          userName: userName,
          assignedTo: assignedToUserId,
          assignedToName: assignedToUserName,
          optInNote: isOptIn ? noteText : null,
          optInProducts: optInSelections,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${appointment.customerName} moved to ${newStage.name}',
              ),
            ),
          );

          // Show success message if converted to order
          if (newStageId == 'send_to_operations') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appointment converted to Operations order!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error moving appointment: $e')),
          );
        }
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildKanbanBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalAppointments = _filteredAppointments.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales Stream',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Search
              Container(
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search appointments...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // View Stock button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showStockDialog(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'View Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalAppointments appointments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Appointments from Marketing booking stage',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _showStockDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer<InventoryProvider>(
        builder: (context, inventoryProvider, child) {
          final stockItems = inventoryProvider.allStockItems;
          final stats = inventoryProvider.stats;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 800,
              height: 600,
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Stock',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Current stock levels from warehouse',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    color: Colors.grey[50],
                    child: Row(
                      children: [
                        _buildStockStatChip(
                          'Total',
                          stats['total']?.toString() ?? '0',
                          AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStockStatChip(
                          'In Stock',
                          stats['inStock']?.toString() ?? '0',
                          AppTheme.successColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStockStatChip(
                          'Low Stock',
                          stats['lowStock']?.toString() ?? '0',
                          AppTheme.warningColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStockStatChip(
                          'Out of Stock',
                          stats['outOfStock']?.toString() ?? '0',
                          AppTheme.errorColor,
                        ),
                      ],
                    ),
                  ),
                  // Stock list
                  Expanded(
                    child: inventoryProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : stockItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No stock records found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Stock will appear here once warehouse updates inventory',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: stockItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final stock = stockItems[index];
                                  return _buildStockListItem(stock);
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockListItem(InventoryStock stock) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (stock.isOutOfStock) {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.error_outline;
      statusText = 'Out of Stock';
    } else if (stock.isLowStock) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.warning_amber_outlined;
      statusText = 'Low Stock';
    } else {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle_outline;
      statusText = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: stock.isLowStock || stock.isOutOfStock
              ? statusColor.withOpacity(0.5)
              : Colors.grey[200]!,
          width: stock.isLowStock || stock.isOutOfStock ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stock.shelfLocation.isNotEmpty
                          ? '${stock.warehouseLocation} - ${stock.shelfLocation}'
                          : stock.warehouseLocation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Quantity
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  '${stock.currentQty}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  'in stock',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Min level
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  '${stock.minStockLevel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'min level',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          // Last updated
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Last Updated',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stock.lastStockTakeDate != null
                      ? _formatStockDate(stock.lastStockTakeDate!)
                      : 'Never',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStockDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildKanbanBoard() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _stages.map((stage) {
          final appointments = _getAppointmentsForStage(stage.id);
          return _buildStageColumn(stage, appointments);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(
    StreamStage stage,
    List<models.SalesAppointment> appointments,
  ) {
    final sortedAppointments = StreamUtils.sortByFormScore(
      appointments,
      (apt) => apt.formScore,
    );
    final tieredAppointments = StreamUtils.withTierSeparators(
      sortedAppointments,
      (apt) => apt.formScore,
    );

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(int.parse(stage.color.replaceFirst('#', '0xff'))),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stage.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${appointments.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Appointments list with DragTarget
          Expanded(
            child: DragTarget<models.SalesAppointment>(
              onWillAcceptWithDetails: (details) {
                // Only allow forward movement to next immediate stage
                return StreamUtils.canMoveToStage(
                  details.data.currentStage,
                  stage.id,
                  _stages,
                );
              },
              onAcceptWithDetails: (details) =>
                  _moveAppointmentToStage(details.data, stage.id),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Color(
                            int.parse(stage.color.replaceFirst('#', '0xff')),
                          ).withOpacity(0.1)
                        : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? Color(
                              int.parse(stage.color.replaceFirst('#', '0xff')),
                            )
                          : Colors.grey.shade200,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: appointments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No appointments in ${stage.name.toLowerCase()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tieredAppointments.length,
                          itemBuilder: (context, index) {
                            final entry = tieredAppointments[index];

                            if (entry.isDivider) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Container(
                                  height: 2,
                                  color: Colors.grey.shade400,
                                ),
                              );
                            }

                            final appointment = entry.item!;
                            final isFinal = StreamUtils.isFinalStage(
                              appointment.currentStage,
                              _stages,
                            );
                            final card = _buildAppointmentCard(appointment);

                            // Gray out final stage cards
                            final styledCard = isFinal
                                ? Opacity(opacity: 0.6, child: card)
                                : card;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isFinal
                                  ? styledCard // Non-draggable for final stage
                                  : Draggable<models.SalesAppointment>(
                                      data: appointment,
                                      feedback: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 280,
                                          child: Opacity(
                                            opacity: 0.8,
                                            child: _buildAppointmentCard(
                                              appointment,
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildAppointmentCard(
                                          appointment,
                                        ),
                                      ),
                                      child: styledCard,
                                    ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppointmentDetail(
    models.SalesAppointment appointment,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AppointmentDetailDialog(
        appointment: appointment,
        stages: _stages,
        onAssignmentChanged: () {
          setState(() {
            _filterAppointments();
          });
        },
      ),
    );
  }

  Widget _buildAppointmentCard(models.SalesAppointment appointment) {
    return InkWell(
      onTap: () => _showAppointmentDetail(appointment),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    appointment.customerName.isNotEmpty
                        ? appointment.customerName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        appointment.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Assigned to badge
            if (appointment.assignedToName != null &&
                appointment.assignedToName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned: ${appointment.assignedToName}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (appointment.appointmentDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${appointment.appointmentDate!.day}/${appointment.appointmentDate!.month}/${appointment.appointmentDate!.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  appointment.timeInStageDisplay,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (appointment.formScore != null)
                  ScoreBadge(score: appointment.formScore),
                if (appointment.formScore != null) const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  onSelected: (stageId) =>
                      _moveAppointmentToStage(appointment, stageId),
                  itemBuilder: (context) => _stages
                      .where((s) => s.id != appointment.currentStage)
                      .map(
                        (stage) => PopupMenuItem(
                          value: stage.id,
                          child: Text('Move to ${stage.name}'),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
