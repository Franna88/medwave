import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/appointment.dart';

/// Service for managing practitioner-patient appointments in Firebase
/// This is separate from the Sales stream appointments
class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get stream of all appointments
  static Stream<List<Appointment>> getAppointmentsStream() {
    return _firestore
        .collection('practitioner_appointments')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
        });
  }

  /// Create a new appointment
  static Future<String> createAppointment(Appointment appointment) async {
    try {
      final docRef = await _firestore.collection('practitioner_appointments').add(appointment.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating appointment: $e');
      }
      rethrow;
    }
  }

  /// Update an existing appointment
  static Future<void> updateAppointment(String appointmentId, Appointment appointment) async {
    try {
      await _firestore
          .collection('practitioner_appointments')
          .doc(appointmentId)
          .update(appointment.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating appointment: $e');
      }
      rethrow;
    }
  }

  /// Delete an appointment
  static Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection('practitioner_appointments').doc(appointmentId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting appointment: $e');
      }
      rethrow;
    }
  }

  /// Update appointment status
  static Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    try {
      await _firestore.collection('practitioner_appointments').doc(appointmentId).update({
        'status': status.name,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating appointment status: $e');
      }
      rethrow;
    }
  }

  /// Check for appointment conflicts
  static Future<List<Appointment>> checkAppointmentConflicts(
    DateTime startTime,
    DateTime endTime, {
    String? excludeAppointmentId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('practitioner_appointments')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      return snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .where((appointment) {
            if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) {
              return false;
            }
            return appointment.status != AppointmentStatus.cancelled &&
                   appointment.status != AppointmentStatus.noShow;
          })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking appointment conflicts: $e');
      }
      rethrow;
    }
  }

  /// Get available time slots for a date
  static Future<List<DateTime>> getAvailableTimeSlots(
    DateTime date, {
    Duration appointmentDuration = const Duration(minutes: 60),
  }) async {
    try {
      final workingStart = DateTime(date.year, date.month, date.day, 9, 0);
      final workingEnd = DateTime(date.year, date.month, date.day, 17, 0);
      final slotDuration = const Duration(minutes: 30);
      
      final availableSlots = <DateTime>[];
      var currentSlot = workingStart;
      
      // Get all appointments for the date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final snapshot = await _firestore
          .collection('practitioner_appointments')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      final existingAppointments = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .where((apt) => apt.status != AppointmentStatus.cancelled && apt.status != AppointmentStatus.noShow)
          .toList();
      
      while (currentSlot.add(appointmentDuration).isBefore(workingEnd) ||
             currentSlot.add(appointmentDuration).isAtSameMomentAs(workingEnd)) {
        
        final slotEnd = currentSlot.add(appointmentDuration);
        
        final hasConflict = existingAppointments.any((appointment) {
          return (currentSlot.isBefore(appointment.endTime) &&
                  slotEnd.isAfter(appointment.startTime));
        });
        
        if (!hasConflict) {
          availableSlots.add(currentSlot);
        }
        
        currentSlot = currentSlot.add(slotDuration);
      }
      
      return availableSlots;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting available time slots: $e');
      }
      rethrow;
    }
  }

  /// Search appointments by patient name or title
  static Future<List<Appointment>> searchAppointments(String query) async {
    try {
      // Get all appointments and filter in memory (since Firestore doesn't support full-text search)
      final snapshot = await _firestore.collection('practitioner_appointments').get();
      
      final lowerQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .where((appointment) {
            return appointment.patientName.toLowerCase().contains(lowerQuery) ||
                   appointment.title.toLowerCase().contains(lowerQuery) ||
                   (appointment.description?.toLowerCase().contains(lowerQuery) ?? false);
          })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching appointments: $e');
      }
      rethrow;
    }
  }

  /// Get appointments by patient
  static Future<List<Appointment>> getAppointmentsByPatient(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection('practitioner_appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting appointments by patient: $e');
      }
      rethrow;
    }
  }

  /// Get upcoming appointments by patient
  static Future<List<Appointment>> getUpcomingAppointmentsByPatient(String patientId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('practitioner_appointments')
          .where('patientId', isEqualTo: patientId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      
      final appointments = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .where((apt) => apt.status != AppointmentStatus.cancelled && apt.status != AppointmentStatus.noShow)
          .toList();
      
      appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
      return appointments;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting upcoming appointments by patient: $e');
      }
      rethrow;
    }
  }

  /// Get appointment statistics
  static Future<Map<String, int>> getAppointmentStats() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final snapshot = await _firestore
          .collection('practitioner_appointments')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      
      final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      
      return {
        'total': appointments.length,
        'completed': appointments.where((a) => a.status == AppointmentStatus.completed).length,
        'cancelled': appointments.where((a) => a.status == AppointmentStatus.cancelled).length,
        'upcoming': appointments.where((a) => a.isUpcoming).length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting appointment stats: $e');
      }
      rethrow;
    }
  }
}

