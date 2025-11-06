import 'package:flutter/material.dart';
import 'dart:async';
import '../models/appointment.dart';
import '../services/firebase/appointment_service.dart';
import '../services/emailjs_service.dart';

class AppointmentProvider with ChangeNotifier {
  final List<Appointment> _appointments = [];
  DateTime _selectedDate = DateTime.now();
  AppointmentStatus? _statusFilter;
  AppointmentType? _typeFilter;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Appointment>>? _appointmentsSubscription;
  
  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = true;

  // Getters
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  DateTime get selectedDate => _selectedDate;
  AppointmentStatus? get statusFilter => _statusFilter;
  AppointmentType? get typeFilter => _typeFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Initialize appointment data stream
  Future<void> loadAppointments() async {
    if (!_useFirebase) {
      return _loadMockAppointments();
    }

    try {
      _setLoading(true);
      _setError(null);
      
      // Subscribe to real-time appointment updates
      _appointmentsSubscription?.cancel();
      _appointmentsSubscription = AppointmentService.getAppointmentsStream().listen(
        (appointments) {
          debugPrint('📅 APPOINTMENTS: Received ${appointments.length} appointments from Firebase');
          _appointments.clear();
          _appointments.addAll(appointments);
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load appointments: $error');
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError('Failed to initialize appointment stream: $e');
      _setLoading(false);
    }
  }

  /// Get appointments for a specific date
  List<Appointment> getAppointmentsForDate(DateTime date) {
    return _appointments.where((appointment) {
      return appointment.startTime.year == date.year &&
             appointment.startTime.month == date.month &&
             appointment.startTime.day == date.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get filtered appointments
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

  /// Get upcoming appointments
  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    return _appointments
        .where((apt) => apt.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get today's appointments
  List<Appointment> get todaysAppointments {
    final now = DateTime.now();
    return getAppointmentsForDate(now);
  }

  /// Get this week's appointments
  List<Appointment> get thisWeekAppointments {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return _appointments.where((appointment) {
      return appointment.startTime.isAfter(startOfWeek) &&
             appointment.startTime.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get appointments by status
  List<Appointment> getAppointmentsByStatus(AppointmentStatus status) {
    return _appointments
        .where((apt) => apt.status == status)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Get appointments by type
  List<Appointment> getAppointmentsByType(AppointmentType type) {
    return _appointments
        .where((apt) => apt.type == type)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Add a new appointment
  Future<bool> addAppointment(Appointment appointment) async {
    if (!_useFirebase) {
      return _addMockAppointment(appointment);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      final appointmentId = await AppointmentService.createAppointment(appointment);
      
      // Send booking confirmation email if patient email is provided
      if (appointment.patientEmail != null && appointment.patientEmail!.isNotEmpty) {
        debugPrint('📧 Sending booking confirmation email...');
        
        final confirmationLink = EmailJSService.generateConfirmationLink(appointmentId);
        
        EmailJSService.sendBookingConfirmation(
          appointment: appointment.copyWith(id: appointmentId),
          patientEmail: appointment.patientEmail!,
          confirmationLink: confirmationLink,
        ).then((success) {
          if (success) {
            debugPrint('✅ Booking confirmation email sent');
          } else {
            debugPrint('⚠️ Failed to send booking confirmation email');
          }
        });
      }
      
      // The real-time listener will automatically update the UI
      debugPrint('Appointment created with ID: $appointmentId');
      return true;
    } catch (e) {
      _setError('Failed to add appointment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing appointment
  Future<bool> updateAppointment(String appointmentId, Appointment appointment) async {
    if (!_useFirebase) {
      return _updateMockAppointment(appointmentId, appointment);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      await AppointmentService.updateAppointment(appointmentId, appointment);
      
      // The real-time listener will automatically update the UI
      return true;
    } catch (e) {
      _setError('Failed to update appointment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete an appointment
  Future<bool> deleteAppointment(String appointmentId) async {
    if (!_useFirebase) {
      return _deleteMockAppointment(appointmentId);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      await AppointmentService.deleteAppointment(appointmentId);
      
      // The real-time listener will automatically update the UI
      return true;
    } catch (e) {
      _setError('Failed to delete appointment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update appointment status
  Future<bool> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    if (!_useFirebase) {
      return _updateMockAppointmentStatus(appointmentId, status);
    }

    try {
      _setLoading(true);
      _setError(null);
      
      await AppointmentService.updateAppointmentStatus(appointmentId, status);
      
      // Send confirmation email if status changed to confirmed
      if (status == AppointmentStatus.confirmed) {
        final appointment = _appointments.firstWhere(
          (apt) => apt.id == appointmentId,
          orElse: () => throw Exception('Appointment not found'),
        );
        
        if (appointment.patientEmail != null && appointment.patientEmail!.isNotEmpty) {
          debugPrint('📧 Sending appointment confirmed email...');
          
          EmailJSService.sendAppointmentConfirmed(
            appointment: appointment,
            patientEmail: appointment.patientEmail!,
          ).then((success) {
            if (success) {
              debugPrint('✅ Appointment confirmed email sent');
            } else {
              debugPrint('⚠️ Failed to send confirmed email');
            }
          });
        }
      }
      
      // The real-time listener will automatically update the UI
      return true;
    } catch (e) {
      _setError('Failed to update appointment status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check for appointment conflicts
  Future<List<Appointment>> checkConflicts(
    DateTime startTime,
    DateTime endTime, {
    String? excludeAppointmentId,
  }) async {
    if (!_useFirebase) {
      return _checkMockConflicts(startTime, endTime, excludeAppointmentId);
    }

    try {
      return await AppointmentService.checkAppointmentConflicts(
        startTime,
        endTime,
        excludeAppointmentId: excludeAppointmentId,
      );
    } catch (e) {
      _setError('Failed to check conflicts: $e');
      return [];
    }
  }

  /// Check for appointment conflicts (synchronous version for UI)
  bool hasConflict(DateTime startTime, DateTime endTime, {String? excludeAppointmentId}) {
    // Get all appointments for the date
    final appointmentsForDate = getAppointmentsForDate(startTime);
    
    // Check for conflicts with existing appointments
    return appointmentsForDate.any((appointment) {
      // Skip if this is the appointment we're excluding
      if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) {
        return false;
      }
      
      // Skip cancelled or no-show appointments
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.noShow) {
        return false;
      }
      
      // Check for time overlap
      return (startTime.isBefore(appointment.endTime) &&
              endTime.isAfter(appointment.startTime));
    });
  }

  /// Get available time slots for a date
  Future<List<DateTime>> getAvailableTimeSlots(
    DateTime date, {
    Duration appointmentDuration = const Duration(minutes: 60),
  }) async {
    if (!_useFirebase) {
      return _getMockAvailableTimeSlots(date, appointmentDuration);
    }

    try {
      return await AppointmentService.getAvailableTimeSlots(
        date,
        appointmentDuration: appointmentDuration,
      );
    } catch (e) {
      _setError('Failed to get available time slots: $e');
      return [];
    }
  }

  /// Search appointments
  Future<List<Appointment>> searchAppointments(String query) async {
    if (!_useFirebase) {
      return _searchMockAppointments(query);
    }

    try {
      return await AppointmentService.searchAppointments(query);
    } catch (e) {
      _setError('Failed to search appointments: $e');
      return [];
    }
  }

  /// Get appointments by patient
  Future<List<Appointment>> getAppointmentsByPatient(String patientId) async {
    if (!_useFirebase) {
      return _getAppointmentsByPatientMock(patientId);
    }

    try {
      return await AppointmentService.getAppointmentsByPatient(patientId);
    } catch (e) {
      _setError('Failed to get patient appointments: $e');
      return [];
    }
  }

  /// Get appointment statistics
  Future<Map<String, int>> getAppointmentStats() async {
    if (!_useFirebase) {
      return _getMockAppointmentStats();
    }

    try {
      return await AppointmentService.getAppointmentStats();
    } catch (e) {
      _setError('Failed to get appointment statistics: $e');
      return {
        'total': 0,
        'completed': 0,
        'cancelled': 0,
        'upcoming': 0,
      };
    }
  }

  /// Set selected date for calendar
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Set status filter
  void setStatusFilter(AppointmentStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  /// Set type filter
  void setTypeFilter(AppointmentType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _statusFilter = null;
    _typeFilter = null;
    notifyListeners();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  // Mock data methods for development
  Future<void> _loadMockAppointments() async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _appointments.clear();
    _appointments.addAll(_generateMockAppointments());
    _setLoading(false);
  }

  Future<bool> _addMockAppointment(Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _appointments.add(appointment);
    notifyListeners();
    return true;
  }

  Future<bool> _updateMockAppointment(String appointmentId, Appointment appointment) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      _appointments[index] = appointment;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> _deleteMockAppointment(String appointmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final initialLength = _appointments.length;
    _appointments.removeWhere((a) => a.id == appointmentId);
    final removed = initialLength - _appointments.length;
    if (removed > 0) {
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> _updateMockAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      _appointments[index] = _appointments[index].copyWith(status: status);
      notifyListeners();
      return true;
    }
    return false;
  }

  List<Appointment> _checkMockConflicts(
    DateTime startTime,
    DateTime endTime,
    String? excludeAppointmentId,
  ) {
    return _appointments
        .where((appointment) {
          if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) {
            return false;
          }
          return appointment.startTime.isBefore(endTime) &&
                 appointment.endTime.isAfter(startTime) &&
                 appointment.status != AppointmentStatus.cancelled &&
                 appointment.status != AppointmentStatus.noShow;
        })
        .toList();
  }

  List<DateTime> _getMockAvailableTimeSlots(DateTime date, Duration appointmentDuration) {
    final workingStart = DateTime(date.year, date.month, date.day, 9, 0);
    final workingEnd = DateTime(date.year, date.month, date.day, 17, 0);
    final slotDuration = const Duration(minutes: 30);
    
    final availableSlots = <DateTime>[];
    var currentSlot = workingStart;
    
    while (currentSlot.add(appointmentDuration).isBefore(workingEnd) ||
           currentSlot.add(appointmentDuration).isAtSameMomentAs(workingEnd)) {
      
      final slotEnd = currentSlot.add(appointmentDuration);
      final existingAppointments = getAppointmentsForDate(date);
      
      final hasConflict = existingAppointments.any((appointment) {
        return (currentSlot.isBefore(appointment.endTime) &&
                slotEnd.isAfter(appointment.startTime)) &&
               appointment.status != AppointmentStatus.cancelled &&
               appointment.status != AppointmentStatus.noShow;
      });
      
      if (!hasConflict) {
        availableSlots.add(currentSlot);
      }
      
      currentSlot = currentSlot.add(slotDuration);
    }
    
    return availableSlots;
  }

  List<Appointment> _searchMockAppointments(String query) {
    if (query.isEmpty) return _appointments;
    
    final lowercaseQuery = query.toLowerCase();
    return _appointments.where((appointment) {
      return appointment.patientName.toLowerCase().contains(lowercaseQuery) ||
             appointment.title.toLowerCase().contains(lowercaseQuery) ||
             (appointment.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  List<Appointment> _getAppointmentsByPatientMock(String patientId) {
    return _appointments
        .where((appointment) => appointment.patientId == patientId)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Map<String, int> _getMockAppointmentStats() {
    final now = DateTime.now();
    final thisMonth = _appointments.where((a) => 
        a.startTime.year == now.year && a.startTime.month == now.month).toList();
    
    return {
      'total': thisMonth.length,
      'completed': thisMonth.where((a) => a.status == AppointmentStatus.completed).length,
      'cancelled': thisMonth.where((a) => a.status == AppointmentStatus.cancelled).length,
      'upcoming': thisMonth.where((a) => a.isUpcoming).length,
    };
  }

  List<Appointment> _generateMockAppointments() {
    // This would contain your existing mock appointment generation logic
    // For now, return an empty list since Firebase is the primary path
    return [];
  }
}