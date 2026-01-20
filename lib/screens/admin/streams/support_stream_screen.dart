import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/streams/support_ticket.dart';
import '../../../models/streams/stream_stage.dart';
import '../../../services/firebase/support_ticket_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/stream_utils.dart';
import '../../../widgets/common/score_badge.dart';
import '../../../widgets/support/support_ticket_detail_dialog.dart';

class SupportStreamScreen extends StatefulWidget {
  const SupportStreamScreen({super.key});

  @override
  State<SupportStreamScreen> createState() => _SupportStreamScreenState();
}

class _SupportStreamScreenState extends State<SupportStreamScreen> {
  final SupportTicketService _ticketService = SupportTicketService();
  final TextEditingController _searchController = TextEditingController();

  List<SupportTicket> _allTickets = [];
  List<SupportTicket> _filteredTickets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<StreamStage> _stages = StreamStage.getSupportStages();

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTickets() {
    _ticketService.ticketsStream().listen((tickets) {
      setState(() {
        _allTickets = tickets;
        _filterTickets();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterTickets();
    });
  }

  void _filterTickets() {
    if (_searchQuery.isEmpty) {
      _filteredTickets = _allTickets;
    } else {
      _filteredTickets = _allTickets.where((ticket) {
        return ticket.customerName.toLowerCase().contains(_searchQuery) ||
            ticket.email.toLowerCase().contains(_searchQuery) ||
            ticket.phone.contains(_searchQuery);
      }).toList();
    }
  }

  List<SupportTicket> _getTicketsForStage(String stageId) {
    return _filteredTickets
        .where((ticket) => ticket.currentStage == stageId)
        .toList();
  }

  Future<void> _moveTicketToStage(
    SupportTicket ticket,
    String newStageId,
  ) async {
    final newStage = _stages.firstWhere((s) => s.id == newStageId);
    final oldStage = _stages.firstWhere((s) => s.id == ticket.currentStage);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move ${ticket.customerName}'),
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
        await _ticketService.moveTicketToStage(
          ticketId: ticket.id,
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
              content: Text('${ticket.customerName} moved to ${newStage.name}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error moving ticket: $e')));
        }
      }
    }
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

  Future<void> _showTicketDetail(SupportTicket ticket) async {
    await showDialog(
      context: context,
      builder: (context) => SupportTicketDetailDialog(
        ticket: ticket,
        stages: _stages,
        onDeleted: () {
          // Refresh tickets list after deletion
          _loadTickets();
        },
        onUpdated: () {
          // Refresh tickets list after update
          _loadTickets();
        },
      ),
    );
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
    final totalTickets = _filteredTickets.length;

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
                'Support Stream',
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
                    hintText: 'Search tickets...',
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
                      Icons.support_agent,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalTickets tickets',
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
            'Support tickets from Operations stream',
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
          final tickets = _getTicketsForStage(stage.id);
          return _buildStageColumn(stage, tickets);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(StreamStage stage, List<SupportTicket> tickets) {
    final sortedTickets = StreamUtils.sortByFormScore(
      tickets,
      (ticket) => ticket.formScore,
    );
    final tieredTickets = StreamUtils.withTierSeparators(
      sortedTickets,
      (ticket) => ticket.formScore,
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
                    '${tickets.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tickets list with DragTarget
          Expanded(
            child: DragTarget<SupportTicket>(
              onWillAcceptWithDetails: (details) {
                // Only allow forward movement to next immediate stage
                return StreamUtils.canMoveToStage(
                  details.data.currentStage,
                  stage.id,
                  _stages,
                );
              },
              onAcceptWithDetails: (details) =>
                  _moveTicketToStage(details.data, stage.id),
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
                  child: tickets.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No tickets in ${stage.name.toLowerCase()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tieredTickets.length,
                          itemBuilder: (context, index) {
                            final entry = tieredTickets[index];

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

                            final ticket = entry.item!;
                            final isFinal = StreamUtils.isFinalStage(
                              ticket.currentStage,
                              _stages,
                            );
                            final card = _buildTicketCard(ticket);

                            // Gray out final stage cards
                            final styledCard = isFinal
                                ? Opacity(opacity: 0.6, child: card)
                                : card;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isFinal
                                  ? styledCard // Non-draggable for final stage
                                  : Draggable<SupportTicket>(
                                      data: ticket,
                                      feedback: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 280,
                                          child: Opacity(
                                            opacity: 0.8,
                                            child: _buildTicketCard(ticket),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildTicketCard(ticket),
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

  Widget _buildTicketCard(SupportTicket ticket) {
    return InkWell(
      onTap: () => _showTicketDetail(ticket),
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
                    ticket.customerName.isNotEmpty
                        ? ticket.customerName[0].toUpperCase()
                        : 'S',
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
                        ticket.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ticket.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(ticket.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPriorityColor(
                        ticket.priority,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    ticket.priorityDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(ticket.priority),
                    ),
                  ),
                ),
              ],
            ),
            if (ticket.issueDescription != null &&
                ticket.issueDescription!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ticket.issueDescription!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  ticket.timeInStageDisplay,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (ticket.formScore != null)
                  ScoreBadge(score: ticket.formScore),
                if (ticket.formScore != null) const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  onSelected: (stageId) => _moveTicketToStage(ticket, stageId),
                  itemBuilder: (context) => _stages
                      .where((s) => s.id != ticket.currentStage)
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
