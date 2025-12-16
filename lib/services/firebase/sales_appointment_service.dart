import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/streams/appointment.dart' as models;
import '../../models/streams/order.dart' as models;
import 'order_service.dart';

/// Service for managing sales appointments in Firebase
class SalesAppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderService _orderService = OrderService();

  /// Get all sales appointments
  Future<List<models.SalesAppointment>> getAllAppointments({
    String? orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('appointments');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => models.SalesAppointment.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all appointments: $e');
      }
      rethrow;
    }
  }

  /// Get appointments by stage
  Future<List<models.SalesAppointment>> getAppointmentsByStage(
    String stage,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('currentStage', isEqualTo: stage)
          .get();

      final appointments = snapshot.docs
          .map((doc) => models.SalesAppointment.fromFirestore(doc))
          .toList();
      // Sort in memory to avoid index requirement
      appointments.sort((a, b) => a.stageEnteredAt.compareTo(b.stageEnteredAt));
      return appointments;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting appointments by stage: $e');
      }
      rethrow;
    }
  }

  /// Get a single appointment by ID
  Future<models.SalesAppointment?> getAppointment(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return models.SalesAppointment.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting appointment $appointmentId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all appointments
  Stream<List<models.SalesAppointment>> appointmentsStream() {
    return _firestore.collection('appointments').snapshots().map((snapshot) {
      final appointments = snapshot.docs
          .map((doc) => models.SalesAppointment.fromFirestore(doc))
          .toList();
      // Sort in memory instead of using orderBy to avoid index requirement
      appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return appointments;
    });
  }

  /// Create a new appointment
  Future<String> createAppointment(models.SalesAppointment appointment) async {
    try {
      final docRef = await _firestore
          .collection('appointments')
          .add(appointment.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating appointment: $e');
      }
      rethrow;
    }
  }

  /// Update an existing appointment
  Future<void> updateAppointment(models.SalesAppointment appointment) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointment.id)
          .update(appointment.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating appointment: $e');
      }
      rethrow;
    }
  }

  Future<void> updateAppointmentAssignment({
    required String appointmentId,
    String? assignedTo,
    String? assignedToName,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      final updatedAppointment = appointment.copyWith(
        assignedTo: assignedTo,
        assignedToName: assignedToName,
        updatedAt: DateTime.now(),
      );

      await updateAppointment(updatedAppointment);

      if (kDebugMode) {
        print(
          'Updated appointment assignment: $appointmentId -> ${assignedToName ?? "Unassigned"}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating appointment assignment: $e');
      }
      rethrow;
    }
  }

  /// Delete an appointment
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting appointment: $e');
      }
      rethrow;
    }
  }

  /// Move appointment to a new stage with note
  Future<void> moveAppointmentToStage({
    required String appointmentId,
    required String newStage,
    required String note,
    required String userId,
    String? userName,
    double? depositAmount,
    bool? depositPaid,
    DateTime? appointmentDate,
    String? appointmentTime,
    String? assignedTo,
    String? assignedToName,
    String? optInNote,
    List<models.OptInProduct>? optInProducts,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      final now = DateTime.now();

      // Create stage history entry for current stage exit
      final updatedHistory = [...appointment.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length -
              1] = models.SalesAppointmentStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: now,
            note: note,
          );
        }
      }

      // Add new stage history entry
      updatedHistory.add(
        models.SalesAppointmentStageHistoryEntry(
          stage: newStage,
          enteredAt: now,
          note: note,
        ),
      );

      // Create note for the transition
      final transitionNote = models.SalesAppointmentNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...appointment.notes, transitionNote];

      // Update appointment
      final updatedAppointment = appointment.copyWith(
        currentStage: newStage,
        stageEnteredAt: now,
        updatedAt: now,
        stageHistory: updatedHistory,
        notes: updatedNotes,
        depositAmount: depositAmount ?? appointment.depositAmount,
        depositPaid: depositPaid ?? appointment.depositPaid,
        appointmentDate: appointmentDate ?? appointment.appointmentDate,
        appointmentTime: appointmentTime ?? appointment.appointmentTime,
        assignedTo: assignedTo ?? appointment.assignedTo,
        assignedToName: assignedToName ?? appointment.assignedToName,
        optInNote: optInNote ?? appointment.optInNote,
        optInProducts: optInProducts ?? appointment.optInProducts,
      );

      await updateAppointment(updatedAppointment);

      // Persist Opt In selection to lead as well, if provided
      if (optInNote != null || optInProducts != null) {
        final productMaps = (optInProducts ?? appointment.optInProducts)
            .map((p) => p.toMap())
            .toList();
        await _firestore.collection('leads').doc(appointment.leadId).update({
          'optInNote': optInNote ?? appointment.optInNote,
          'optInProducts': productMaps,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Check if we need to convert to Order (final stage)
      if (newStage == 'send_to_operations') {
        await convertToOrder(
          appointmentId: appointmentId,
          userId: userId,
          userName: userName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error moving appointment to stage: $e');
      }
      rethrow;
    }
  }

  /// Convert appointment to order (when reaching "Send to Operations" stage)
  Future<String> convertToOrder({
    required String appointmentId,
    required String userId,
    String? userName,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      // Check if already converted
      if (appointment.convertedToOrderId != null) {
        return appointment.convertedToOrderId!;
      }

      final now = DateTime.now();

      // Create new order from appointment data
      final order = models.Order(
        id: '',
        appointmentId: appointmentId,
        customerName: appointment.customerName,
        email: appointment.email,
        phone: appointment.phone,
        currentStage: 'order_placed', // First stage in Operations stream
        orderDate: now,
        items: [], // Empty initially - will be filled in "Items Selected" stage
        createdAt: now,
        updatedAt: now,
        stageEnteredAt: now,
        stageHistory: [
          models.OrderStageHistoryEntry(
            stage: 'order_placed',
            enteredAt: now,
            note: 'Converted from Sales appointment',
          ),
        ],
        notes: [
          models.OrderNote(
            text: 'Order created from appointment ${appointment.id}',
            createdAt: now,
            createdBy: userId,
            createdByName: userName,
          ),
        ],
        createdBy: userId,
        createdByName: userName,
      );

      // Create the order
      final orderId = await _orderService.createOrder(order);

      // Update appointment with order reference
      final updatedAppointment = appointment.copyWith(
        convertedToOrderId: orderId,
        updatedAt: now,
      );
      await updateAppointment(updatedAppointment);

      if (kDebugMode) {
        print('Converted appointment $appointmentId to order $orderId');
      }

      return orderId;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting appointment to order: $e');
      }
      rethrow;
    }
  }

  /// Add a note to an appointment
  Future<void> addNote({
    required String appointmentId,
    required String noteText,
    required String userId,
    String? userName,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      final note = models.SalesAppointmentNote(
        text: noteText,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...appointment.notes, note];

      await _firestore.collection('appointments').doc(appointmentId).update({
        'notes': updatedNotes.map((n) => n.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error adding note: $e');
      }
      rethrow;
    }
  }

  /// Search appointments by customer name, email, or phone
  Future<List<models.SalesAppointment>> searchAppointments(String query) async {
    try {
      // Get all appointments
      final allAppointments = await getAllAppointments();

      // Filter by query
      final lowerQuery = query.toLowerCase();
      return allAppointments.where((appointment) {
        return appointment.customerName.toLowerCase().contains(lowerQuery) ||
            appointment.email.toLowerCase().contains(lowerQuery) ||
            appointment.phone.contains(query);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching appointments: $e');
      }
      rethrow;
    }
  }

  /// Get appointment count by stage
  Future<Map<String, int>> getAppointmentCountsByStage() async {
    try {
      final appointments = await getAllAppointments();
      final counts = <String, int>{};

      for (final appointment in appointments) {
        counts[appointment.currentStage] =
            (counts[appointment.currentStage] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting appointment counts by stage: $e');
      }
      rethrow;
    }
  }

  /// Move appointment to Deposit Requested stage (after contract signing)
  /// This is called unauthenticated, so it uses direct update without reading first
  Future<void> moveToDepositRequested(
    String appointmentId, {
    String? customerName,
    String? contractId,
  }) async {
    try {
      final now = DateTime.now();
      final contextNote = customerName != null
          ? 'Contract digitally signed by $customerName. Moving to deposit requested stage for payment processing.'
          : 'Contract digitally signed. Moving to deposit requested stage for payment processing.';

      // Direct update without reading first (Firestore rules will validate)
      // Rules ensure this only works if appointment is in opt_in stage
      await _firestore.collection('appointments').doc(appointmentId).update({
        'currentStage': 'deposit_requested',
        'updatedAt': Timestamp.fromDate(now),
        'stageHistory': FieldValue.arrayUnion([
          {
            'stage': 'deposit_requested',
            'movedAt': Timestamp.fromDate(now),
            'movedBy': 'system',
            'movedByName': 'System (Contract Signing)',
            'note': contextNote,
          },
        ]),
      });

      if (kDebugMode) {
        print('✅ Moved appointment $appointmentId to Deposit Requested stage');
        if (contractId != null) {
          print('   Contract ID: $contractId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error moving appointment to Deposit Requested: $e');
      }
      rethrow;
    }
  }
}
