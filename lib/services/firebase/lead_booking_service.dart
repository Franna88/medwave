import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/leads/lead_booking.dart';

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
      final bookings =
          snapshot.docs.map((doc) => LeadBooking.fromFirestore(doc)).toList();
      // Sort by booking date and time
      bookings.sort((a, b) => a.bookingDateTime.compareTo(b.bookingDateTime));
      return bookings;
    });
  }

  /// Get bookings for a specific date
  Future<List<LeadBooking>> getBookingsByDate(DateTime date) async {
    try {
      // Start and end of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _bookingsCollection
          .where('bookingDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('bookingDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final bookings = querySnapshot.docs
          .map((doc) => LeadBooking.fromFirestore(doc))
          .toList();

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
      DateTime start, DateTime end) async {
    try {
      final startOfDay = DateTime(start.year, start.month, start.day);
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      final querySnapshot = await _bookingsCollection
          .where('bookingDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('bookingDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
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

  /// Check if a time slot has a conflict with existing bookings
  Future<bool> checkTimeSlotConflict({
    required DateTime date,
    required String time,
    required int duration,
    String? excludeBookingId,
  }) async {
    try {
      // Get all bookings for the date
      final existingBookings = await getBookingsByDate(date);

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
        if (_timesOverlap(selectedStart, selectedEnd, bookingStart, bookingEnd)) {
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
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    // Two ranges overlap if one starts before the other ends
    return start1.isBefore(end2) && start2.isBefore(end1);
  }

  /// Get available time slots for a given date
  Future<List<TimeSlot>> getAvailableTimeSlots({
    required DateTime date,
    required int duration,
    String? excludeBookingId,
  }) async {
    try {
      final slots = <TimeSlot>[];

      // Working hours: 9 AM - 5 PM
      const startHour = 9;
      const endHour = 17;

      // Generate time slots every 30 minutes
      for (var hour = startHour; hour < endHour; hour++) {
        for (var minute = 0; minute < 60; minute += 30) {
          // Skip if this slot would end after working hours
          final slotEnd = DateTime(date.year, date.month, date.day, hour, minute)
              .add(Duration(minutes: duration));
          if (slotEnd.hour >= endHour &&
              (slotEnd.hour > endHour || slotEnd.minute > 0)) {
            continue;
          }

          final timeString =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

          final hasConflict = await checkTimeSlotConflict(
            date: date,
            time: timeString,
            duration: duration,
            excludeBookingId: excludeBookingId,
          );

          slots.add(TimeSlot(
            time: timeString,
            hour: hour,
            minute: minute,
            isAvailable: !hasConflict,
          ));
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
      int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final bookings = await getBookingsByDateRange(startOfMonth, endOfMonth);

      // Extract unique dates
      final datesSet = <DateTime>{};
      for (final booking in bookings) {
        final date = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
        );
        datesSet.add(date);
      }

      return datesSet;
    } catch (e) {
      print('Error getting dates with bookings: $e');
      return {};
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    try {
      await _bookingsCollection.doc(bookingId).update({
        'status': status.name,
      });
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

