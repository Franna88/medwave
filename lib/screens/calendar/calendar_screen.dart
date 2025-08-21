import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/patient_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/appointment_card.dart';
import 'widgets/add_appointment_dialog.dart';
import 'widgets/appointment_details_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<Appointment>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier([]);
    
    // Load sample data if appointments are empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appointmentProvider = context.read<AppointmentProvider>();
      final patientProvider = context.read<PatientProvider>();
      
      if (appointmentProvider.appointments.isEmpty && patientProvider.patients.isNotEmpty) {
        appointmentProvider.loadSampleData(patientProvider.patients);
      }
      
      _updateSelectedEvents();
    });
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  void _updateSelectedEvents() {
    if (_selectedDay != null) {
      final appointments = context.read<AppointmentProvider>().getAppointmentsForDate(_selectedDay!);
      _selectedEvents.value = appointments;
    }
  }

  List<Appointment> _getEventsForDay(DateTime day) {
    return context.read<AppointmentProvider>().getAppointmentsForDate(day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppointmentProvider>(
        builder: (context, appointmentProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Modern Calendar Header
                _buildModernCalendarHeader(appointmentProvider),
                
                // Calendar Widget
                TableCalendar<Appointment>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(color: AppTheme.redColor),
                    holidayTextStyle: TextStyle(color: AppTheme.redColor),
                    selectedDecoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: AppTheme.greenColor,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.all(Radius.circular(12.0)),
                    ),
                    formatButtonTextStyle: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _updateSelectedEvents();
                    }
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
                
                const SizedBox(height: 8.0),
                
                // Selected Day Appointments
                ValueListenableBuilder<List<Appointment>>(
                  valueListenable: _selectedEvents,
                  builder: (context, appointments, _) {
                    if (appointments.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Appointments for ${DateFormat('EEEE, MMMM d').format(_selectedDay!)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = appointments[index];
                            return AppointmentCard(
                              appointment: appointment,
                              onTap: () => _showAppointmentDetails(appointment),
                              onStatusChanged: (status) {
                                appointmentProvider.updateAppointmentStatus(
                                  appointment.id,
                                  status,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 100), // Add bottom padding for FAB
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppointmentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildModernCalendarHeader(AppointmentProvider provider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and actions
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calendar',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Schedule and manage appointments',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.filter_list, color: AppTheme.textColor),
                        ),
                        onPressed: _showFilterDialog,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.today, color: AppTheme.textColor),
                        ),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime.now();
                            _selectedDay = DateTime.now();
                          });
                          _updateSelectedEvents();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stats cards
              _buildCalendarStats(provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarStats(AppointmentProvider provider) {
    final todayCount = provider.todaysAppointments.length;
    final weekCount = provider.thisWeekAppointments.length;
    final upcomingCount = provider.upcomingAppointments.length;

    return Row(
      children: [
        _buildStatCard('Today', todayCount.toString(), AppTheme.primaryColor),
        const SizedBox(width: 12),
        _buildStatCard('This Week', weekCount.toString(), AppTheme.greenColor),
        const SizedBox(width: 12),
        _buildStatCard('Upcoming', upcomingCount.toString(), AppTheme.pinkColor),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForLabel(label),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Today':
        return Icons.today;
      case 'This Week':
        return Icons.calendar_view_week;
      case 'Upcoming':
        return Icons.schedule;
      default:
        return Icons.event;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: AppTheme.secondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments scheduled',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.secondaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add an appointment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AddAppointmentDialog(
          selectedDate: _selectedDay ?? DateTime.now(),
          onAppointmentAdded: (appointment) {
            context.read<AppointmentProvider>().addAppointment(appointment);
            _updateSelectedEvents();
          },
        ),
      ),
    );
  }

  void _showAppointmentDetails(Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AppointmentDetailsDialog(
          appointment: appointment,
          onAppointmentUpdated: (updatedAppointment) {
            context.read<AppointmentProvider>().updateAppointment(
              appointment.id,
              updatedAppointment,
            );
            _updateSelectedEvents();
          },
          onAppointmentDeleted: () {
            context.read<AppointmentProvider>().deleteAppointment(appointment.id);
            _updateSelectedEvents();
          },
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Appointments'),
        content: Consumer<AppointmentProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status'),
                DropdownButton<AppointmentStatus?>(
                  value: provider.statusFilter,
                  isExpanded: true,
                  hint: const Text('All statuses'),
                  onChanged: (status) {
                    provider.setStatusFilter(status);
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...AppointmentStatus.values.map((status) =>
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Type'),
                DropdownButton<AppointmentType?>(
                  value: provider.typeFilter,
                  isExpanded: true,
                  hint: const Text('All types'),
                  onChanged: (type) {
                    provider.setTypeFilter(type);
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...AppointmentType.values.map((type) =>
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AppointmentProvider>().clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
