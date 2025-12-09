import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/leads/lead_booking.dart';
import '../../models/streams/appointment.dart' as models;

/// Service for managing lead bookings in Firestore
class LeadBookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get bookings collection reference
  CollectionReference get _bookingsCollection =>
      _firestore.collection('leadBookings');

  /// Create a new booking
  Future<String> createBooking(LeadBooking booking) async {
    try {
      // Check for conflicts before creating
      final hasConflict = await checkTimeSlotConflict(
        date: booking.bookingDate,
        time: booking.bookingTime,
        duration: booking.duration,
        excludeBookingId: null,
        assignedTo: booking.assignedTo,
      );

      if (hasConflict) {
        throw Exception('Time slot is already booked');
      }

      // Create booking
      final docRef = await _bookingsCollection.add(booking.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  /// Get a single booking by ID
  Future<LeadBooking?> getBooking(String bookingId) async {
    try {
      final doc = await _bookingsCollection.doc(bookingId).get();
      if (!doc.exists) return null;
      return LeadBooking.fromFirestore(doc);
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  /// Update an existing booking
  Future<void> updateBooking(LeadBooking booking) async {
    try {
      await _bookingsCollection.doc(booking.id).update(booking.toMap());
    } catch (e) {
      print('Error updating booking: $e');
      rethrow;
    }
  }

  /// Delete a booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _bookingsCollection.doc(bookingId).delete();
    } catch (e) {
      print('Error deleting booking: $e');
      rethrow;
    }
  }

  /// Stream of all bookings (for real-time updates)
  Stream<List<LeadBooking>> bookingsStream() {
    return _bookingsCollection.snapshots().map((snapshot) {
      final bookings = snapshot.docs
          .map((doc) => LeadBooking.fromFirestore(doc))
          .toList();
      // Sort by booking date and time
      bookings.sort((a, b) => a.bookingDateTime.compareTo(b.bookingDateTime));
      return bookings;
    });
  }

  /// Get bookings for a specific date
  Future<List<LeadBooking>> getBookingsByDate(
    DateTime date, {
    String? assignedTo,
  }) async {
    try {
      // Start and end of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      Query query = _bookingsCollection
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'bookingDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          );

      final querySnapshot = await query.get();

      var bookings = querySnapshot.docs
          .map((doc) => LeadBooking.fromFirestore(doc))
          .toList();

      // Filter by assignedTo in memory if provided (avoids composite index requirement)
      if (assignedTo != null) {
        bookings = bookings
            .where((booking) => booking.assignedTo == assignedTo)
            .toList();
      }

      // Sort by time
      bookings.sort((a, b) => a.bookingTime.compareTo(b.bookingTime));

      return bookings;
    } catch (e) {
      print('Error getting bookings by date: $e');
      return [];
    }
  }

  /// Get bookings for a date range
  Future<List<LeadBooking>> getBookingsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startOfDay = DateTime(start.year, start.month, start.day);
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      final querySnapshot = await _bookingsCollection
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'bookingDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      final bookings = querySnapshot.docs
          .map((doc) => LeadBooking.fromFirestore(doc))
          .toList();

      // Sort by date and time
      bookings.sort((a, b) => a.bookingDateTime.compareTo(b.bookingDateTime));

      return bookings;
    } catch (e) {
      print('Error getting bookings by date range: $e');
      return [];
    }
  }

  /// Get today's bookings
  Future<List<LeadBooking>> getTodaysBookings() async {
    final today = DateTime.now();
    return getBookingsByDate(today);
  }

  /// Get upcoming bookings (next 7 days)
  Future<List<LeadBooking>> getUpcomingBookings() async {
    final today = DateTime.now();
    final endDate = today.add(const Duration(days: 7));
    return getBookingsByDateRange(today, endDate);
  }

  /// Get appointments by date and assigned admin
  Future<List<models.SalesAppointment>> getAppointmentsByDateAndAdmin(
    DateTime date, {
    String? assignedTo,
  }) async {
    try {
      // Start and end of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      Query query = _firestore
          .collection('appointments')
          .where(
            'appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'appointmentDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          );

      final querySnapshot = await query.get();
      var appointments = querySnapshot.docs
          .map((doc) => models.SalesAppointment.fromFirestore(doc))
          .where((appt) => appt.appointmentDate != null)
          .toList();

      // Filter by assignedTo if provided
      if (assignedTo != null) {
        appointments = appointments
            .where((appt) => appt.assignedTo == assignedTo)
            .toList();
      }

      return appointments;
    } catch (e) {
      print('Error getting appointments by date and admin: $e');
      return [];
    }
  }

  /// Get sales admin availability for a specific date and time
  /// Returns a map of adminUserId -> AdminAvailability
  Future<Map<String, AdminAvailability>> getSalesAdminAvailability({
    required DateTime date,
    required String time,
    required int duration,
    required List<String> adminUserIds, // List of sales admin user IDs to check
  }) async {
    try {
      final availabilityMap = <String, AdminAvailability>{};

      // Parse the selected time
      final timeParts = time.split(':');
      final selectedHour = int.parse(timeParts[0]);
      final selectedMinute = int.parse(timeParts[1]);
      final selectedStart = DateTime(
        date.year,
        date.month,
        date.day,
        selectedHour,
        selectedMinute,
      );
      final selectedEnd = selectedStart.add(Duration(minutes: duration));

      // Get all bookings and appointments for the date
      final allBookings = await getBookingsByDate(date);
      final allAppointments = await getAppointmentsByDateAndAdmin(date);

      // Get all available time slots for the date (to count available slots per admin)
      const startHour = 9;
      const endHour = 17;
      final allTimeSlots = <String>[];
      for (var hour = startHour; hour < endHour; hour++) {
        for (var minute = 0; minute < 60; minute += 30) {
          final slotEnd = DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          ).add(Duration(minutes: duration));
          if (slotEnd.hour >= endHour &&
              (slotEnd.hour > endHour || slotEnd.minute > 0)) {
            continue;
          }
          final timeString =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          allTimeSlots.add(timeString);
        }
      }

      // Check availability for each admin
      for (final adminId in adminUserIds) {
        // Filter bookings and appointments for this admin
        final adminBookings = allBookings
            .where((b) => b.assignedTo == adminId)
            .toList();
        final adminAppointments = allAppointments
            .where((a) => a.assignedTo == adminId)
            .toList();

        // Check for conflicts at selected time
        final conflictingBookings = <LeadBooking>[];
        final conflictingAppointments = <models.SalesAppointment>[];

        for (final booking in adminBookings) {
          if (booking.status == BookingStatus.cancelled) continue;

          final bookingStart = booking.bookingDateTime;
          final bookingEnd = booking.bookingEndTime;

          if (_timesOverlap(
            selectedStart,
            selectedEnd,
            bookingStart,
            bookingEnd,
          )) {
            conflictingBookings.add(booking);
          }
        }

        for (final appointment in adminAppointments) {
          if (appointment.appointmentDate == null ||
              appointment.appointmentTime == null) {
            continue;
          }
          if (appointment.currentStage == 'completed' ||
              appointment.currentStage == 'cancelled') {
            continue;
          }

          final apptTimeParts = appointment.appointmentTime!.split(':');
          final apptHour = int.parse(apptTimeParts[0]);
          final apptMinute = int.parse(apptTimeParts[1]);
          final apptStart = DateTime(
            appointment.appointmentDate!.year,
            appointment.appointmentDate!.month,
            appointment.appointmentDate!.day,
            apptHour,
            apptMinute,
          );
          final apptEnd = apptStart.add(const Duration(minutes: 30));

          if (_timesOverlap(selectedStart, selectedEnd, apptStart, apptEnd)) {
            conflictingAppointments.add(appointment);
          }
        }

        final isAvailable =
            conflictingBookings.isEmpty && conflictingAppointments.isEmpty;

        // Count available slots for this admin on this date
        int availableSlotsCount = 0;
        for (final slotTime in allTimeSlots) {
          bool hasConflict = false;

          // Check against bookings
          for (final booking in adminBookings) {
            if (booking.status == BookingStatus.cancelled) continue;
            if (booking.bookingTime == slotTime) {
              hasConflict = true;
              break;
            }
          }

          // Check against appointments
          if (!hasConflict) {
            for (final appointment in adminAppointments) {
              if (appointment.appointmentDate == null ||
                  appointment.appointmentTime == null) {
                continue;
              }
              if (appointment.currentStage == 'completed' ||
                  appointment.currentStage == 'cancelled') {
                continue;
              }
              if (appointment.appointmentTime == slotTime) {
                hasConflict = true;
                break;
              }
            }
          }

          if (!hasConflict) {
            availableSlotsCount++;
          }
        }

        availabilityMap[adminId] = AdminAvailability(
          isAvailable: isAvailable,
          availableSlotsCount: availableSlotsCount,
          conflictingBookings: conflictingBookings,
          conflictingAppointments: conflictingAppointments,
        );
      }

      return availabilityMap;
    } catch (e) {
      print('Error getting sales admin availability: $e');
      return {};
    }
  }

  /// Check if a time slot has a conflict with existing bookings and appointments
  Future<bool> checkTimeSlotConflict({
    required DateTime date,
    required String time,
    required int duration,
    String? excludeBookingId,
    String? assignedTo,
  }) async {
    try {
      // Get all bookings for the date (filtered by assignedTo)
      final existingBookings = await getBookingsByDate(
        date,
        assignedTo: assignedTo,
      );

      // Get all appointments for the date (filtered by assignedTo)
      final existingAppointments = await getAppointmentsByDateAndAdmin(
        date,
        assignedTo: assignedTo,
      );

      // Parse the selected time
      final timeParts = time.split(':');
      final selectedHour = int.parse(timeParts[0]);
      final selectedMinute = int.parse(timeParts[1]);
      final selectedStart = DateTime(
        date.year,
        date.month,
        date.day,
        selectedHour,
        selectedMinute,
      );
      final selectedEnd = selectedStart.add(Duration(minutes: duration));

      // Check each existing booking for overlap
      for (final booking in existingBookings) {
        // Skip if this is the booking being edited
        if (excludeBookingId != null && booking.id == excludeBookingId) {
          continue;
        }

        // Skip cancelled bookings
        if (booking.status == BookingStatus.cancelled) {
          continue;
        }

        final bookingStart = booking.bookingDateTime;
        final bookingEnd = booking.bookingEndTime;

        // Check for time overlap
        if (_timesOverlap(
          selectedStart,
          selectedEnd,
          bookingStart,
          bookingEnd,
        )) {
          return true; // Conflict found
        }
      }

      // Check each existing appointment for overlap
      for (final appointment in existingAppointments) {
        // Skip if appointment doesn't have date/time
        if (appointment.appointmentDate == null ||
            appointment.appointmentTime == null) {
          continue;
        }

        // Skip completed appointments (assuming completed means past stage)
        if (appointment.currentStage == 'completed' ||
            appointment.currentStage == 'cancelled') {
          continue;
        }

        // Parse appointment time
        final apptTimeParts = appointment.appointmentTime!.split(':');
        final apptHour = int.parse(apptTimeParts[0]);
        final apptMinute = int.parse(apptTimeParts[1]);
        final apptStart = DateTime(
          appointment.appointmentDate!.year,
          appointment.appointmentDate!.month,
          appointment.appointmentDate!.day,
          apptHour,
          apptMinute,
        );
        // Assume 30 minutes duration for appointments (or use a default)
        final apptEnd = apptStart.add(const Duration(minutes: 30));

        // Check for time overlap
        if (_timesOverlap(selectedStart, selectedEnd, apptStart, apptEnd)) {
          return true; // Conflict found
        }
      }

      return false; // No conflict
    } catch (e) {
      print('Error checking time slot conflict: $e');
      return false;
    }
  }

  /// Helper method to check if two time ranges overlap
  bool _timesOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    // Two ranges overlap if one starts before the other ends
    return start1.isBefore(end2) && start2.isBefore(end1);
  }

  /// Get available time slots for a given date
  /// OPTIMIZED: Loads all bookings/appointments once, then checks all slots in memory
  /// This reduces from 32+ queries to just 2 queries, dramatically improving performance
  Future<List<TimeSlot>> getAvailableTimeSlots({
    required DateTime date,
    required int duration,
    String? excludeBookingId,
    String? assignedTo,
  }) async {
    try {
      // Load all bookings and appointments for the date ONCE (not per slot)
      // This is the key optimization - reduces from 32 queries to 2 queries
      final existingBookings = await getBookingsByDate(
        date,
        assignedTo: assignedTo,
      );

      final existingAppointments = await getAppointmentsByDateAndAdmin(
        date,
        assignedTo: assignedTo,
      );

      // Filter out cancelled/completed items
      final activeBookings = existingBookings
          .where((b) => b.status != BookingStatus.cancelled)
          .where((b) => excludeBookingId == null || b.id != excludeBookingId)
          .toList();

      final activeAppointments = existingAppointments
          .where(
            (a) =>
                a.appointmentDate != null &&
                a.appointmentTime != null &&
                a.currentStage != 'completed' &&
                a.currentStage != 'cancelled',
          )
          .toList();

      // Pre-calculate booking and appointment time ranges for faster in-memory lookup
      final bookingRanges = activeBookings
          .map((b) => {'start': b.bookingDateTime, 'end': b.bookingEndTime})
          .toList();

      final appointmentRanges = activeAppointments.map((a) {
        final timeParts = a.appointmentTime!.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final start = DateTime(
          a.appointmentDate!.year,
          a.appointmentDate!.month,
          a.appointmentDate!.day,
          hour,
          minute,
        );
        return {'start': start, 'end': start.add(const Duration(minutes: 30))};
      }).toList();

      final slots = <TimeSlot>[];

      // Working hours: 9 AM - 5 PM
      const startHour = 9;
      const endHour = 17;

      // Generate time slots every 30 minutes and check conflicts in memory
      for (var hour = startHour; hour < endHour; hour++) {
        for (var minute = 0; minute < 60; minute += 30) {
          // Skip if this slot would end after working hours
          final slotStart = DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );
          final slotEnd = slotStart.add(Duration(minutes: duration));

          if (slotEnd.hour >= endHour &&
              (slotEnd.hour > endHour || slotEnd.minute > 0)) {
            continue;
          }

          final timeString =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

          // Check conflicts in memory (much faster than individual queries)
          bool hasConflict = false;

          // Check against bookings
          for (final range in bookingRanges) {
            if (_timesOverlap(
              slotStart,
              slotEnd,
              range['start'] as DateTime,
              range['end'] as DateTime,
            )) {
              hasConflict = true;
              break;
            }
          }

          // Check against appointments if no booking conflict
          if (!hasConflict) {
            for (final range in appointmentRanges) {
              if (_timesOverlap(
                slotStart,
                slotEnd,
                range['start'] as DateTime,
                range['end'] as DateTime,
              )) {
                hasConflict = true;
                break;
              }
            }
          }

          slots.add(
            TimeSlot(
              time: timeString,
              hour: hour,
              minute: minute,
              isAvailable: !hasConflict,
            ),
          );
        }
      }

      return slots;
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  /// Get dates with bookings in a month (for calendar indicators)
  Future<Set<DateTime>> getDatesWithBookingsInMonth(
    int year,
    int month, {
    String? assignedTo,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      // Get bookings for the month (filtered by assignedTo)
      Query bookingsQuery = _bookingsCollection
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'bookingDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          );

      if (assignedTo != null) {
        bookingsQuery = bookingsQuery.where(
          'assignedTo',
          isEqualTo: assignedTo,
        );
      }

      final bookingsSnapshot = await bookingsQuery.get();
      final bookings = bookingsSnapshot.docs
          .map((doc) => LeadBooking.fromFirestore(doc))
          .toList();

      // Get appointments for the month (filtered by assignedTo)
      // Note: We need to handle the case where appointmentDate might be null
      // So we'll query and filter in memory
      Query appointmentsQuery = _firestore
          .collection('appointments')
          .where(
            'appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'appointmentDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          );

      final appointmentsSnapshot = await appointmentsQuery.get();
      var appointments = appointmentsSnapshot.docs
          .map((doc) => models.SalesAppointment.fromFirestore(doc))
          .where((appt) => appt.appointmentDate != null)
          .toList();

      // Filter by assignedTo if provided
      if (assignedTo != null) {
        appointments = appointments
            .where((appt) => appt.assignedTo == assignedTo)
            .toList();
      }

      // Extract unique dates from bookings
      final datesSet = <DateTime>{};
      for (final booking in bookings) {
        final date = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );
        datesSet.add(date);
      }

      // Extract unique dates from appointments
      for (final appointment in appointments) {
        if (appointment.appointmentDate != null) {
          final date = DateTime(
            appointment.appointmentDate!.year,
            appointment.appointmentDate!.month,
            appointment.appointmentDate!.day,
          );
          datesSet.add(date);
        }
      }

      return datesSet;
    } catch (e) {
      print('Error getting dates with bookings: $e');
      return {};
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      await _bookingsCollection.doc(bookingId).update({'status': status.name});
    } catch (e) {
      print('Error updating booking status: $e');
      rethrow;
    }
  }

  /// Update call notes and outcome
  Future<void> updateCallDetails({
    required String bookingId,
    String? callNotes,
    String? callOutcome,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (callNotes != null) updates['callNotes'] = callNotes;
      if (callOutcome != null) updates['callOutcome'] = callOutcome;

      await _bookingsCollection.doc(bookingId).update(updates);
    } catch (e) {
      print('Error updating call details: $e');
      rethrow;
    }
  }

  /// Seed mock bookings for testing
  Future<void> seedMockBookings() async {
    try {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      final mockBookings = [
        LeadBooking.createMock(
          id: 'mock1',
          leadId: 'lead1',
          bookingDate: today,
          bookingTime: '09:00',
          duration: 30,
        ),
        LeadBooking.createMock(
          id: 'mock2',
          leadId: 'lead2',
          bookingDate: today,
          bookingTime: '14:00',
          duration: 60,
        ),
        LeadBooking.createMock(
          id: 'mock3',
          leadId: 'lead3',
          bookingDate: tomorrow,
          bookingTime: '10:00',
          duration: 45,
        ),
      ];

      for (final booking in mockBookings) {
        await _bookingsCollection.doc(booking.id).set(booking.toMap());
      }

      print('Mock bookings seeded successfully');
    } catch (e) {
      print('Error seeding mock bookings: $e');
    }
  }
}

/// Time slot model for display
class TimeSlot {
  final String time; // "09:00"
  final int hour;
  final int minute;
  final bool isAvailable;

  TimeSlot({
    required this.time,
    required this.hour,
    required this.minute,
    required this.isAvailable,
  });

  /// Get formatted time for display (e.g., "9:00 AM")
  String get formattedTime {
    final isPM = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr ${isPM ? 'PM' : 'AM'}';
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}

/// Model for sales admin availability information
class AdminAvailability {
  final bool isAvailable; // No conflict at selected time
  final int availableSlotsCount; // Total available slots on that date
  final List<LeadBooking> conflictingBookings; // Conflicting bookings if any
  final List<models.SalesAppointment>
  conflictingAppointments; // Conflicting appointments if any

  AdminAvailability({
    required this.isAvailable,
    required this.availableSlotsCount,
    this.conflictingBookings = const [],
    this.conflictingAppointments = const [],
  });
}
