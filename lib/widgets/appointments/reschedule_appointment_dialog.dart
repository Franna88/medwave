import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/streams/appointment.dart' as models;
import '../../services/firebase/lead_booking_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/admin_user.dart';
import '../../utils/role_manager.dart';
import '../../services/firebase/lead_booking_service.dart' show TimeSlot;
import '../leads/booking_calendar_widget.dart';
import '../leads/time_slot_picker.dart' show TimeSlotPicker, DurationPicker;
import '../leads/sales_admin_availability_widget.dart';

/// Result object returned when rescheduling is confirmed
class RescheduleTransitionResult {
  final String note;
  final DateTime bookingDate;
  final String bookingTime;
  final int duration;
  final String? assignedTo; // userId of assigned Sales Admin
  final String? assignedToName; // name of assigned Sales Admin

  RescheduleTransitionResult({
    required this.note,
    required this.bookingDate,
    required this.bookingTime,
    required this.duration,
    this.assignedTo,
    this.assignedToName,
  });
}

/// Dialog for rescheduling an appointment when moving to "Rescheduled" stage
class RescheduleAppointmentDialog extends StatefulWidget {
  final models.SalesAppointment appointment;
  final String newStageName;

  const RescheduleAppointmentDialog({
    super.key,
    required this.appointment,
    required this.newStageName,
  });

