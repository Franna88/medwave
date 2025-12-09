import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/leads/lead.dart';
import '../../models/leads/lead_channel.dart';
import '../../models/leads/lead_stage.dart';
import '../../services/firebase/lead_service.dart';
import '../../services/firebase/lead_channel_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/leads/lead_card.dart';
import '../../widgets/leads/followup_drilldown.dart';
import '../../widgets/leads/add_lead_dialog.dart';
import '../../widgets/leads/stage_transition_dialog.dart';
import '../../widgets/leads/contacted_questionnaire_dialog.dart';
import '../../widgets/leads/lead_detail_dialog.dart';
import '../../widgets/leads/followup_week_transition_dialog.dart';
import '../../widgets/leads/booking_stage_transition_dialog.dart';
import '../../widgets/leads/booking_detail_dialog.dart';
import '../../models/leads/lead_booking.dart';
import '../../services/firebase/lead_booking_service.dart';

export '../../widgets/leads/stage_transition_dialog.dart' show StageTransitionResult;

class AdminLeadsScreen extends StatefulWidget {
  const AdminLeadsScreen({super.key});

  @override
  State<AdminLeadsScreen> createState() => _AdminLeadsScreenState();
}

class _AdminLeadsScreenState extends State<AdminLeadsScreen> {
  final LeadService _leadService = LeadService();
  final LeadChannelService _channelService = LeadChannelService();
  final LeadBookingService _bookingService = LeadBookingService();
  final TextEditingController _searchController = TextEditingController();

  LeadChannel? _currentChannel;
  List<Lead> _allLeads = [];
  List<Lead> _filteredLeads = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showTodaysBookings = false;

  @override
  void initState() {
    super.initState();
    _initializeChannel();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeChannel() async {
    setState(() => _isLoading = true);
    try {
      // Initialize default channel if it doesn't exist
      final channel = await _channelService.initializeDefaultChannel();
      setState(() {
        _currentChannel = channel;
      });
      _loadLeads();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing channel: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _loadLeads() {
    if (_currentChannel == null) return;

    _leadService.leadsStream(_currentChannel!.id).listen((leads) {
      setState(() {
        _allLeads = leads;
        _filterLeads();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterLeads();
    });
  }

  void _filterLeads() {
    if (_searchQuery.isEmpty) {
      _filteredLeads = _allLeads;
    } else {
      _filteredLeads = _allLeads.where((lead) {
        return lead.firstName.toLowerCase().contains(_searchQuery) ||
            lead.lastName.toLowerCase().contains(_searchQuery) ||
            lead.email.toLowerCase().contains(_searchQuery) ||
            lead.phone.contains(_searchQuery);
      }).toList();
    }
  }

  List<Lead> _getLeadsForStage(String stageId) {
    return _filteredLeads.where((lead) => lead.currentStage == stageId).toList();
  }

  Future<void> _showAddLeadDialog() async {
    if (_currentChannel == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddLeadDialog(channel: _currentChannel!),
    );

    if (result == true) {
      // Leads will auto-update via stream
    }
  }

  Future<void> _showLeadDetail(Lead lead) async {
    if (_currentChannel == null) return;

    await showDialog(
      context: context,
      builder: (context) => LeadDetailDialog(
        lead: lead,
        channel: _currentChannel!,
        onEdit: () => _showEditLeadDialog(lead),
        onDelete: () => _confirmDeleteLead(lead),
      ),
    );
  }

  Future<void> _showEditLeadDialog(Lead lead) async {
    if (_currentChannel == null) return;

    await showDialog(
      context: context,
      builder: (context) => AddLeadDialog(
        channel: _currentChannel!,
        existingLead: lead,
      ),
    );
  }

  Future<void> _confirmDeleteLead(Lead lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete ${lead.fullName}?'),
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
        await _leadService.deleteLead(lead.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting lead: $e')),
          );
        }
      }
    }
  }

  Future<void> _moveLeadToStage(Lead lead, String newStageId) async {
    if (_currentChannel == null) return;

    final newStage = _currentChannel!.getStageById(newStageId);
    final oldStage = _currentChannel!.getStageById(lead.currentStage);

    if (newStage == null || oldStage == null) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    // Check if this is the Booking stage
    if (newStageId == 'booking') {
      // Show booking calendar dialog
      final bookingResult = await showDialog<BookingTransitionResult>(
        context: context,
        builder: (context) => BookingStageTransitionDialog(
          lead: lead,
          newStageName: newStage.name,
        ),
      );

      if (bookingResult == null) return; // User cancelled

      try {
        // Create the booking
        final booking = LeadBooking(
          id: '', // Will be set by Firestore
          leadId: lead.id,
          leadName: lead.fullName,
          leadEmail: lead.email,
          leadPhone: lead.phone,
          bookingDate: bookingResult.bookingDate,
          bookingTime: bookingResult.bookingTime,
          duration: bookingResult.duration,
          status: BookingStatus.scheduled,
          createdBy: userId,
          createdByName: userName,
          createdAt: DateTime.now(),
          leadSource: lead.source,
          leadHistory: [
            'Lead Created',
            'Contacted',
            if (lead.followUpWeek != null) 'Follow-up Week ${lead.followUpWeek}',
            'Booking Scheduled',
          ],
          aiPrompts: AICallPrompts.getDefault(),
          assignedTo: bookingResult.assignedTo,
          assignedToName: bookingResult.assignedToName,
        );

        final bookingId = await _bookingService.createBooking(booking);

        // Move lead to Booking stage with booking info
        await _leadService.moveLeadToStage(
          leadId: lead.id,
          newStage: newStageId,
          note: bookingResult.note,
          userId: userId,
          userName: userName,
          isFollowUpStage: false,
          bookingId: bookingId,
          bookingDate: bookingResult.bookingDate,
          bookingStatus: 'scheduled',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Booking created for ${bookingResult.bookingDate.day}/${bookingResult.bookingDate.month} at ${bookingResult.bookingTime}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating booking: $e')),
          );
        }
      }
      return;
    }

    // Show questionnaire dialog for Contacted stage, regular dialog for others
    final result = await showDialog<StageTransitionResult>(
      context: context,
      builder: (context) {
        if (newStageId == 'contacted') {
          return ContactedQuestionnaireDialog(
            fromStage: oldStage.name,
            toStage: newStage.name,
          );
        } else {
          return StageTransitionDialog(
            fromStage: oldStage.name,
            toStage: newStage.name,
            toStageId: newStageId,
          );
        }
      },
    );

    if (result == null) return; // User cancelled

    try {
      await _leadService.moveLeadToStage(
        leadId: lead.id,
        newStage: newStageId,
        note: result.note,
        userId: userId,
        userName: userName,
        isFollowUpStage: newStage.isFollowUpStage,
        amount: result.amount,
        invoiceNumber: result.invoiceNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lead.fullName} moved to ${newStage.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving lead: $e')),
        );
      }
    }
  }

