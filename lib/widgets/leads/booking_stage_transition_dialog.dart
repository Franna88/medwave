import 'package:flutter/material.dart';
import '../../models/leads/lead.dart';
import '../../services/firebase/lead_booking_service.dart';
import '../../theme/app_theme.dart';
import 'booking_calendar_widget.dart';
import 'time_slot_picker.dart';

/// Result object returned when booking is confirmed
class BookingTransitionResult {
  final String note;
  final DateTime bookingDate;
  final String bookingTime;
  final int duration;

  BookingTransitionResult({
    required this.note,
    required this.bookingDate,
    required this.bookingTime,
    required this.duration,
  });
}

/// Dialog for creating a booking when moving to "Booking" stage
class BookingStageTransitionDialog extends StatefulWidget {
  final Lead lead;
  final String newStageName;

  const BookingStageTransitionDialog({
    super.key,
    required this.lead,
    required this.newStageName,
  });

  @override
  State<BookingStageTransitionDialog> createState() =>
      _BookingStageTransitionDialogState();
}

class _BookingStageTransitionDialogState
    extends State<BookingStageTransitionDialog> {
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

  @override
  void initState() {
    super.initState();
    _loadDatesWithBookings();
    _loadAvailableTimeSlots();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDatesWithBookings() async {
    setState(() => _isLoadingDates = true);
    try {
      final dates = await _bookingService.getDatesWithBookingsInMonth(
        _selectedDate.year,
        _selectedDate.month,
      );
      setState(() {
        _datesWithBookings = dates;
        _isLoadingDates = false;
      });
    } catch (e) {
      print('Error loading dates with bookings: $e');
      setState(() => _isLoadingDates = false);
    }
  }

  Future<void> _loadAvailableTimeSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final slots = await _bookingService.getAvailableTimeSlots(
        date: _selectedDate,
        duration: _selectedDuration,
      );
      setState(() {
        _availableTimeSlots = slots;
        _isLoadingSlots = false;
      });

      // Clear selected time if it's no longer available
      if (_selectedTime != null) {
        final isStillAvailable = slots.any(
          (s) => s.time == _selectedTime && s.isAvailable,
        );
        if (!isStillAvailable) {
          setState(() => _selectedTime = null);
        }
      }
    } catch (e) {
      print('Error loading available time slots: $e');
      setState(() => _isLoadingSlots = false);
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
    setState(() => _selectedTime = time);
  }

  void _confirmBooking() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    final result = BookingTransitionResult(
      note: _noteController.text.trim(),
      bookingDate: _selectedDate,
      bookingTime: _selectedTime!,
      duration: _selectedDuration,
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
    
    final endHour = end.hour > 12 ? end.hour - 12 : (end.hour == 0 ? 12 : end.hour);
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
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Booking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.lead.fullName,
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
                        '📅 Select Appointment Date',
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
                        '⏱️ Duration',
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

                      // Time slot picker
                      Row(
                        children: [
                          const Text(
                            '⏰ Select Time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedTime != null) ...[
                            const Spacer(),
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
                                'Ends at ${_getEndTime()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      _isLoadingSlots
                          ? const Center(child: CircularProgressIndicator())
                          : TimeSlotPicker(
                              timeSlots: _availableTimeSlots,
                              selectedTime: _selectedTime,
                              onTimeSelected: _onTimeSelected,
                            ),
                      const SizedBox(height: 24),

                      // Note field
                      const Text(
                        '📝 Transition Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          hintText: 'Add a note about this booking...',
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
                    onPressed: _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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
}

