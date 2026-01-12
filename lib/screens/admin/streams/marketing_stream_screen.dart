import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/leads/lead.dart';
import '../../../models/streams/stream_stage.dart';
import '../../../services/firebase/lead_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/role_manager.dart';
import '../../../utils/stream_utils.dart';
import '../../../widgets/leads/lead_card.dart';
import '../../../widgets/leads/add_lead_dialog.dart';
import '../../../widgets/leads/stage_transition_dialog.dart';
import '../../../widgets/leads/contacted_questionnaire_dialog.dart';
import '../../../widgets/leads/lead_detail_dialog.dart';
import '../../../widgets/leads/booking_stage_transition_dialog.dart';
import '../../../models/leads/lead_channel.dart';
import '../../../models/leads/lead_booking.dart';
import '../../../services/firebase/lead_channel_service.dart';
import '../../../services/firebase/lead_booking_service.dart';

class MarketingStreamScreen extends StatefulWidget {
  const MarketingStreamScreen({super.key});

  @override
  State<MarketingStreamScreen> createState() => _MarketingStreamScreenState();
}

class _MarketingStreamScreenState extends State<MarketingStreamScreen> {
  final LeadService _leadService = LeadService();
  final LeadChannelService _channelService = LeadChannelService();
  final LeadBookingService _bookingService = LeadBookingService();
  final TextEditingController _searchController = TextEditingController();

  LeadChannel? _currentChannel;
  List<Lead> _allLeads = [];
  List<Lead> _filteredLeads = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<StreamStage> _stages = StreamStage.getMarketingStages();

  @override
  void initState() {
    super.initState();
    _initializeChannel();
    _searchController.addListener(_onSearchChanged);
    // Load admin users for assignment feature (Super Admin only)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userRole == UserRole.superAdmin) {
        context.read<AdminProvider>().loadAdminUsers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeChannel() async {
    setState(() => _isLoading = true);
    try {
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
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.userRole;
    final currentUserId = authProvider.user?.uid ?? '';

    // Start with all leads
    var filtered = _allLeads;
    // Marketing Admin see only their assigned leads + unassigned leads
    if (userRole == UserRole.marketingAdmin) {
      filtered = filtered.where((lead) {
        return lead.assignedTo == null || lead.assignedTo == currentUserId;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((lead) {
        return lead.firstName.toLowerCase().contains(_searchQuery) ||
            lead.lastName.toLowerCase().contains(_searchQuery) ||
            lead.email.toLowerCase().contains(_searchQuery) ||
            lead.phone.contains(_searchQuery);
      }).toList();
    }

    _filteredLeads = filtered;
  }

  List<Lead> _getLeadsForStage(String stageId) {
    return _filteredLeads
        .where((lead) => lead.currentStage == stageId)
        .toList();
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
        onAssignmentChanged: () {
          setState(() {
            _filterLeads();
          });
        },
      ),
    );
  }

  Future<void> _showEditLeadDialog(Lead lead) async {
    if (_currentChannel == null) return;

    await showDialog(
      context: context,
      builder: (context) =>
          AddLeadDialog(channel: _currentChannel!, existingLead: lead),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting lead: $e')));
        }
      }
    }
  }

  Future<void> _moveLeadToStage(Lead lead, String newStageId) async {
    if (_currentChannel == null) return;

    final newStage = _stages.firstWhere((s) => s.id == newStageId);
    final oldStage = _stages.firstWhere((s) => s.id == lead.currentStage);

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
            if (lead.followUpWeek != null)
              'Follow-up Week ${lead.followUpWeek}',
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
                'Booking created for ${bookingResult.bookingDate.day}/${bookingResult.bookingDate.month} at ${bookingResult.bookingTime}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating booking: $e')));
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

    if (result != null) {
      try {
        // Get user role to determine if assignment should happen
        final userRole = authProvider.userRole;
        // Only assign if user is a Marketing Admin (not Super Admin or Country Admin)
        final shouldAssign = userRole == UserRole.marketingAdmin;

        await _leadService.moveLeadToStage(
          leadId: lead.id,
          newStage: newStageId,
          note: result.note,
          userId: userId,
          userName: userName,
          isFollowUpStage: newStage.id == 'follow_up',
          assignedTo: shouldAssign ? userId : null,
          assignedToName: shouldAssign ? userName : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lead.fullName} moved to ${newStage.name}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error moving lead: $e')));
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
    final totalLeads = _filteredLeads.length;

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
                'Marketing Stream',
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
                    hintText: 'Search leads by name, email, or phone...',
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
              // Lead count badge
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
                      Icons.people_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalLeads leads',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Add Lead button
              ElevatedButton.icon(
                onPressed: _showAddLeadDialog,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Lead'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'All new leads enter in Marketing',
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
          final leads = _getLeadsForStage(stage.id);
          return _buildStageColumn(stage, leads);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(StreamStage stage, List<Lead> leads) {
    final sortedLeads = StreamUtils.sortByFormScore(
      leads,
      (lead) => lead.formScore,
    );
    final tieredLeads = StreamUtils.withTierSeparators<Lead>(
      sortedLeads,
      (lead) => lead.formScore,
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
                    '${leads.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Leads list with DragTarget
          Expanded(
            child: DragTarget<Lead>(
              onWillAcceptWithDetails: (details) {
                // Only allow forward movement to next immediate stage
                return StreamUtils.canMoveToStage(
                  details.data.currentStage,
                  stage.id,
                  _stages,
                );
              },
              onAcceptWithDetails: (details) =>
                  _moveLeadToStage(details.data, stage.id),
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
                  child: leads.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No leads in ${stage.name.toLowerCase()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tieredLeads.length,
                          itemBuilder: (context, index) {
                            final entry = tieredLeads[index];

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

                            final lead = entry.item!;
                            final isFinal = StreamUtils.isFinalStage(
                              lead.currentStage,
                              _stages,
                            );
                            final leadCard = LeadCard(
                              lead: lead,
                              onTap: () => _showLeadDetail(lead),
                              isFollowUpStage: stage.id == 'follow_up',
                            );

                            // Gray out final stage cards
                            final styledCard = isFinal
                                ? Opacity(opacity: 0.6, child: leadCard)
                                : leadCard;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isFinal
                                  ? styledCard // Non-draggable for final stage
                                  : Draggable<Lead>(
                                      data: lead,
                                      feedback: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 280,
                                          child: Opacity(
                                            opacity: 0.8,
                                            child: LeadCard(
                                              lead: lead,
                                              onTap: () {},
                                              isFollowUpStage: false,
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: LeadCard(
                                          lead: lead,
                                          onTap: () {},
                                          isFollowUpStage:
                                              stage.id == 'follow_up',
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
}
