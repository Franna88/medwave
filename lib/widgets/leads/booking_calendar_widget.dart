import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Custom calendar widget for booking selection
class BookingCalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final Set<DateTime> datesWithBookings;
  final Function(DateTime) onDateSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const BookingCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.datesWithBookings,
    required this.onDateSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  State<BookingCalendarWidget> createState() => _BookingCalendarWidgetState();
}

class _BookingCalendarWidgetState extends State<BookingCalendarWidget> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  bool _isDateDisabled(DateTime date) {
    // Disable past dates
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    if (date.isBefore(todayStart)) return true;

    // Check min/max dates
    if (widget.minDate != null && date.isBefore(widget.minDate!)) return true;
    if (widget.maxDate != null && date.isAfter(widget.maxDate!)) return true;

    return false;
  }

  bool _hasBooking(DateTime date) {
    return widget.datesWithBookings.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  bool _isSelected(DateTime date) {
    return date.year == widget.selectedDate.year &&
        date.month == widget.selectedDate.month &&
        date.day == widget.selectedDate.day;
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  List<DateTime> _getDaysInMonth() {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    
    final days = <DateTime>[];
    
    // Add empty days for alignment (start from Sunday)
    final firstWeekday = firstDayOfMonth.weekday % 7; // Convert to Sunday = 0
    for (var i = 0; i < firstWeekday; i++) {
      days.add(DateTime(1970, 1, 1)); // Placeholder for empty cells
    }
    
    // Add actual days
    for (var day = 1; day <= lastDayOfMonth.day; day++) {
      days.add(DateTime(_displayedMonth.year, _displayedMonth.month, day));
    }
    
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = _getMonthName(_displayedMonth.month);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
                color: AppTheme.primaryColor,
              ),
              Text(
                '$monthName ${_displayedMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              
              // Empty cell for alignment
              if (date.year == 1970) {
                return const SizedBox();
              }
              
              final isDisabled = _isDateDisabled(date);
              final hasBooking = _hasBooking(date);
              final isSelected = _isSelected(date);
              final isToday = _isToday(date);
              
              return InkWell(
                onTap: isDisabled ? null : () => widget.onDateSelected(date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : isToday
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppTheme.primaryColor, width: 2)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.grey[300]
                              : isSelected
                                  ? Colors.white
                                  : Colors.black87,
                          fontWeight:
                              isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasBooking && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: AppTheme.primaryColor,
                label: 'Selected',
              ),
              const SizedBox(width: 16),
              _buildLegendItem(
                color: AppTheme.warningColor,
                label: 'Has Bookings',
                isCircle: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isCircle = false,
  }) {
    return Row(
      children: [
        Container(
          width: isCircle ? 4 : 16,
          height: isCircle ? 4 : 16,
          decoration: BoxDecoration(
            color: color,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

