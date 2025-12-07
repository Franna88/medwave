import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/streams/order.dart' as models;
import '../../../models/streams/stream_stage.dart';
import '../../../services/firebase/order_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/stream_utils.dart';
import '../../../widgets/common/score_badge.dart';

class OperationsStreamScreen extends StatefulWidget {
  const OperationsStreamScreen({super.key});

  @override
  State<OperationsStreamScreen> createState() => _OperationsStreamScreenState();
}

class _OperationsStreamScreenState extends State<OperationsStreamScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  List<models.Order> _allOrders = [];
  List<models.Order> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<StreamStage> _stages = StreamStage.getOperationsStages();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    _orderService.ordersStream().listen((orders) {
      setState(() {
        _allOrders = orders;
        _filterOrders();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterOrders();
    });
  }

  void _filterOrders() {
    if (_searchQuery.isEmpty) {
      _filteredOrders = _allOrders;
    } else {
      _filteredOrders = _allOrders.where((order) {
        return order.customerName.toLowerCase().contains(_searchQuery) ||
            order.email.toLowerCase().contains(_searchQuery) ||
            order.phone.contains(_searchQuery);
      }).toList();
    }
  }

  List<models.Order> _getOrdersForStage(String stageId) {
    return _filteredOrders
        .where((order) => order.currentStage == stageId)
        .toList();
  }

  Future<void> _moveOrderToStage(models.Order order, String newStageId) async {
    final newStage = _stages.firstWhere((s) => s.id == newStageId);
    final oldStage = _stages.firstWhere((s) => s.id == order.currentStage);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move ${order.customerName}'),
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
      ),
    );

    if (confirmed == true) {
      try {
        await _orderService.moveOrderToStage(
          orderId: order.id,
          newStage: newStageId,
          note: noteController.text.isEmpty
              ? 'Moved to ${newStage.name}'
              : noteController.text,
          userId: userId,
          userName: userName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${order.customerName} moved to ${newStage.name}'),
            ),
          );

          // Show success message if converted to support ticket
          if (newStageId == 'installed') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order converted to Support ticket!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error moving order: $e')));
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
    final totalOrders = _filteredOrders.length;

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
                'Operations Stream',
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
                    hintText: 'Search orders...',
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
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalOrders orders',
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
            'Orders from Sales stream',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _stages.map((stage) {
          final orders = _getOrdersForStage(stage.id);
          return _buildStageColumn(stage, orders);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(StreamStage stage, List<models.Order> orders) {
    final sortedOrders = StreamUtils.sortByFormScore(
      orders,
      (order) => order.formScore,
    );
    final tieredOrders = StreamUtils.withTierSeparators(
      sortedOrders,
      (order) => order.formScore,
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
                    '${orders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Orders list with DragTarget
          Expanded(
            child: DragTarget<models.Order>(
              onWillAcceptWithDetails: (details) {
                // Only allow forward movement to next immediate stage
                return StreamUtils.canMoveToStage(
                  details.data.currentStage,
                  stage.id,
                  _stages,
                );
              },
              onAcceptWithDetails: (details) =>
                  _moveOrderToStage(details.data, stage.id),
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
                  child: orders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No orders in ${stage.name.toLowerCase()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tieredOrders.length,
                          itemBuilder: (context, index) {
                            final entry = tieredOrders[index];

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

                            final order = entry.item!;
                            final isFinal = StreamUtils.isFinalStage(
                              order.currentStage,
                              _stages,
                            );
                            final card = _buildOrderCard(order);

                            // Gray out final stage cards
                            final styledCard = isFinal
                                ? Opacity(opacity: 0.6, child: card)
                                : card;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isFinal
                                  ? styledCard // Non-draggable for final stage
                                  : Draggable<models.Order>(
                                      data: order,
                                      feedback: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 280,
                                          child: Opacity(
                                            opacity: 0.8,
                                            child: _buildOrderCard(order),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildOrderCard(order),
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

  Widget _buildOrderCard(models.Order order) {
    return Container(
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
                  order.customerName.isNotEmpty
                      ? order.customerName[0].toUpperCase()
                      : 'O',
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
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      order.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.invoiceNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.receipt, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Invoice: ${order.invoiceNumber}',
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
                order.timeInStageDisplay,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (order.formScore != null) ScoreBadge(score: order.formScore),
              if (order.formScore != null) const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (stageId) => _moveOrderToStage(order, stageId),
                itemBuilder: (context) => _stages
                    .where((s) => s.id != order.currentStage)
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
    );
  }
}