  Future<void> _updateFollowUpWeek(Lead lead, int newWeek) async {
    final currentWeek = lead.followUpWeek ?? 1;
    
    // Show transition dialog
    final result = await showDialog<FollowUpWeekTransitionResult>(
      context: context,
      builder: (context) => FollowUpWeekTransitionDialog(
        leadName: lead.fullName,
        fromWeek: currentWeek,
        toWeek: newWeek,
      ),
    );

    if (result == null) return; // User cancelled

    // Get auth provider before async operations
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    try {

      // Build the note text
      final noteText = result.additionalNote != null && result.additionalNote!.isNotEmpty
          ? '${result.reason} - ${result.additionalNote}'
          : result.reason;

      await _leadService.updateFollowUpWeekWithNote(
        leadId: lead.id,
        newWeek: newWeek,
        note: noteText,
        userId: userId,
        userName: userName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lead.fullName} moved to Week $newWeek')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating week: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentChannel == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load channel',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeChannel,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildTodaysBookingsSection(),
          Expanded(child: _buildKanbanBoard()),
        ],
      ),
    );
  }

  Widget _buildTodaysBookingsSection() {
    return StreamBuilder<List<LeadBooking>>(
      stream: _bookingService.bookingsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final today = DateTime.now();
        final todaysBookings = snapshot.data!.where((booking) {
          return booking.bookingDate.year == today.year &&
              booking.bookingDate.month == today.month &&
              booking.bookingDate.day == today.day;
        }).toList();

        if (todaysBookings.isEmpty) return const SizedBox();

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _showTodaysBookings = !_showTodaysBookings;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Today's Bookings",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${todaysBookings.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showTodaysBookings
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              if (_showTodaysBookings) ...[
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: todaysBookings.map((booking) {
                      return _buildBookingCard(booking);
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(LeadBooking booking) {
    return InkWell(
      onTap: () => _showBookingDetail(booking),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: _getBookingStatusColor(booking.status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.leadName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${booking.formattedTime} (${booking.duration}m)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        booking.leadPhone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getBookingStatusColor(booking.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                booking.status.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getBookingStatusColor(booking.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBookingStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.scheduled:
        return AppTheme.primaryColor;
      case BookingStatus.completed:
        return AppTheme.successColor;
      case BookingStatus.cancelled:
        return AppTheme.errorColor;
      case BookingStatus.noShow:
        return AppTheme.warningColor;
    }
  }

  Future<void> _showBookingDetail(LeadBooking booking) async {
    await showDialog(
      context: context,
      builder: (context) => BookingDetailDialog(
        booking: booking,
        onBookingUpdated: (updatedBooking) {
          // Refresh handled by stream
        },
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
                  'Leads',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Channel: ${_currentChannel?.name ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddLeadDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Lead'),
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search leads by name, email, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.people, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '${_filteredLeads.length} leads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard() {
    if (_filteredLeads.isEmpty && _searchQuery.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredLeads.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No leads found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _currentChannel!.stages.map((stage) {
          return _buildStageColumn(stage);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(LeadStage stage) {
    final leadsInStage = _getLeadsForStage(stage.id);
    final stageColor = Color(int.parse(stage.color.replaceFirst('#', '0xFF')));

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: stageColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: stageColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stage.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: stageColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stageColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${leadsInStage.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stage content
          Expanded(
            child: DragTarget<Lead>(
              onWillAccept: (lead) => lead?.currentStage != stage.id,
              onAccept: (lead) => _moveLeadToStage(lead, stage.id),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? stageColor.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? stageColor
                          : Colors.grey[200]!,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                  ),
                  child: stage.isFollowUpStage
                      ? _buildFollowUpColumn(leadsInStage)
                      : _buildRegularColumn(leadsInStage),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularColumn(List<Lead> leads) {
    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No leads',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return Draggable<Lead>(
          data: lead,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 280,
              child: Opacity(
                opacity: 0.8,
                child: LeadCard(
                  lead: lead,
                  onTap: () {},
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: LeadCard(
              lead: lead,
              onTap: () {},
            ),
          ),
          child: LeadCard(
            lead: lead,
            onTap: () => _showLeadDetail(lead),
          ),
        );
      },
    );
  }

  Widget _buildFollowUpColumn(List<Lead> leads) {
    if (leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No leads in follow-up',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: FollowUpDrilldown(
        leads: leads,
        onLeadTap: _showLeadDetail,
        onWeekChange: _updateFollowUpWeek,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No leads yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first lead to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddLeadDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Lead'),
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
}

