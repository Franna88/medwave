import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/leads/lead.dart';
import '../../../models/streams/stream_stage.dart';
import '../../../services/firebase/lead_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/leads/lead_card.dart';
import '../../../widgets/leads/add_lead_dialog.dart';
import '../../../widgets/leads/stage_transition_dialog.dart';
import '../../../widgets/leads/contacted_questionnaire_dialog.dart';
import '../../../widgets/leads/lead_detail_dialog.dart';
import '../../../models/leads/lead_channel.dart';
import '../../../services/firebase/lead_channel_service.dart';

class MarketingStreamScreen extends StatefulWidget {
  const MarketingStreamScreen({super.key});

  @override
  State<MarketingStreamScreen> createState() => _MarketingStreamScreenState();
}

class _MarketingStreamScreenState extends State<MarketingStreamScreen> {
  final LeadService _leadService = LeadService();
  final LeadChannelService _channelService = LeadChannelService();
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
        await _leadService.moveLeadToStage(
          leadId: lead.id,
          newStage: newStageId,
          note: result.note,
          userId: userId,
          userName: userName,
          isFollowUpStage: newStage.id == 'follow_up',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lead.fullName} moved to ${newStage.name}'),
            ),
          );

          // Show success message if converted to appointment
          if (newStageId == 'booking') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lead converted to Sales appointment!'),
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
              onWillAcceptWithDetails: (details) =>
                  details.data.currentStage != stage.id,
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
                          itemCount: leads.length,
                          itemBuilder: (context, index) {
                            final lead = leads[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Draggable<Lead>(
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
                                    isFollowUpStage: stage.id == 'follow_up',
                                  ),
                                ),
                                child: LeadCard(
                                  lead: lead,
                                  onTap: () => _showLeadDetail(lead),
                                  isFollowUpStage: stage.id == 'follow_up',
                                ),
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
