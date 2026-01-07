import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/streams/appointment.dart';
import '../../models/streams/stream_stage.dart';
import '../../models/admin/admin_user.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/firebase/sales_appointment_service.dart';
import '../../utils/role_manager.dart';
import 'contract_section_widget.dart';
import 'ready_for_ops_badge.dart';

/// Dialog for viewing full appointment details and history
class AppointmentDetailDialog extends StatefulWidget {
  final SalesAppointment appointment;
  final List<StreamStage> stages;
  final VoidCallback? onAssignmentChanged;
  final VoidCallback? onDeleted;

  const AppointmentDetailDialog({
    super.key,
    required this.appointment,
    required this.stages,
    this.onAssignmentChanged,
    this.onDeleted,
  });

  @override
  State<AppointmentDetailDialog> createState() =>
      _AppointmentDetailDialogState();
}

class _AppointmentDetailDialogState extends State<AppointmentDetailDialog> {
  late SalesAppointment _currentAppointment;
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  String? _selectedAssignedTo;
  bool _isSavingAssignment = false;
  bool _isDeleting = false;
  List<AdminUser> _salesAdmins = [];

  @override
  void initState() {
    super.initState();
    _currentAppointment = widget.appointment;
    _selectedAssignedTo = widget.appointment.assignedTo;
    _loadSalesAdmins();
  }

