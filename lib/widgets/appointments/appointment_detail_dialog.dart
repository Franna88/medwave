import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/contracts/contract.dart';
import '../../models/streams/appointment.dart';
import '../../models/streams/stream_stage.dart';
import '../../models/admin/admin_user.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/firebase/contract_service.dart';
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
  final ContractService _contractService = ContractService();
  String? _selectedAssignedTo;
  bool _isSavingAssignment = false;
  bool _isDeleting = false;
  List<AdminUser> _salesAdmins = [];
  StreamSubscription<SalesAppointment?>? _appointmentSubscription;

  @override
  void initState() {
    super.initState();
    _currentAppointment = widget.appointment;
    _selectedAssignedTo = widget.appointment.assignedTo;
    _loadSalesAdmins();
    _setupRealtimeUpdates();
  }

  void _setupRealtimeUpdates() {
    // Listen to real-time updates for this appointment
    _appointmentSubscription = _appointmentService
        .getAppointmentStream(_currentAppointment.id)
        .listen((appointment) {
          if (mounted && appointment != null) {
            setState(() {
              _currentAppointment = appointment;
            });
          }
        });
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    super.dispose();
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
                    // Stage checklist (Opt In and onwards) – collapsible dropdown
                    if (_currentAppointment.currentStage == 'opt_in' ||
                        _currentAppointment.currentStage ==
                            'deposit_requested' ||
                        _currentAppointment.currentStage == 'deposit_made') ...[
                      if (_currentAppointment.currentStage == 'opt_in')
                        StreamBuilder<List<Contract>>(
                          stream: _contractService
                              .watchContractsByAppointmentId(
                                _currentAppointment.id,
                              ),
                          builder: (context, snapshot) {
                            return _buildStageChecklistExpansion(
                              child: _buildStageChecklist(
                                contracts: snapshot.data,
                              ),
                            );
                          },
                        )
                      else
                        _buildStageChecklistExpansion(
                          child: _buildStageChecklist(contracts: null),
                        ),
                      const SizedBox(height: 24),
                    ],
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
                        _currentAppointment.depositPaid ||
                        (_currentAppointment.customerUploadedProofUrl != null &&
                            _currentAppointment
                                .customerUploadedProofUrl!
                                .isNotEmpty) ||
                        (_currentAppointment.depositProofUrl != null &&
                            _currentAppointment.depositProofUrl!.isNotEmpty))
                      _buildDepositSection(),
                    if (_currentAppointment.depositAmount != null ||
                        _currentAppointment.depositPaid ||
                        (_currentAppointment.customerUploadedProofUrl != null &&
                            _currentAppointment
                                .customerUploadedProofUrl!
                                .isNotEmpty) ||
                        (_currentAppointment.depositProofUrl != null &&
                            _currentAppointment.depositProofUrl!.isNotEmpty))
                      const SizedBox(height: 24),

                    // Proof of Payment Upload Section (for deposit_requested stage)
                    if (_currentAppointment.currentStage == 'deposit_requested')
                      _buildProofUploadSection(),
                    if (_currentAppointment.currentStage == 'deposit_requested')
                      const SizedBox(height: 24),

                    // Opt In Products & Questionnaire (show for opt-in stage and all forward stages)
                    if (_isAtOptInOrBeyond()) ...[
                      // Opt In Products (always show for opt-in stage and beyond)
                      _buildSection('Opt In Products', Icons.shopping_cart, [
                        if (_currentAppointment.optInProducts.isNotEmpty)
                          _buildOptInProductsList(
                            _currentAppointment.optInProducts,
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No products selected yet.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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
                      if (_currentAppointment.optInPackages.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSection('Opt In Packages', Icons.inventory, [
                          _buildOptInProductsList(
                            _currentAppointment.optInPackages,
                          ),
                        ]),
                      ],
                      const SizedBox(height: 24),

                      // Opt In Questionnaire (always show for opt-in stage and beyond)
                      _buildSection('Opt-In Questionnaire', Icons.question_answer, [
                        // Show existing data or empty state message
                        if (_currentAppointment.optInQuestions != null &&
                            _currentAppointment.optInQuestions!.isNotEmpty)
                          ..._currentAppointment.optInQuestions!.entries.map((
                            entry,
                          ) {
                            return _buildInfoRow(
                              Icons.check_circle_outline,
                              entry.key,
                              entry.value,
                            );
                          }).toList()
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No questionnaire data yet. Click button below to add.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        // Add/Edit button (always visible for opt-in stage and beyond)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ElevatedButton.icon(
                            onPressed: _showEditQuestionnaireDialog,
                            icon: Icon(
                              (_currentAppointment.optInQuestions == null ||
                                      _currentAppointment
                                          .optInQuestions!
                                          .isEmpty)
                                  ? Icons.add
                                  : Icons.edit,
                              size: 18,
                            ),
                            label: Text(
                              (_currentAppointment.optInQuestions == null ||
                                      _currentAppointment
                                          .optInQuestions!
                                          .isEmpty)
                                  ? 'Add Questionnaire'
                                  : 'Edit Questionnaire',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
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
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _isDeleting ? null : _showAddNoteDialog,
            icon: const Icon(Icons.note_add, size: 18),
            label: const Text('Add Note'),
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

  Future<void> _showAddNoteDialog() async {
    final controller = TextEditingController();
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Note'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter note...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            minLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a note.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (saved == true && mounted) {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        final authProvider = context.read<AuthProvider>();
        final userId = authProvider.user?.uid;
        if (userId == null) return;
        try {
          await _appointmentService.addNote(
            appointmentId: _currentAppointment.id,
            noteText: text,
            userId: userId,
            userName: authProvider.userName,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note added'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add note: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } finally {
      controller.dispose();
    }
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

  Widget _buildDepositSection() {
    final children = <Widget>[
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
    ];

    // Show customer-uploaded proof if exists
    if (_currentAppointment.customerUploadedProofUrl != null &&
        _currentAppointment.customerUploadedProofUrl!.isNotEmpty) {
      final isPdf = _currentAppointment.customerUploadedProofUrl!
          .toLowerCase()
          .contains('.pdf');

      children.addAll([
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Customer Uploaded Proof',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 8),
            if (!_currentAppointment.customerProofVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEEDS VERIFICATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VERIFIED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showProofFile(
            _currentAppointment.customerUploadedProofUrl!,
            isPdf,
          ),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(
                color: _currentAppointment.customerProofVerified
                    ? Colors.green
                    : Colors.orange,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: isPdf
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 64,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PDF Document',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Image.network(
                    _currentAppointment.customerUploadedProofUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (_currentAppointment.customerUploadedProofAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Uploaded by customer on ${DateFormat('MMM dd, yyyy').format(_currentAppointment.customerUploadedProofAt!)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
        if (!_currentAppointment.customerProofVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _verifyCustomerProof,
                  icon: const Icon(Icons.verified),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _rejectCustomerProof,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ] else if (_currentAppointment.customerProofVerifiedByName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Verified by ${_currentAppointment.customerProofVerifiedByName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ]);
    }

    // Add sales-uploaded proof of payment display if uploaded
    if (_currentAppointment.depositProofUrl != null &&
        _currentAppointment.depositProofUrl!.isNotEmpty) {
      final isPdf = _currentAppointment.depositProofUrl!.toLowerCase().contains(
        '.pdf',
      );

      children.addAll([
        const SizedBox(height: 16),
        const Text(
          'Proof of Payment',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () =>
              _showProofFile(_currentAppointment.depositProofUrl!, isPdf),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: isPdf
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 64,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PDF Document',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Image.network(
                    _currentAppointment.depositProofUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (_currentAppointment.depositProofUploadedByName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Uploaded by ${_currentAppointment.depositProofUploadedByName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ]);
    }

    return _buildSection('Deposit Information', Icons.payments, children);
  }

  Widget _buildProofUploadSection() {
    // Only show if:
    // - Sales proof doesn't exist, AND
    // - Customer proof doesn't exist OR customer proof was rejected
    if ((_currentAppointment.depositProofUrl != null &&
            _currentAppointment.depositProofUrl!.isNotEmpty) ||
        (_currentAppointment.customerUploadedProofUrl != null &&
            _currentAppointment.customerUploadedProofUrl!.isNotEmpty &&
            !_currentAppointment.customerProofRejected)) {
      return const SizedBox.shrink();
    }

    return _buildSection('Proof of Payment', Icons.upload_file, [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Colors.teal[700],
            ),
            const SizedBox(height: 12),
            Text(
              'Upload Proof of Payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload an image or PDF document of the deposit proof to automatically move this appointment to Deposit Made.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploadDepositProof,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _uploadDepositProof() async {
    try {
      // 1. Show options to pick image or document
      final sourceType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Proof of Payment'),
          content: const Text('Choose how you want to upload the proof:'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop('image'),
              icon: const Icon(Icons.image),
              label: const Text('Image/Screenshot'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop('document'),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF Document'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (sourceType == null) {
        // User cancelled
        return;
      }

      // 2. Pick file based on selection
      XFile? file;

      if (sourceType == 'image') {
        final ImagePicker picker = ImagePicker();
        file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else if (sourceType == 'document') {
        // Handle PDF selection
        if (kIsWeb) {
          // For web, use HTML input element
          file = await _pickPdfWeb();
        } else {
          // For mobile, show message that PDF support requires additional setup
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'PDF upload is only supported on web. Please select an image instead.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (file == null) {
        // User cancelled
        return;
      }

      // 3. Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uploading proof of payment...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 4. Get current user info
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? '';
      final userName = authProvider.userName ?? 'Unknown';

      // 5. Upload proof and move to deposit_made
      final result = await _appointmentService.uploadDepositProofAndConfirm(
        appointmentId: _currentAppointment.id,
        proofFile: file,
        uploadedBy: userId,
        uploadedByName: userName,
      );

      // 6. Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 7. Show success/error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 8. Close dialog and trigger refresh if successful
      if (result.success && mounted) {
        Navigator.of(context).pop(); // Close detail dialog
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading proof: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _verifyCustomerProof() async {
    // Confirm with dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Proof of Payment'),
        content: const Text(
          'Have you reviewed the customer\'s proof of payment? '
          'This will move the appointment to Deposit Made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verify & Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying proof...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Get user info
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName ?? 'Unknown';

    // Call service
    final result = await _appointmentService.verifySalesDepositProof(
      appointmentId: _currentAppointment.id,
      verifiedBy: userId,
      verifiedByName: userName,
    );

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }

    // Close detail dialog and refresh if successful
    if (result.success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _rejectCustomerProof() async {
    // Show dialog to confirm rejection and get optional reason
    final TextEditingController reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Proof of Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to reject this proof? '
              'The customer will need to upload a valid proof, or you can upload it manually.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Invalid document, not a proof of payment',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Rejecting proof...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Get user info
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName ?? 'Unknown';

    // Call service
    final result = await _appointmentService.rejectCustomerDepositProof(
      appointmentId: _currentAppointment.id,
      rejectedBy: userId,
      rejectedByName: userName,
      rejectionReason: reason.isNotEmpty ? reason : null,
    );

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }

    // The dialog will automatically update via stream subscription
    // No need to close or manually refresh
  }

  Future<XFile?> _pickPdfWeb() async {
    if (!kIsWeb) return null;

    final completer = Completer<XFile?>();
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'application/pdf,.pdf';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);

        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as List<int>;
          final xFile = XFile.fromData(
            Uint8List.fromList(bytes),
            name: file.name,
            mimeType: 'application/pdf',
          );
          completer.complete(xFile);
        });
      } else {
        completer.complete(null);
      }
    });

    // Add timeout to handle cancelled selection
    Future.delayed(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  void _showProofFile(String fileUrl, bool isPdf) {
    if (isPdf) {
      // For PDF, open in a new browser tab or download
      if (kIsWeb) {
        // ignore: avoid_web_libraries_in_flutter
        html.window.open(fileUrl, '_blank');
      } else {
        // For mobile, show dialog with option to open
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Proof of Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[700]),
                const SizedBox(height: 16),
                const Text('Click the button below to view the PDF document.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // On mobile, use url_launcher if needed in future
                  // For now, PDF viewing on mobile requires external app
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
              ),
            ],
          ),
        );
      }
    } else {
      // For images, open in new tab on web (like PDF) for full screen; dialog on mobile
      if (kIsWeb) {
        // ignore: avoid_web_libraries_in_flutter
        html.window.open(fileUrl, '_blank');
      } else {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Proof of Payment'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      fileUrl,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error, size: 48, color: Colors.red),
                                SizedBox(height: 16),
                                Text('Failed to load image'),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Widget _buildStageChecklistExpansion({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.checklist, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Next steps',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStageChecklist({List<Contract>? contracts}) {
    final stage = _currentAppointment.currentStage;
    String title;
    List<({String label, bool done})> items;

    if (stage == 'opt_in') {
      final hasContract = contracts != null && contracts.isNotEmpty;
      final contractSent = _currentAppointment.contractEmailSentAt != null;
      final contractSigned =
          contracts != null &&
          contracts.any((c) => c.status == ContractStatus.signed);

      title = 'To move to Deposit Requested';
      items = [
        (label: 'Generate contract', done: hasContract),
        (label: 'Send contract', done: contractSent),
        (label: 'Customer signs contract', done: contractSigned),
      ];
    } else if (stage == 'deposit_requested') {
      final sent = _currentAppointment.depositConfirmationSentAt != null;
      final customerConfirmed =
          _currentAppointment.depositConfirmationStatus == 'confirmed';
      final proofVerified =
          _currentAppointment.customerProofVerified ||
          (_currentAppointment.depositProofUrl != null &&
              _currentAppointment.depositProofUrl!.isNotEmpty);

      title = 'To move to Deposit Made';
      items = [
        (label: 'Send deposit request', done: sent),
        (
          label: 'Customer confirms they have made the deposit',
          done: customerConfirmed,
        ),
        (label: 'Verify proof of payment', done: proofVerified),
      ];
    } else if (stage == 'deposit_made') {
      final depositConfirmed =
          _currentAppointment.customerProofVerified ||
          (_currentAppointment.depositProofUrl != null &&
              _currentAppointment.depositProofUrl!.isNotEmpty);

      title = 'To Send to Operations';
      items = [
        (label: 'Deposit confirmed', done: depositConfirmed),
        (label: 'Manually drag to Send to Operations', done: false),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return _buildSection(
      title,
      Icons.checklist,
      items.map((item) => _buildChecklistRow(item.label, item.done)).toList(),
    );
  }

  Widget _buildChecklistRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: done ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: done ? Colors.grey[700] : Colors.grey[600],
              ),
            ),
          ),
        ],
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
    final authProvider = context.watch<AuthProvider>();
    final isSuperAdmin = authProvider.userRole == UserRole.superAdmin;

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
                  children: [
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
                      width: 80,
                      child: Text(
                        'Quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isSuperAdmin) ...[
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
                      SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${p.quantity}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSuperAdmin) ...[
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
          Text(
            '${note.text}${note.stageTransition != null ? ' | Moved by ${note.createdByName ?? 'Unknown'}' : (note.createdBy == 'system' ? ' | Added by System' : ' | Added by ${note.createdByName ?? 'Unknown'}')}',
            style: const TextStyle(fontSize: 14),
          ),
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

  /// Check if appointment is at opt_in stage or any stage after it
  bool _isAtOptInOrBeyond() {
    try {
      final optInStage = widget.stages.firstWhere(
        (s) => s.id == 'opt_in',
        orElse: () => StreamStage(
          id: 'opt_in',
          name: 'Opt In',
          position: 0,
          color: '#2196F3',
          streamType: StreamType.sales,
        ),
      );

      final currentStage = widget.stages.firstWhere(
        (s) => s.id == _currentAppointment.currentStage,
        orElse: () => StreamStage(
          id: _currentAppointment.currentStage,
          name: _currentAppointment.currentStage,
          position: 0,
          color: '#2196F3',
          streamType: StreamType.sales,
        ),
      );

      return currentStage.position >= optInStage.position;
    } catch (e) {
      // Fallback: check by stage ID if position comparison fails
      return _currentAppointment.currentStage == 'opt_in' ||
          _currentAppointment.currentStage == 'deposit_requested' ||
          _currentAppointment.currentStage == 'deposit_made' ||
          _currentAppointment.currentStage == 'send_to_operations';
    }
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

  Future<void> _showEditQuestionnaireDialog() async {
    final Map<String, TextEditingController> controllers = {
      'Best phone number': TextEditingController(
        text: _currentAppointment.optInQuestions?['Best phone number'] ?? '',
      ),
      'Name of business': TextEditingController(
        text: _currentAppointment.optInQuestions?['Name of business'] ?? '',
      ),
      'Best email': TextEditingController(
        text: _currentAppointment.optInQuestions?['Best email'] ?? '',
      ),
      'Sales person dealing with': TextEditingController(
        text:
            _currentAppointment.optInQuestions?['Sales person dealing with'] ??
            '',
      ),
      'Shipping address': TextEditingController(
        text: _currentAppointment.optInQuestions?['Shipping address'] ?? '',
      ),
      'Method of payment': TextEditingController(
        text: _currentAppointment.optInQuestions?['Method of payment'] ?? '',
      ),
      'Interested package': TextEditingController(
        text: _currentAppointment.optInQuestions?['Interested package'] ?? '',
      ),
    };

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Opt-In Questionnaire'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              final isRequired = entry.key == 'Shipping address';
              final isMultiline = entry.key == 'Shipping address';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: '${entry.key}${isRequired ? ' *' : ''}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: isMultiline ? 3 : 1,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Build map with only non-empty values
              final answers = <String, String>{};
              controllers.forEach((question, controller) {
                if (controller.text.trim().isNotEmpty) {
                  answers[question] = controller.text.trim();
                }
              });
              Navigator.of(context).pop(answers.isNotEmpty ? answers : null);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Dispose controllers
    controllers.values.forEach((c) => c.dispose());

    if (result != null && mounted) {
      // Update appointment with new questionnaire answers
      await _updateQuestionnaireAnswers(result);
    }
  }

  Future<void> _updateQuestionnaireAnswers(Map<String, String> answers) async {
    if (!mounted) return;

    try {
      // Update the appointment with new questionnaire
      await _appointmentService.updateAppointment(
        _currentAppointment.copyWith(
          optInQuestions: answers,
          updatedAt: DateTime.now(),
        ),
      );

      // Refresh appointment data
      if (!mounted) return;

      final updatedAppointment = await _appointmentService.getAppointment(
        _currentAppointment.id,
      );

      if (!mounted) return;

      if (updatedAppointment != null) {
        setState(() {
          _currentAppointment = updatedAppointment;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questionnaire updated successfully')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating questionnaire: $e')),
      );
    }
  }
}