  @override
  State<RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends State<RescheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _bookingService = LeadBookingService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  int _selectedDuration = 30;
  Set<DateTime> _datesWithBookings = {};
  List<TimeSlot> _availableTimeSlots = [];
  bool _isLoadingSlots = false;
  bool _isLoadingDates = false;
  bool _isDisposed = false;
  String? _selectedSalesAdminId;
  String? _selectedSalesAdminName;
  List<AdminUser> _salesAdmins = [];
  bool _isLoadingSalesAdmins = false;
  Map<String, AdminAvailability> _adminAvailabilityMap = {};
  bool _isLoadingAvailability = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current appointment date if available, otherwise use today
    if (widget.appointment.appointmentDate != null) {
      _selectedDate = widget.appointment.appointmentDate!;
    }
    if (widget.appointment.appointmentTime != null) {
      _selectedTime = widget.appointment.appointmentTime;
    }
    _loadSalesAdmins();
    _loadDatesWithBookings();
    _loadAvailableTimeSlots();
  }

  Future<void> _loadSalesAdmins() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole;

    // Only show dropdown for Super Admin
    if (userRole != UserRole.superAdmin) {
      return;
    }

    if (_isDisposed || !mounted) return;
    if (mounted) {
      setState(() => _isLoadingSalesAdmins = true);
    }
    try {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      await adminProvider.loadAdminUsers();

      // Filter for active sales admins
      final salesAdmins = adminProvider.adminUsers
          .where(
            (admin) =>
                admin.role == AdminRole.sales &&
                admin.status == AdminUserStatus.active,
          )
          .toList();

      if (!_isDisposed && mounted) {
        setState(() {
          _salesAdmins = salesAdmins;
          _isLoadingSalesAdmins = false;
        });
      }
    } catch (e) {
      print('Error loading sales admins: $e');
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingSalesAdmins = false);
      }
    }
  }

  bool get _canAssignSalesAdmin {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole;
    return userRole == UserRole.superAdmin;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDatesWithBookings() async {
    if (_isDisposed || !mounted) return;
    if (mounted) {
      setState(() => _isLoadingDates = true);
    }
    try {
      // Use selected admin ID if SuperAdmin, otherwise use current user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = _selectedSalesAdminId ?? authProvider.user?.uid;

      final dates = await _bookingService.getDatesWithBookingsInMonth(
        _selectedDate.year,
        _selectedDate.month,
        assignedTo: userId,
      );
      if (!_isDisposed && mounted) {
        setState(() {
          _datesWithBookings = dates;
          _isLoadingDates = false;
        });
      }
    } catch (e) {
      print('Error loading dates with bookings: $e');
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingDates = false);
      }
    }
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (_isDisposed || !mounted) return;
    if (mounted) {
      setState(() => _isLoadingSlots = true);
    }
    try {
      // Use selected admin ID if SuperAdmin, otherwise use current user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = _selectedSalesAdminId ?? authProvider.user?.uid;

      final slots = await _bookingService.getAvailableTimeSlots(
        date: _selectedDate,
        duration: _selectedDuration,
        assignedTo: userId,
      );
      if (!_isDisposed && mounted) {
        setState(() {
          _availableTimeSlots = slots;
          _isLoadingSlots = false;
        });

        // Clear selected time if it's no longer available
        if (_selectedTime != null) {
          final isStillAvailable = slots.any(
            (s) => s.time == _selectedTime && s.isAvailable,
          );
          if (!isStillAvailable && mounted) {
            setState(() {
              _selectedTime = null;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading available time slots: $e');
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null; // Reset time when date changes
    });
    _loadDatesWithBookings();
    _loadAvailableTimeSlots();
  }

  void _onDurationChanged(int duration) {
    setState(() {
      _selectedDuration = duration;
      _selectedTime = null; // Reset time when duration changes
    });
    _loadAvailableTimeSlots();
  }

  void _onTimeSelected(String time) {
    setState(() {
      _selectedTime = time;
      _selectedSalesAdminId = null; // Reset admin selection when time changes
      _selectedSalesAdminName = null;
      _adminAvailabilityMap = {};
    });
    // Load admin availability for the selected time if SuperAdmin
    if (_canAssignSalesAdmin) {
      _loadAdminAvailability();
    }
  }

  Future<void> _loadAdminAvailability() async {
    if (_selectedTime == null ||
        _salesAdmins.isEmpty ||
        _isDisposed ||
        !mounted) {
      return;
    }

    if (mounted) {
      setState(() => _isLoadingAvailability = true);
    }

    try {
      final adminUserIds = _salesAdmins.map((admin) => admin.userId).toList();
      final availabilityMap = await _bookingService.getSalesAdminAvailability(
        date: _selectedDate,
        time: _selectedTime!,
        duration: _selectedDuration,
        adminUserIds: adminUserIds,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _adminAvailabilityMap = availabilityMap;
          _isLoadingAvailability = false;
        });
      }
    } catch (e) {
      print('Error loading admin availability: $e');
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  void _onSalesAdminSelected(String? adminId) {
    if (!mounted) return;
    setState(() {
      _selectedSalesAdminId = adminId;
      _selectedSalesAdminName = adminId != null
          ? _salesAdmins.firstWhere((a) => a.userId == adminId).fullName
          : null;
    });
    // Reload dates and slots when admin changes
    _loadDatesWithBookings();
    _loadAvailableTimeSlots();
  }

  void _confirmReschedule() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    // Validate sales admin selection if user can assign
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole;
    final userId = authProvider.user?.uid;

    String? assignedToId;
    String? assignedToName;

    if (userRole == UserRole.superAdmin) {
      // SuperAdmin must select an admin
      if (_selectedSalesAdminId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a sales admin')),
        );
        return;
      }
      assignedToId = _selectedSalesAdminId;
      assignedToName = _selectedSalesAdminName;
    } else {
      // SalesAdmin auto-assigns to themselves
      assignedToId = userId;
      assignedToName = authProvider.userName;
    }

    final result = RescheduleTransitionResult(
      note: _noteController.text.trim(),
      bookingDate: _selectedDate,
      bookingTime: _selectedTime!,
      duration: _selectedDuration,
      assignedTo: assignedToId,
      assignedToName: assignedToName,
    );

    Navigator.of(context).pop(result);
  }

  String _getEndTime() {
    if (_selectedTime == null) return '';

    final timeParts = _selectedTime!.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final start = DateTime(2000, 1, 1, hour, minute);
    final end = start.add(Duration(minutes: _selectedDuration));

    final endHour = end.hour > 12
        ? end.hour - 12
        : (end.hour == 0 ? 12 : end.hour);
    final endMinute = end.minute.toString().padLeft(2, '0');
    final period = end.hour >= 12 ? 'PM' : 'AM';

    return '$endHour:$endMinute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reschedule Appointment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.appointment.customerName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      const Text(
                        'Select New Appointment Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingDates
                          ? const Center(child: CircularProgressIndicator())
                          : BookingCalendarWidget(
                              selectedDate: _selectedDate,
                              datesWithBookings: _datesWithBookings,
                              onDateSelected: _onDateSelected,
                              minDate: DateTime.now(),
                            ),
                      const SizedBox(height: 24),

                      // Duration picker
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DurationPicker(
                        selectedDuration: _selectedDuration,
                        onDurationSelected: _onDurationChanged,
                      ),
                      const SizedBox(height: 24),

                      // Time slot picker (visible after date selected)
                      const Text(
                        'Select Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedTime != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Selected: ${_selectedTime} - Ends at ${_getEndTime()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _isLoadingSlots
                          ? const Center(child: CircularProgressIndicator())
                          : TimeSlotPicker(
                              timeSlots: _availableTimeSlots,
                              selectedTime: _selectedTime,
                              onTimeSelected: _onTimeSelected,
                            ),
                      const SizedBox(height: 24),

                      // Sales Admin Selection with Availability (visible after time selected for SuperAdmin)
                      if (_canAssignSalesAdmin && _selectedTime != null) ...[
                        SalesAdminAvailabilityWidget(
                          salesAdmins: _salesAdmins,
                          availabilityMap: _adminAvailabilityMap,
                          selectedAdminId: _selectedSalesAdminId,
                          onAdminSelected: _onSalesAdminSelected,
                          isLoading:
                              _isLoadingAvailability || _isLoadingSalesAdmins,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Note field
                      const Text(
                        'Reschedule Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText: 'Add a note about this reschedule...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please add a note';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _confirmReschedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Confirm Reschedule',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
}
