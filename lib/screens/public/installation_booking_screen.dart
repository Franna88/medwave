import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../services/firebase/order_service.dart';
import '../../models/streams/order.dart' as models;

class InstallationBookingScreen extends StatefulWidget {
  final String? orderId;
  final String? token;

  const InstallationBookingScreen({super.key, this.orderId, this.token});

  @override
  State<InstallationBookingScreen> createState() =>
      _InstallationBookingScreenState();
}

class _InstallationBookingScreenState extends State<InstallationBookingScreen> {
  final OrderService _orderService = OrderService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isCompleted = false;
  String? _errorMessage;
  models.Order? _order;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _selectedDates = {};
  late DateTime _firstAvailableDate;
  late DateTime _lastAvailableDate;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final orderId = widget.orderId;
    final token = widget.token;

    if (orderId == null || token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid booking link. Missing order information.';
      });
      return;
    }

    try {
      final order = await _orderService.getOrder(orderId);

      if (order == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Order not found.';
        });
        return;
      }

      // Validate token
      if (order.installBookingToken != token) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This link is invalid or has already been used.';
        });
        return;
      }

      // Check if already selected
      if (order.installBookingStatus ==
              models.InstallBookingStatus.datesSelected ||
          order.installBookingStatus == models.InstallBookingStatus.confirmed) {
        setState(() {
          _isLoading = false;
          _isCompleted = true;
          _order = order;
        });
        return;
      }

      // Calculate available date range (3 weeks from order creation)
      _firstAvailableDate = order.createdAt.add(const Duration(days: 21));
      _lastAvailableDate = _firstAvailableDate.add(const Duration(days: 90));
      _focusedDay = _firstAvailableDate;

      setState(() {
        _isLoading = false;
        _order = order;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load order details. Please try again.';
      });
    }
  }

  bool _isDateSelectable(DateTime day) {
    // Only allow dates from 3 weeks after order creation
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final normalizedFirst = DateTime(
      _firstAvailableDate.year,
      _firstAvailableDate.month,
      _firstAvailableDate.day,
    );
    final normalizedLast = DateTime(
      _lastAvailableDate.year,
      _lastAvailableDate.month,
      _lastAvailableDate.day,
    );

    // Don't allow weekends
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }

    return !normalizedDay.isBefore(normalizedFirst) &&
        !normalizedDay.isAfter(normalizedLast);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalizedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    if (!_isDateSelectable(selectedDay)) return;

    setState(() {
      _focusedDay = focusedDay;

      if (_selectedDates.contains(normalizedDay)) {
        _selectedDates.remove(normalizedDay);
      } else if (_selectedDates.length < 3) {
        _selectedDates.add(normalizedDay);
      } else {
        // Show message that max 3 dates can be selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can only select 3 dates. Remove one to add another.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _submitDates() async {
    if (_selectedDates.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exactly 3 preferred dates.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _orderService.handleInstallationDateSelection(
        orderId: widget.orderId!,
        token: widget.token!,
        selectedDates: _selectedDates.toList(),
      );

      if (result.success) {
        setState(() {
          _isSubmitting = false;
          _isCompleted = true;
        });
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to submit dates. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_errorMessage != null) {
      return _buildErrorCard();
    }

    if (_isCompleted) {
      return _buildCompletedCard();
    }

    return _buildBookingCard();
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Loading your order...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Oops!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thank You!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your preferred installation dates have been saved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Our team will contact you to confirm the final installation date.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),
            if (_order != null && _order!.customerSelectedDates.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Your Selected Dates:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ..._order!.customerSelectedDates.map(
                (date) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_month, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Select Installation Dates',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hi ${_order?.customerName ?? 'Customer'}!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please select 3 possible convienient dates for your installation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Selected dates indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _selectedDates.length == 3
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedDates.length == 3
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 20,
                  color: _selectedDates.length == 3
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDates.length}/3 dates selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selectedDates.length == 3
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Calendar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: _firstAvailableDate,
              lastDay: _lastAvailableDate,
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.grey.shade400),
                disabledTextStyle: TextStyle(color: Colors.grey.shade300),
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                ),
              ),
              enabledDayPredicate: _isDateSelectable,
              selectedDayPredicate: (day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return _selectedDates.contains(normalizedDay);
              },
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
            ),
          ),

          // Selected dates list
          if (_selectedDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Selected Dates:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_selectedDates.toList()..sort()).map(
                    (date) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Color(0xFF1A1A2E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(date),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _selectedDates.remove(date));
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedDates.length == 3 && !_isSubmitting
                    ? _submitDates
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Confirm Selected Dates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          // Info text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Select dates starting from ${DateFormat('MMMM d, yyyy').format(_firstAvailableDate)} (3 weeks from order placement)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
