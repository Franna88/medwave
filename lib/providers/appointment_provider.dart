import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

class AppointmentProvider with ChangeNotifier {
  final List<Appointment> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  AppointmentStatus? _statusFilter;
  AppointmentType? _typeFilter;

  // Getters
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  DateTime get selectedDate => _selectedDate;
  AppointmentStatus? get statusFilter => _statusFilter;
  AppointmentType? get typeFilter => _typeFilter;

  // Get appointments for a specific date
  List<Appointment> getAppointmentsForDate(DateTime date) {
    return _appointments.where((appointment) {
      return appointment.startTime.year == date.year &&
             appointment.startTime.month == date.month &&
             appointment.startTime.day == date.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get filtered appointments
  List<Appointment> get filteredAppointments {
    List<Appointment> filtered = List.from(_appointments);

    if (_statusFilter != null) {
      filtered = filtered.where((apt) => apt.status == _statusFilter).toList();
    }

    if (_typeFilter != null) {
      filtered = filtered.where((apt) => apt.type == _typeFilter).toList();
    }

    return filtered..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get upcoming appointments
  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    return _appointments
        .where((apt) => apt.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get today's appointments
  List<Appointment> get todaysAppointments {
    final today = DateTime.now();
    return getAppointmentsForDate(today);
  }

  // Get appointments for current week
  List<Appointment> get thisWeekAppointments {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return _appointments.where((apt) {
      return apt.startTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             apt.startTime.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get appointments by patient
  List<Appointment> getAppointmentsByPatient(String patientId) {
    return _appointments
        .where((apt) => apt.patientId == patientId)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Get appointment statistics
  Map<String, int> get appointmentStats {
    final stats = <String, int>{};
    
    for (final status in AppointmentStatus.values) {
      stats[status.displayName] = _appointments
          .where((apt) => apt.status == status)
          .length;
    }
    
    return stats;
  }

  // Check for conflicts
  bool hasConflict(DateTime startTime, DateTime endTime, {String? excludeId}) {
    return _appointments.any((apt) {
      if (excludeId != null && apt.id == excludeId) return false;
      
      // Check if appointments overlap
      return (startTime.isBefore(apt.endTime) && endTime.isAfter(apt.startTime));
    });
  }

  // Get available time slots for a date
  List<DateTime> getAvailableTimeSlots(DateTime date, {Duration duration = const Duration(hours: 1)}) {
    final workingHours = <DateTime>[];
    final startHour = 8; // 8 AM
    final endHour = 17; // 5 PM
    
    // Generate all possible time slots
    for (int hour = startHour; hour < endHour; hour++) {
      for (int minute = 0; minute < 60; minute += 30) { // 30-minute intervals
        final slot = DateTime(date.year, date.month, date.day, hour, minute);
        final slotEnd = slot.add(duration);
        
        // Check if slot is within working hours
        if (slotEnd.hour <= endHour) {
          workingHours.add(slot);
        }
      }
    }
    
    // Remove conflicting slots
    return workingHours.where((slot) {
      final slotEnd = slot.add(duration);
      return !hasConflict(slot, slotEnd);
    }).toList();
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Set filters
  void setStatusFilter(AppointmentStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setTypeFilter(AppointmentType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _typeFilter = null;
    notifyListeners();
  }

  // CRUD operations
  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    notifyListeners();
  }

  void updateAppointment(String id, Appointment updatedAppointment) {
    final index = _appointments.indexWhere((apt) => apt.id == id);
    if (index != -1) {
      _appointments[index] = updatedAppointment.copyWith(
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void deleteAppointment(String id) {
    _appointments.removeWhere((apt) => apt.id == id);
    notifyListeners();
  }

  // Update appointment status
  void updateAppointmentStatus(String id, AppointmentStatus status) {
    final index = _appointments.indexWhere((apt) => apt.id == id);
    if (index != -1) {
      _appointments[index] = _appointments[index].copyWith(
        status: status,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Reschedule appointment
  void rescheduleAppointment(String id, DateTime newStartTime, DateTime newEndTime) {
    final index = _appointments.indexWhere((apt) => apt.id == id);
    if (index != -1) {
      _appointments[index] = _appointments[index].copyWith(
        startTime: newStartTime,
        endTime: newEndTime,
        status: AppointmentStatus.rescheduled,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Bulk operations
  void addAppointments(List<Appointment> appointments) {
    _appointments.addAll(appointments);
    notifyListeners();
  }

  void clearAppointments() {
    _appointments.clear();
    notifyListeners();
  }

  // Search appointments
  List<Appointment> searchAppointments(String query) {
    if (query.isEmpty) return filteredAppointments;
    
    final lowercaseQuery = query.toLowerCase();
    return _appointments.where((apt) {
      return apt.patientName.toLowerCase().contains(lowercaseQuery) ||
             apt.title.toLowerCase().contains(lowercaseQuery) ||
             apt.description?.toLowerCase().contains(lowercaseQuery) == true ||
             apt.type.displayName.toLowerCase().contains(lowercaseQuery) ||
             apt.status.displayName.toLowerCase().contains(lowercaseQuery);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Generate sample data for testing
  void loadSampleData(List<Patient> patients) {
    final sampleAppointments = <Appointment>[];
    final now = DateTime.now();
    
    // Create some sample appointments
    for (int i = 0; i < patients.length && i < 10; i++) {
      final patient = patients[i];
      
      // Past appointment
      sampleAppointments.add(Appointment(
        id: 'apt_${i}_1',
        patientId: patient.id,
        patientName: patient.name,
        title: 'Follow-up Consultation',
        description: 'Regular check-up and progress review',
        startTime: now.subtract(Duration(days: 7 - i, hours: 9 + (i % 3))),
        endTime: now.subtract(Duration(days: 7 - i, hours: 10 + (i % 3))),
        type: AppointmentType.followUp,
        status: AppointmentStatus.completed,
        practitionerName: 'Dr. Smith',
        location: 'Room ${101 + i}',
        notes: ['Completed successfully', 'Patient showed improvement'],
        createdAt: now.subtract(Duration(days: 14)),
      ));
      
      // Future appointment
      sampleAppointments.add(Appointment(
        id: 'apt_${i}_2',
        patientId: patient.id,
        patientName: patient.name,
        title: 'Treatment Session',
        description: 'Scheduled treatment session',
        startTime: now.add(Duration(days: i + 1, hours: 10 + (i % 4))),
        endTime: now.add(Duration(days: i + 1, hours: 11 + (i % 4))),
        type: AppointmentType.treatment,
        status: AppointmentStatus.scheduled,
        practitionerName: 'Dr. Johnson',
        location: 'Treatment Room ${i + 1}',
        notes: [],
        createdAt: now.subtract(Duration(days: 5)),
      ));
    }
    
    _appointments.addAll(sampleAppointments);
    notifyListeners();
  }
}