  void _loadSalesAdmins() {
    final adminProvider = context.read<AdminProvider>();
    // Filter to only active sales admin users
    final filtered = adminProvider.adminUsers
        .where(
          (user) =>
              user.role == AdminRole.sales &&
              user.status == AdminUserStatus.active,
        )
        .toList();

    if (mounted) {
      setState(() {
        _salesAdmins = filtered;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload sales admins when AdminProvider updates
    final adminProvider = context.watch<AdminProvider>();
    if (adminProvider.adminUsers.isNotEmpty) {
      _loadSalesAdmins();
    }
  }

  Future<void> _updateAssignment(
    String? assignedTo,
    String? assignedToName,
  ) async {
    if (_isSavingAssignment) return;

    setState(() => _isSavingAssignment = true);

    try {
      await _appointmentService.updateAppointmentAssignment(
        appointmentId: _currentAppointment.id,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
      );

      // Update local appointment state
      setState(() {
        _currentAppointment = _currentAppointment.copyWith(
          assignedTo: assignedTo,
          assignedToName: assignedToName,
        );
        _selectedAssignedTo = assignedTo;
      });

      // Notify parent to refresh appointments
      if (widget.onAssignmentChanged != null) {
        widget.onAssignmentChanged!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assignedToName != null
                  ? 'Appointment assigned to $assignedToName'
                  : 'Appointment assignment removed',
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
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      _currentAppointment.customerName.isNotEmpty
                          ? _currentAppointment.customerName[0].toUpperCase()
                          : 'A',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAppointment.customerName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current Stage: ${_getStageName(_currentAppointment.currentStage)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Ready For Ops Badge (for Deposit Made stage)
            if (_currentAppointment.currentStage == 'deposit_made')
              Padding(
                padding: const EdgeInsets.all(16),
                child: ReadyForOpsBadge(
                  appointment: _currentAppointment,
                  isCompact: false,
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
                      _buildInfoRow(
                        Icons.email,
                        'Email',
                        _currentAppointment.email,
                      ),
                      _buildInfoRow(
                        Icons.phone,
                        'Phone',
                        _currentAppointment.phone,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Current Status
                    _buildSection('Current Status', Icons.info_outline, [
                      _buildInfoRow(
                        Icons.access_time,
                        'Time in Stage',
                        _formatDuration(_currentAppointment.timeInStage),
                      ),
                      _buildInfoRow(
                        Icons.person,
                        'Created By',
                        _currentAppointment.createdByName ?? 'Unknown',
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Assignment Section
                    _buildAssignmentSection(),
                    const SizedBox(height: 24),

                    // Appointment Information
                    if (_currentAppointment.appointmentDate != null ||
                        _currentAppointment.appointmentTime != null)
                      _buildSection(
                        'Appointment Details',
                        Icons.calendar_today,
                        [
                          if (_currentAppointment.appointmentDate != null)
                            _buildInfoRow(
                              Icons.event,
                              'Appointment Date',
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(_currentAppointment.appointmentDate!),
                            ),
                          if (_currentAppointment.appointmentTime != null)
                            _buildInfoRow(
                              Icons.schedule,
                              'Appointment Time',
                              _currentAppointment.appointmentTime!,
                            ),
                        ],
                      ),
                    if (_currentAppointment.appointmentDate != null ||
                        _currentAppointment.appointmentTime != null)
                      const SizedBox(height: 24),

                    // Deposit Information
                    if (_currentAppointment.depositAmount != null ||
                        _currentAppointment.depositPaid)
                      _buildSection('Deposit Information', Icons.payments, [
                        if (_currentAppointment.depositAmount != null)
                          _buildInfoRow(
                            Icons.account_balance_wallet,
                            'Deposit Amount',
                            'R ${_currentAppointment.depositAmount!.toStringAsFixed(2)}',
                          ),
                        _buildInfoRow(
                          Icons.check_circle,
                          'Deposit Paid',
                          _currentAppointment.depositPaid ? 'Yes' : 'No',
                        ),
                      ]),
                    if (_currentAppointment.depositAmount != null ||
                        _currentAppointment.depositPaid)
                      const SizedBox(height: 24),

                    // Opt In Products (whenever present)
                    if (_currentAppointment.optInProducts.isNotEmpty ||
                        (_currentAppointment.optInNote?.isNotEmpty ??
                            false)) ...[
                      _buildSection('Opt In Products', Icons.shopping_cart, [
                        if (_currentAppointment.optInProducts.isNotEmpty)
                          _buildOptInProductsList(
                            _currentAppointment.optInProducts,
                          ),
                        if (_currentAppointment.optInNote?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildInfoRow(
                              Icons.sticky_note_2_outlined,
                              'Opt In Note',
                              _currentAppointment.optInNote!,
                            ),
                          ),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Contract Section (for Opt In stage)
                    ContractSectionWidget(
                      appointment: _currentAppointment,
                      onContractGenerated: () {
                        // Refresh appointment data if needed
                      },
                      onContractSigned: () {
                        // Refresh appointment data if needed
                      },
                    ),
                    const SizedBox(height: 24),

                    // Notes (newest first)
                    if (_currentAppointment.notes.isNotEmpty) ...[
                      _buildSection('Notes', Icons.note, [
                        ..._currentAppointment.notes.reversed.map((note) {
                          return _buildNoteEntry(note);
                        }).toList(),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Stage History (newest first)
                    _buildSection('Stage History', Icons.timeline, [
                      ..._currentAppointment.stageHistory.reversed.map((entry) {
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
          // Delete Lead button (left side)
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
            label: Text(_isDeleting ? 'Deleting...' : 'Delete Lead'),
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

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Lead'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('This Sales Appointment'),
            _buildDeleteItem('All related Contracts'),
            _buildDeleteItem('Stage History'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Lead'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteLead();
    }
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.remove_circle, size: 16, color: Colors.red[400]),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _deleteLead() async {
    setState(() => _isDeleting = true);

    try {
      await _appointmentService.deleteAppointment(_currentAppointment.id);

      if (mounted) {
        // Close the dialog first
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lead "${_currentAppointment.customerName}" deleted successfully',
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
            content: Text('Error deleting lead: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
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
                labelText: 'Assign to Sales Admin',
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
                // Sales admin users
                ..._salesAdmins.map((admin) {
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
                  // Assign to selected sales admin
                  final selectedAdmin = _salesAdmins.firstWhere(
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
          _currentAppointment.assignedToName ?? 'Unassigned',
        ),
      ],
    ]);
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptInProductsList(List<OptInProduct> products) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Product',
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
              ...products.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'R ${p.price.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteEntry(SalesAppointmentNote note) {
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

  Widget _buildHistoryEntry(SalesAppointmentStageHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                _getStageName(entry.stage),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(entry.enteredAt),
                style: TextStyle(fontSize: 11, color: Colors.blue[700]),
              ),
            ],
          ),
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.note!,
              style: TextStyle(fontSize: 13, color: Colors.blue[900]),
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
        streamType: StreamType.sales,
      ),
    );
    return stage.name;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }
}
