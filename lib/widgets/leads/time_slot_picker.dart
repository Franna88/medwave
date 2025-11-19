import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/firebase/lead_booking_service.dart';

/// Widget for selecting available time slots
class TimeSlotPicker extends StatefulWidget {
  final List<TimeSlot> timeSlots;
  final String? selectedTime;
  final Function(String) onTimeSelected;

  const TimeSlotPicker({
    super.key,
    required this.timeSlots,
    required this.selectedTime,
    required this.onTimeSelected,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  @override
  Widget build(BuildContext context) {
    if (widget.timeSlots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No time slots available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.timeSlots.map((slot) {
            final isSelected = widget.selectedTime == slot.time;
            final isAvailable = slot.isAvailable;

            return InkWell(
              onTap: isAvailable ? () => widget.onTimeSelected(slot.time) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: !isAvailable
                      ? Colors.grey[200]
                      : isSelected
                          ? AppTheme.primaryColor
                          : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: !isAvailable
                        ? Colors.grey[300]!
                        : isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey[400]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      slot.formattedTime,
                      style: TextStyle(
                        color: !isAvailable
                            ? Colors.grey[400]
                            : isSelected
                                ? Colors.white
                                : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!isAvailable)
                      Text(
                        'Booked',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Widget for selecting booking duration
class DurationPicker extends StatelessWidget {
  final int selectedDuration;
  final Function(int) onDurationSelected;
  final List<int> availableDurations;

  const DurationPicker({
    super.key,
    required this.selectedDuration,
    required this.onDurationSelected,
    this.availableDurations = const [15, 30, 45, 60],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableDurations.map((duration) {
        final isSelected = selectedDuration == duration;

        return InkWell(
          onTap: () => onDurationSelected(duration),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.warningColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.warningColor : Colors.grey[400]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
                const SizedBox(width: 4),
                Text(
                  '${duration}m',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

