import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/appointment.dart';

class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get _appointmentsCollection => _firestore.collection('appointments');

  /// Get appointments stream for the current practitioner
  static Stream<List<Appointment>> getAppointmentsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _appointmentsCollection
        .where('practitionerId', isEqualTo: userId)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    });
  }

  /// Get appointments for a specific date range
  static Stream<List<Appointment>> getAppointmentsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _appointmentsCollection
        .where('practitionerId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    });
  }

  /// Get appointments for a specific date
  static Future<List<Appointment>> getAppointmentsForDate(DateTime date) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get appointments for date: $e');
    }
  }

  /// Get a specific appointment by ID
  static Future<Appointment?> getAppointment(String appointmentId) async {
    try {
      final doc = await _appointmentsCollection.doc(appointmentId).get();
      if (doc.exists) {
        return Appointment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get appointment: $e');
    }
  }

  /// Create a new appointment
  static Future<String> createAppointment(Appointment appointment) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Check for conflicts before creating
      final conflicts = await checkAppointmentConflicts(
        appointment.startTime,
        appointment.endTime,
        excludeAppointmentId: null,
      );

      if (conflicts.isNotEmpty) {
        throw Exception('Appointment conflicts with existing appointments');
      }

      // Create appointment with practitioner ID
      final appointmentData = appointment.copyWith(
        practitionerId: userId,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final docRef = await _appointmentsCollection.add(appointmentData.toFirestore());
      
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create appointment: $e');
    }
  }

  /// Update an existing appointment
  static Future<void> updateAppointment(String appointmentId, Appointment appointment) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the appointment belongs to the current practitioner
      final existingDoc = await _appointmentsCollection.doc(appointmentId).get();
      if (!existingDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final existingData = existingDoc.data() as Map<String, dynamic>;
      if (existingData['practitionerId'] != userId) {
        throw Exception('Access denied: Appointment belongs to another practitioner');
      }

      // Check for conflicts if time has changed
      final existingAppointment = Appointment.fromFirestore(existingDoc);
      if (appointment.startTime != existingAppointment.startTime ||
          appointment.endTime != existingAppointment.endTime) {
        final conflicts = await checkAppointmentConflicts(
          appointment.startTime,
          appointment.endTime,
          excludeAppointmentId: appointmentId,
        );

        if (conflicts.isNotEmpty) {
          throw Exception('Appointment conflicts with existing appointments');
        }
      }

      final updatedAppointment = appointment.copyWith(
        lastUpdated: DateTime.now(),
      );

      await _appointmentsCollection.doc(appointmentId).update(updatedAppointment.toFirestore());
    } catch (e) {
      throw Exception('Failed to update appointment: $e');
    }
  }

  /// Delete an appointment
  static Future<void> deleteAppointment(String appointmentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the appointment belongs to the current practitioner
      final appointmentDoc = await _appointmentsCollection.doc(appointmentId).get();
      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }
      
      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      if (appointmentData['practitionerId'] != userId) {
        throw Exception('Access denied: Appointment belongs to another practitioner');
      }

      // Check if appointment can be deleted (not completed, etc.)
      final appointment = Appointment.fromFirestore(appointmentDoc);
      if (!appointment.canBeModified) {
        throw Exception('Appointment cannot be deleted in its current status');
      }

      await _appointmentsCollection.doc(appointmentId).delete();
    } catch (e) {
      throw Exception('Failed to delete appointment: $e');
    }
  }

  /// Check for appointment conflicts
  static Future<List<Appointment>> checkAppointmentConflicts(
    DateTime startTime,
    DateTime endTime, {
    String? excludeAppointmentId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isLessThan: Timestamp.fromDate(endTime))
          .where('endTime', isGreaterThan: Timestamp.fromDate(startTime))
          .get();

      final conflicts = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .where((appointment) {
            // Exclude the appointment being updated
            if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) {
              return false;
            }
            // Only consider active appointments as conflicts
            return appointment.status != AppointmentStatus.cancelled &&
                   appointment.status != AppointmentStatus.noShow;
          })
          .toList();

      return conflicts;
    } catch (e) {
      throw Exception('Failed to check appointment conflicts: $e');
    }
  }

  /// Get upcoming appointments (next 7 days)
  static Future<List<Appointment>> getUpcomingAppointments() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isGreaterThan: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(nextWeek))
          .orderBy('startTime')
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get upcoming appointments: $e');
    }
  }

  /// Get today's appointments
  static Future<List<Appointment>> getTodaysAppointments() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get today\'s appointments: $e');
    }
  }

  /// Update appointment status
  static Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus newStatus,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final doc = await _appointmentsCollection.doc(appointmentId).get();
      if (!doc.exists) {
        throw Exception('Appointment not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      if (data['practitionerId'] != userId) {
        throw Exception('Access denied');
      }

      await _appointmentsCollection.doc(appointmentId).update({
        'status': newStatus.name,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update appointment status: $e');
    }
  }

  /// Get appointments by patient ID
  static Future<List<Appointment>> getAppointmentsByPatient(String patientId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('patientId', isEqualTo: patientId)
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get patient appointments: $e');
    }
  }

  /// Search appointments by patient name or title
  static Future<List<Appointment>> searchAppointments(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      if (query.isEmpty) {
        // Return recent appointments
        final snapshot = await _appointmentsCollection
            .where('practitionerId', isEqualTo: userId)
            .orderBy('startTime', descending: true)
            .limit(20)
            .get();
        
        return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      }

      // Search by patient name (Firestore doesn't support full-text search)
      final lowercaseQuery = query.toLowerCase();
      
      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .orderBy('patientName')
          .startAt([lowercaseQuery])
          .endAt(['$lowercaseQuery\uf8ff'])
          .get();

      return snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to search appointments: $e');
    }
  }

  /// Get appointment statistics
  static Future<Map<String, int>> getAppointmentStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final snapshot = await _appointmentsCollection
          .where('practitionerId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      
      final totalAppointments = appointments.length;
      final completedAppointments = appointments.where((a) => a.status == AppointmentStatus.completed).length;
      final cancelledAppointments = appointments.where((a) => a.status == AppointmentStatus.cancelled).length;
      final upcomingAppointments = appointments.where((a) => a.isUpcoming).length;

      return {
        'total': totalAppointments,
        'completed': completedAppointments,
        'cancelled': cancelledAppointments,
        'upcoming': upcomingAppointments,
      };
    } catch (e) {
      throw Exception('Failed to get appointment statistics: $e');
    }
  }

  /// Get available time slots for a specific date
  static Future<List<DateTime>> getAvailableTimeSlots(
    DateTime date, {
    Duration slotDuration = const Duration(minutes: 30),
    Duration appointmentDuration = const Duration(minutes: 60),
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get existing appointments for the date
      final existingAppointments = await getAppointmentsForDate(date);
      
      // Define working hours (9 AM to 5 PM)
      final workingStart = DateTime(date.year, date.month, date.day, 9, 0);
      final workingEnd = DateTime(date.year, date.month, date.day, 17, 0);
      
      final availableSlots = <DateTime>[];
      var currentSlot = workingStart;
      
      while (currentSlot.add(appointmentDuration).isBefore(workingEnd) ||
             currentSlot.add(appointmentDuration).isAtSameMomentAs(workingEnd)) {
        
        final slotEnd = currentSlot.add(appointmentDuration);
        
        // Check if this slot conflicts with any existing appointment
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
    } catch (e) {
      throw Exception('Failed to get available time slots: $e');
    }
  }
}
