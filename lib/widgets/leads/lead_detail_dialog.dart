import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/leads/lead.dart';
import '../../models/leads/lead_channel.dart';
import '../../models/admin/admin_user.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/firebase/lead_service.dart';
import '../../utils/role_manager.dart';

/// Dialog for viewing full lead details and history
class LeadDetailDialog extends StatefulWidget {
  final Lead lead;
  final LeadChannel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAssignmentChanged;

  const LeadDetailDialog({
    super.key,
    required this.lead,
    required this.channel,
    required this.onEdit,
    required this.onDelete,
    this.onAssignmentChanged,
  });

  @override
  State<LeadDetailDialog> createState() => _LeadDetailDialogState();
}

class _LeadDetailDialogState extends State<LeadDetailDialog> {
  late Lead _currentLead;
  final LeadService _leadService = LeadService();
  String? _selectedAssignedTo;
  bool _isSavingAssignment = false;
  List<AdminUser> _marketingAdmins = [];

  @override
  void initState() {
    super.initState();
    _currentLead = widget.lead;
    _selectedAssignedTo = widget.lead.assignedTo;
    _loadMarketingAdmins();
  }

  void _loadMarketingAdmins() {
    final adminProvider = context.read<AdminProvider>();
    // Filter to only active marketing admin users
    final filtered = adminProvider.adminUsers
        .where(
          (user) =>
              user.role == AdminRole.marketing &&
              user.status == AdminUserStatus.active,
        )
        .toList();

    if (mounted) {
      setState(() {
        _marketingAdmins = filtered;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload marketing admins when AdminProvider updates
    final adminProvider = context.watch<AdminProvider>();
    if (adminProvider.adminUsers.isNotEmpty) {
      _loadMarketingAdmins();
    }
  }

  Future<void> _updateAssignment(
    String? assignedTo,
    String? assignedToName,
  ) async {
    if (_isSavingAssignment) return;

    setState(() => _isSavingAssignment = true);

    try {
      await _leadService.updateLeadAssignment(
        leadId: _currentLead.id,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
      );

      // Update local lead state
      setState(() {
        _currentLead = _currentLead.copyWith(
          assignedTo: assignedTo,
          assignedToName: assignedToName,
        );
        _selectedAssignedTo = assignedTo;
      });

      // Notify parent to refresh leads
      if (widget.onAssignmentChanged != null) {
        widget.onAssignmentChanged!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assignedToName != null
                  ? 'Lead assigned to $assignedToName'
                  : 'Lead assignment removed',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingAssignment = false);
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      _currentLead.initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentLead.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current Stage: ${_getStageName(_currentLead.currentStage)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
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
                    // Contact Information
                    _buildSection('Contact Information', Icons.contact_mail, [
                      _buildInfoRow(Icons.email, 'Email', _currentLead.email),
                      _buildInfoRow(Icons.phone, 'Phone', _currentLead.phone),
                      if (_currentLead.source.isNotEmpty)
                        _buildInfoRow(
                          Icons.source,
                          'Source',
                          _currentLead.source,
                        ),
                    ]),
                    const SizedBox(height: 24),

                    // UTM Tracking Information (if available)
                    if (_currentLead.utmCampaign != null ||
                        _currentLead.utmAdset != null ||
                        _currentLead.utmAd != null)
                      _buildSection('Campaign Tracking', Icons.track_changes, [
                        if (_currentLead.utmCampaign != null)
                          _buildInfoRow(
                            Icons.campaign,
                            'Campaign',
                            _currentLead.utmCampaign!,
                          ),
                        if (_currentLead.utmAdset != null)
                          _buildInfoRow(
                            Icons.group_work,
                            'Ad Set',
                            _currentLead.utmAdset!,
                          ),
                        if (_currentLead.utmAd != null)
                          _buildInfoRow(
                            Icons.image,
                            'Ad Name',
                            _currentLead.utmAd!,
                          ),
                        if (_currentLead.utmSource != null)
                          _buildInfoRow(
                            Icons.source,
                            'UTM Source',
                            _currentLead.utmSource!,
                          ),
                        if (_currentLead.utmMedium != null)
                          _buildInfoRow(
                            Icons.trending_up,
                            'UTM Medium',
                            _currentLead.utmMedium!,
                          ),
                      ]),
                    if (_currentLead.utmCampaign != null ||
                        _currentLead.utmAdset != null ||
                        _currentLead.utmAd != null)
                      const SizedBox(height: 24),

                    // Current Status
                    _buildSection('Current Status', Icons.info_outline, [
                      _buildInfoRow(
                        Icons.access_time,
                        'Time in Stage',
                        _formatDuration(_currentLead.timeInStage),
                      ),
                      if (_currentLead.followUpWeek != null)
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Follow-up Week',
                          'Week ${_currentLead.followUpWeek}',
                        ),
                      _buildInfoRow(
                        Icons.person,
                        'Created By',
                        _currentLead.createdByName ?? 'Unknown',
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Assignment Section
                    _buildAssignmentSection(),
                    const SizedBox(height: 24),

                    // Booking Information
                    if (_currentLead.bookingId != null)
                      _buildSection(
                        'Booking Information',
                        Icons.calendar_today,
                        [
                          if (_currentLead.bookingDate != null)
                            _buildInfoRow(
                              Icons.event,
                              'Booking Date',
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(_currentLead.bookingDate!),
                            ),
                          if (_currentLead.bookingStatus != null)
                            _buildInfoRow(
                              Icons.info,
                              'Status',
                              _currentLead.bookingStatus!.toUpperCase(),
                            ),
                          _buildInfoRow(
                            Icons.link,
                            'Booking ID',
                            _currentLead.bookingId!,
                          ),
                        ],
                      ),
                    if (_currentLead.bookingId != null)
                      const SizedBox(height: 24),

                    // Payment Information
                    if (_currentLead.depositAmount != null ||
                        _currentLead.cashCollectedAmount != null)
                      _buildSection('Payment Information', Icons.payments, [
                        if (_currentLead.depositAmount != null) ...[
                          _buildInfoRow(
                            Icons.account_balance_wallet,
                            'Deposit Amount',
                            'R ${_currentLead.depositAmount!.toStringAsFixed(2)}',
                          ),
                          if (_currentLead.depositInvoiceNumber != null)
                            _buildInfoRow(
                              Icons.receipt,
                              'Deposit Invoice',
                              _currentLead.depositInvoiceNumber!,
                            ),
                        ],
                        if (_currentLead.cashCollectedAmount != null) ...[
                          _buildInfoRow(
                            Icons.money,
                            'Cash Collected',
                            'R ${_currentLead.cashCollectedAmount!.toStringAsFixed(2)}',
                          ),
                          if (_currentLead.cashCollectedInvoiceNumber != null)
                            _buildInfoRow(
                              Icons.receipt_long,
                              'Cash Invoice',
                              _currentLead.cashCollectedInvoiceNumber!,
                            ),
                        ],
                      ]),
                    if (_currentLead.depositAmount != null ||
                        _currentLead.cashCollectedAmount != null)
                      const SizedBox(height: 24),

                    // Notes (newest first)
                    if (_currentLead.notes.isNotEmpty) ...[
                      _buildSection('Notes', Icons.note, [
                        ..._currentLead.notes.reversed.map((note) {
                          return _buildNoteEntry(note);
                        }).toList(),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Stage History (newest first)
                    _buildSection('Stage History', Icons.timeline, [
                      ..._currentLead.stageHistory.reversed.map((entry) {
                        return _buildHistoryEntry(entry);
                      }).toList(),
                    ]),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDelete();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Delete Lead',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onEdit();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Lead'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHistoryEntry(StageHistoryEntry entry) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.exitedAt == null
                      ? Colors.green
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStageName(entry.stage),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Entered: ${dateFormat.format(entry.enteredAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (entry.exitedAt != null)
            Text(
              'Exited: ${dateFormat.format(entry.exitedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteEntry(note) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final isWeekTransition =
        note.stageTransition != null && note.stageTransition!.contains('Week');
    final isQuestionnaire = note.isQuestionnaire;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isQuestionnaire
            ? Colors.purple[50]
            : (isWeekTransition ? Colors.orange[50] : Colors.blue[50]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isQuestionnaire
              ? Colors.purple[100]!
              : (isWeekTransition ? Colors.orange[100]! : Colors.blue[100]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isQuestionnaire
                    ? Icons.contact_phone
                    : (isWeekTransition ? Icons.calendar_month : Icons.person),
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                note.createdByName ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(note.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          if (note.stageTransition != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isQuestionnaire
                    ? Colors.purple[100]
                    : (isWeekTransition
                          ? Colors.orange[100]
                          : AppTheme.primaryColor.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWeekTransition ? Icons.event_repeat : Icons.swap_horiz,
                    size: 12,
                    color: isQuestionnaire
                        ? Colors.purple[700]
                        : (isWeekTransition
                              ? Colors.orange[700]
                              : AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    note.stageTransition!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isQuestionnaire
                          ? Colors.purple[700]
                          : (isWeekTransition
                                ? Colors.orange[700]
                                : AppTheme.primaryColor),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Display questionnaire data or regular text
          if (isQuestionnaire) ...[
            // Display as Q&A format
            const Text(
              'Sales Questionnaire:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...note.questionnaireData!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      TextSpan(text: entry.value.toString()),
                    ],
                  ),
                ),
              );
            }).toList(),
          ] else ...[
            // Display regular text note
            Text(note.textAsString, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentSection() {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole;
    final isSuperAdmin = userRole == UserRole.superAdmin;

    return _buildSection('Assignment', Icons.person_outline, [
      if (isSuperAdmin) ...[
        // Editable dropdown for Super Admin
        if (_isSavingAssignment)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Saving assignment...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _selectedAssignedTo,
              decoration: InputDecoration(
                labelText: 'Assign to Marketing Admin',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              items: [
                // Unassigned option
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                // Marketing admin users
                ..._marketingAdmins.map((admin) {
                  return DropdownMenuItem<String>(
                    value: admin.userId,
                    child: Text(admin.fullName),
                  );
                }).toList(),
              ],
              onChanged: (value) async {
                if (value == null) {
                  // Unassign
                  await _updateAssignment(null, null);
                } else {
                  // Assign to selected marketing admin
                  final selectedAdmin = _marketingAdmins.firstWhere(
                    (admin) => admin.userId == value,
                  );
                  await _updateAssignment(
                    selectedAdmin.userId,
                    selectedAdmin.fullName,
                  );
                }
              },
            ),
          ),
      ] else ...[
        // Read-only display for non-Super Admin users
        _buildInfoRow(
          Icons.person,
          'Assigned To',
          _currentLead.assignedToName ?? 'Unassigned',
        ),
      ],
    ]);
  }

  String _getStageName(String stageId) {
    final stage = widget.channel.getStageById(stageId);
    return stage?.name ?? stageId;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    }
  }
}
