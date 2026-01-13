import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/streams/support_ticket.dart';
import '../../models/streams/stream_stage.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/support_ticket_service.dart';
import '../../services/firebase/order_service.dart';
import '../../widgets/orders/order_detail_dialog.dart';

/// Dialog for viewing full support ticket details and history
class SupportTicketDetailDialog extends StatefulWidget {
  final SupportTicket ticket;
  final List<StreamStage> stages;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const SupportTicketDetailDialog({
    super.key,
    required this.ticket,
    required this.stages,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  State<SupportTicketDetailDialog> createState() =>
      _SupportTicketDetailDialogState();
}

class _SupportTicketDetailDialogState extends State<SupportTicketDetailDialog> {
  late SupportTicket _currentTicket;
  final SupportTicketService _ticketService = SupportTicketService();
  final OrderService _orderService = OrderService();
  bool _isDeleting = false;
  bool _isLoadingOrder = false;

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return Colors.green;
      case TicketPriority.medium:
        return Colors.orange;
      case TicketPriority.high:
        return Colors.red;
      case TicketPriority.urgent:
        return Colors.purple;
    }
  }

  Future<void> _viewRelatedOrder() async {
    if (_currentTicket.orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No related order ID found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingOrder = true);

    try {
      final order = await _orderService.getOrder(_currentTicket.orderId);

      if (!mounted) return;

      if (order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Related order not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Open OrderDetailDialog
      await showDialog(
        context: context,
        builder: (context) => OrderDetailDialog(
          order: order,
          onOrderUpdated: () {
            // Refresh ticket if needed
            widget.onUpdated?.call();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Support Ticket'),
        content: Text(
          'Are you sure you want to delete the support ticket for "${_currentTicket.customerName}"? This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTicket();
    }
  }

  Future<void> _deleteTicket() async {
    setState(() => _isDeleting = true);

    try {
      await _ticketService.deleteTicket(_currentTicket.id);

      if (mounted) {
        // Close the dialog first
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Support ticket for "${_currentTicket.customerName}" deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Notify parent to refresh
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support Ticket Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentTicket.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isDeleting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildSection('Customer Information', Icons.person, [
                      _buildInfoRow(Icons.email, 'Email', _currentTicket.email),
                      _buildInfoRow(Icons.phone, 'Phone', _currentTicket.phone),
                      _buildInfoRow(
                        Icons.access_time,
                        'Time in Stage',
                        _currentTicket.timeInStageDisplay,
                      ),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Created',
                        DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(_currentTicket.createdAt),
                      ),
                      _buildInfoRow(
                        Icons.update,
                        'Last Updated',
                        DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(_currentTicket.updatedAt),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Support-Specific Information
                    _buildSection('Ticket Information', Icons.support_agent, [
                      // Priority
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.flag, size: 20, color: Colors.grey[700]),
                            const SizedBox(width: 12),
                            const Text(
                              'Priority:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(
                                  _currentTicket.priority,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getPriorityColor(
                                    _currentTicket.priority,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _currentTicket.priorityDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _getPriorityColor(
                                    _currentTicket.priority,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Current Stage
                      _buildInfoRow(
                        Icons.timeline,
                        'Current Stage',
                        _getStageName(_currentTicket.currentStage),
                      ),
                      // Issue Description
                      if (_currentTicket.issueDescription != null &&
                          _currentTicket.issueDescription!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 20,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Issue Description:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  _currentTicket.issueDescription!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Resolution
                      if (_currentTicket.resolution != null &&
                          _currentTicket.resolution!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Resolution:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[300]!),
                                ),
                                child: Text(
                                  _currentTicket.resolution!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Satisfaction Rating
                      if (_currentTicket.satisfactionRating != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 20,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Satisfaction Rating:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < _currentTicket.satisfactionRating!
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 24,
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_currentTicket.satisfactionRating}/5',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // Related Order Section
                    _buildSection('Related Order', Icons.shopping_bag, [
                      if (_currentTicket.orderId.isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.tag,
                          'Order ID',
                          _currentTicket.orderId,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingOrder
                                ? null
                                : _viewRelatedOrder,
                            icon: _isLoadingOrder
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.open_in_new),
                            label: Text(
                              _isLoadingOrder
                                  ? 'Loading...'
                                  : 'View Related Order',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'No related order',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 24),

                    // Notes (newest first)
                    if (_currentTicket.notes.isNotEmpty) ...[
                      _buildSection('Notes', Icons.note, [
                        ..._currentTicket.notes.reversed.map((note) {
                          return _buildNoteEntry(note);
                        }).toList(),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Stage History (newest first)
                    _buildSection('Stage History', Icons.timeline, [
                      if (_currentTicket.stageHistory.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'No stage history available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ..._currentTicket.stageHistory.reversed.map((entry) {
                          return _buildHistoryEntry(entry);
                        }).toList(),
                    ]),
                  ],
                ),
              ),
            ),
            // Footer with Delete button
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Delete button (left side)
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _showDeleteConfirmation,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.delete_forever, size: 18),
            label: Text(_isDeleting ? 'Deleting...' : 'Delete Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const Spacer(),
          // Close button (right side)
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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
    );
  }

  Widget _buildNoteEntry(TicketNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                note.createdByName ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(note.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(note.text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHistoryEntry(TicketStageHistoryEntry entry) {
    final isCurrentStage = entry.exitedAt == null;
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentStage ? Colors.green[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentStage ? Colors.green[200]! : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCurrentStage ? Colors.green : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStageName(entry.stage),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCurrentStage
                        ? Colors.green[900]
                        : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Entered: ${dateFormat.format(entry.enteredAt)}',
            style: TextStyle(
              fontSize: 12,
              color: isCurrentStage ? Colors.green[700] : Colors.blue[700],
            ),
          ),
          if (entry.exitedAt != null)
            Text(
              'Exited: ${dateFormat.format(entry.exitedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: isCurrentStage ? Colors.green[700] : Colors.blue[700],
              ),
            ),
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.note!,
              style: TextStyle(
                fontSize: 13,
                color: isCurrentStage ? Colors.green[900] : Colors.blue[900],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStageName(String stageId) {
    final stage = widget.stages.firstWhere(
      (s) => s.id == stageId,
      orElse: () => StreamStage(
        id: stageId,
        name: stageId,
        position: 0,
        color: '#2196F3',
        streamType: StreamType.support,
      ),
    );
    return stage.name;
  }
}
