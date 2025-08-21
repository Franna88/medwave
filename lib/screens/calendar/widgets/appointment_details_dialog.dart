import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/appointment.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';
import 'complete_appointment_dialog.dart';

class AppointmentDetailsDialog extends StatelessWidget {
  final Appointment appointment;
  final Function(Appointment)? onAppointmentUpdated;
  final VoidCallback? onAppointmentDeleted;

  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
    this.onAppointmentUpdated,
    this.onAppointmentDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _getTypeIcon(appointment.type),
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appointment.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    appointment.type.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: appointment.status.color,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (appointment.canBeModified)
            IconButton(
              onPressed: () => _editAppointment(context),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _showDeleteConfirmation(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (appointment.canBeModified)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.redColor),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and time header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: appointment.status.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: appointment.status.color.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: appointment.status.color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              appointment.status.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (appointment.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ACTIVE NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time and date display
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: appointment.status.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(appointment.startTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: appointment.status.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${appointment.timeRange} (${_formatDuration(appointment.duration)})',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Patient information card
            _buildModernInfoCard(
              title: 'Patient Information',
              icon: Icons.person,
              color: AppTheme.primaryColor,
              children: [
                _buildModernInfoRow(Icons.badge, 'Name', appointment.patientName),
                _buildModernInfoRow(Icons.fingerprint, 'Patient ID', appointment.patientId),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewPatientProfile(context),
                    icon: const Icon(Icons.person_search, size: 18),
                    label: const Text('View Patient Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Location and practitioner card
            if (appointment.location != null || appointment.practitionerName != null) ...[
              _buildModernInfoCard(
                title: 'Appointment Details',
                icon: Icons.info_outline,
                color: AppTheme.greenColor,
                children: [
                  if (appointment.location != null)
                    _buildModernInfoRow(Icons.location_on, 'Location', appointment.location!),
                  if (appointment.practitionerName != null)
                    _buildModernInfoRow(Icons.medical_services, 'Practitioner', appointment.practitionerName!),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // Description card
            if (appointment.description != null && appointment.description!.isNotEmpty) ...[
              _buildModernInfoCard(
                title: 'Description',
                icon: Icons.description,
                color: AppTheme.pinkColor,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      appointment.description!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // Notes card
            if (appointment.notes.isNotEmpty) ...[
              _buildModernInfoCard(
                title: 'Notes',
                icon: Icons.notes,
                color: Colors.orange,
                children: [
                  ...appointment.notes.map((note) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            note,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // Timestamps card
            _buildModernInfoCard(
              title: 'Timeline',
              icon: Icons.history,
              color: AppTheme.secondaryColor,
              children: [
                _buildModernInfoRow(
                  Icons.add_circle_outline,
                  'Created',
                  DateFormat('MMM d, yyyy \'at\' h:mm a').format(appointment.createdAt),
                ),
                if (appointment.lastUpdated != null)
                  _buildModernInfoRow(
                    Icons.update,
                    'Last Updated',
                    DateFormat('MMM d, yyyy \'at\' h:mm a').format(appointment.lastUpdated!),
                  ),
              ],
            ),
            
            // Add bottom padding for floating buttons
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: appointment.canBeModified
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary actions
                  Row(
                    children: [
                      if (appointment.status == AppointmentStatus.scheduled) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(context, AppointmentStatus.confirmed),
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text('Confirm'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.greenColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (appointment.status == AppointmentStatus.confirmed) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showCompleteAppointmentDialog(context),
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: const Text('Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(context, AppointmentStatus.cancelled),
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.redColor,
                            side: BorderSide(color: AppTheme.redColor, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Secondary actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(context, AppointmentStatus.rescheduled),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: const Text('Reschedule'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(context, AppointmentStatus.noShow),
                          icon: const Icon(Icons.person_off, size: 18),
                          label: const Text('No Show'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildModernInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryColor.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, AppointmentStatus status) {
    final updatedAppointment = appointment.copyWith(
      status: status,
      lastUpdated: DateTime.now(),
    );
    
    onAppointmentUpdated?.call(updatedAppointment);
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment status updated to ${status.displayName}'),
        backgroundColor: status.color,
      ),
    );
  }

  void _viewPatientProfile(BuildContext context) {
    // Check if this is a manual patient entry (temporary patient)
    if (appointment.patientId.startsWith('manual_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This is a temporary patient entry. No profile available.'),
          backgroundColor: AppTheme.secondaryColor,
          action: SnackBarAction(
            label: 'Create Profile',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Navigate to create patient profile screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create patient profile feature coming soon'),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // Navigate to patient profile screen
    context.push('/patients/${appointment.patientId}');
  }

  void _showCompleteAppointmentDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CompleteAppointmentDialog(
          appointment: appointment,
          onCompleted: (completedAppointment, session) {
            // Update the appointment
            onAppointmentUpdated?.call(completedAppointment);
            
            // Add session to patient if provided
            if (session != null && !appointment.patientId.startsWith('manual_')) {
              context.read<PatientProvider>().addSession(
                appointment.patientId,
                session,
              );
            }
            
            // Close the current dialog
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _editAppointment(BuildContext context) {
    // TODO: Implement edit functionality
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit functionality coming soon'),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: const Text(
          'Are you sure you want to delete this appointment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation dialog
              Navigator.of(context).pop(); // Close details dialog
              onAppointmentDeleted?.call();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appointment deleted'),
                  backgroundColor: AppTheme.redColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(AppointmentType type) {
    switch (type) {
      case AppointmentType.consultation:
        return Icons.medical_services;
      case AppointmentType.followUp:
        return Icons.follow_the_signs;
      case AppointmentType.treatment:
        return Icons.healing;
      case AppointmentType.assessment:
        return Icons.assessment;
      case AppointmentType.emergency:
        return Icons.emergency;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${hours}h';
      }
    } else {
      return '${minutes}m';
    }
  }
}
