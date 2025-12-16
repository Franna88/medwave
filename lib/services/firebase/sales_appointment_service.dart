import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/streams/appointment.dart' as models;
import '../../models/streams/order.dart' as models;
import '../emailjs_service.dart';
import 'order_service.dart';

/// Service for managing sales appointments in Firebase
class SalesAppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderService _orderService = OrderService();
  static const String _depositLinkBaseProd = 'https://app.medwave.com';
  static const String _depositLinkBaseLocal = 'http://localhost:52961';

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
    String? depositConfirmationToken,
    String? depositConfirmationStatus,
    DateTime? depositConfirmationSentAt,
    DateTime? depositConfirmationRespondedAt,
    bool shouldSendDepositEmail = true,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        throw Exception('Appointment not found');
      }

      final now = DateTime.now();

      // Determine if we need to send deposit confirmation email
      final movedFromOptInToDeposit =
          appointment.currentStage == 'opt_in' &&
          newStage == 'deposit_requested';

      String? confirmationToken = depositConfirmationToken;
      String? confirmationStatus = depositConfirmationStatus;
      DateTime? confirmationSentAt = depositConfirmationSentAt;
      DateTime? confirmationRespondedAt = depositConfirmationRespondedAt;

      if (shouldSendDepositEmail && movedFromOptInToDeposit) {
        confirmationToken = const Uuid().v4();
        confirmationStatus = 'pending';
        confirmationSentAt = now;

        final yesUrl = _buildDepositConfirmationLink(
          appointmentId: appointment.id,
          decision: 'yes',
          token: confirmationToken,
        );
        final noUrl = _buildDepositConfirmationLink(
          appointmentId: appointment.id,
          decision: 'no',
          token: confirmationToken,
        );

        await EmailJSService.sendCustomerDepositRequest(
          appointment: appointment,
          yesUrl: yesUrl,
          noUrl: noUrl,
        );
      }

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
        depositConfirmationToken:
            confirmationToken ?? appointment.depositConfirmationToken,
        depositConfirmationStatus:
            confirmationStatus ?? appointment.depositConfirmationStatus,
        depositConfirmationSentAt:
            confirmationSentAt ?? appointment.depositConfirmationSentAt,
        depositConfirmationRespondedAt:
            confirmationRespondedAt ??
            appointment.depositConfirmationRespondedAt,
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

  /// Handle deposit confirmation response from public link
  Future<DepositConfirmationResult> handleDepositConfirmationResponse({
    required String appointmentId,
    required String decision,
    required String token,
  }) async {
    final normalizedDecision = decision.toLowerCase();
    if (normalizedDecision != 'yes' && normalizedDecision != 'no') {
      return const DepositConfirmationResult(
        success: false,
        message: 'Unknown decision.',
        status: DepositResponseStatus.invalid,
      );
    }

    try {
      // 1. Fetch the appointment to validate token
      final appointment = await getAppointment(appointmentId);

      if (appointment == null) {
        return const DepositConfirmationResult(
          success: false,
          message: 'Appointment not found.',
          status: DepositResponseStatus.invalid,
        );
      }

      // 2. Validate token matches
      if (appointment.depositConfirmationToken != token) {
        return const DepositConfirmationResult(
          success: false,
          message: 'Invalid or expired confirmation link.',
          status: DepositResponseStatus.invalid,
        );
      }

      // 3. Check if already responded
      if (appointment.depositConfirmationStatus != null &&
          appointment.depositConfirmationStatus != 'pending') {
        return const DepositConfirmationResult(
          success: false,
          message: 'You have already responded to this confirmation.',
          status: DepositResponseStatus.invalid,
        );
      }

      // 4. Prepare update data
      final now = DateTime.now();
      final isConfirmed = normalizedDecision == 'yes';
      final newStatus = isConfirmed ? 'confirmed' : 'declined';

      // Create stage history note
      final stageNote = isConfirmed
          ? 'Customer ${appointment.customerName} has made deposit, finance department will confirm'
          : 'We will send a follow up email in 2 days';

      // Add new stage history entry (append to existing history)
      final updatedHistory = [...appointment.stageHistory];
      if (updatedHistory.isNotEmpty) {
        // Update the last entry's note if it's the current stage and has no exit time
        final lastEntry = updatedHistory.last;
        if (lastEntry.stage == 'deposit_requested' &&
            lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length -
              1] = models.SalesAppointmentStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: lastEntry.exitedAt,
            note: stageNote,
          );
        }
      }

      // 5. Update appointment in Firestore
      await _firestore.collection('appointments').doc(appointmentId).update({
        'depositConfirmationStatus': newStatus,
        'depositConfirmationRespondedAt': Timestamp.fromDate(now),
        'stageHistory': updatedHistory.map((entry) => entry.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (kDebugMode) {
        print('Deposit confirmation updated: $appointmentId -> $newStatus');
      }

      if (isConfirmed) {
        try {
          final financeUrl = _buildFinanceConfirmationLink(
            appointmentId: appointment.id,
            token: appointment.depositConfirmationToken ?? token,
          );

          final sent = await EmailJSService.sendMarketingDepositNotification(
            appointment: appointment,
            marketingEmail: 'ojebola.michae00@gmail.com',
            yesUrl: financeUrl,
            noUrl: financeUrl,
            yesLabel: 'Deposit received',
            noLabel: '',
            description:
                'Please confirm you have received the customer deposit.',
          );

          if (kDebugMode) {
            print(
              'Finance notification for $appointmentId sent: $sent (confirmed)',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to send finance notification for $appointmentId: $e');
          }
        }
      }

      // 6. Return success result
      return DepositConfirmationResult(
        success: true,
        message: isConfirmed
            ? 'Thank you for confirming your deposit.'
            : 'Thank you for your response.',
        status: isConfirmed
            ? DepositResponseStatus.confirmed
            : DepositResponseStatus.declined,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error handling deposit confirmation response: $e');
      }
      return const DepositConfirmationResult(
        success: false,
        message: 'Something went wrong. Please try again later.',
        status: DepositResponseStatus.invalid,
      );
    }
  }

  /// Handle finance confirmation (single button) to mark deposit as received
  Future<DepositConfirmationResult> handleFinanceDepositConfirmation({
    required String appointmentId,
    required String token,
  }) async {
    try {
      final appointment = await getAppointment(appointmentId);
      if (appointment == null) {
        return const DepositConfirmationResult(
          success: false,
          message: 'Appointment not found.',
          status: DepositResponseStatus.invalid,
        );
      }

      if (appointment.depositConfirmationToken != token) {
        return const DepositConfirmationResult(
          success: false,
          message: 'Invalid or expired confirmation link.',
          status: DepositResponseStatus.invalid,
        );
      }

      if (appointment.currentStage == 'deposit_made') {
        return const DepositConfirmationResult(
          success: true,
          message: 'Deposit already marked as received.',
          status: DepositResponseStatus.confirmed,
        );
      }

      final now = DateTime.now();

      // Update stage history: close current stage and add deposit_made
      final updatedHistory = [...appointment.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length -
              1] = models.SalesAppointmentStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: now,
            note: lastEntry.note,
          );
        }
      }

      updatedHistory.add(
        models.SalesAppointmentStageHistoryEntry(
          stage: 'deposit_made',
          enteredAt: now,
          note: 'Finance confirmed deposit received.',
        ),
      );

      await _firestore.collection('appointments').doc(appointmentId).update({
        'currentStage': 'deposit_made',
        'stageEnteredAt': Timestamp.fromDate(now),
        'depositPaid': true,
        'stageHistory': updatedHistory.map((entry) => entry.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (kDebugMode) {
        print('Finance marked deposit received for $appointmentId');
      }

      return const DepositConfirmationResult(
        success: true,
        message: 'Deposit marked as received.',
        status: DepositResponseStatus.confirmed,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error handling finance deposit confirmation: $e');
      }
      return const DepositConfirmationResult(
        success: false,
        message: 'Something went wrong. Please try again later.',
        status: DepositResponseStatus.invalid,
      );
    }
  }

  String _buildDepositConfirmationLink({
    required String appointmentId,
    required String decision,
    required String token,
  }) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _depositLinkBaseProd : _depositLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/deposit-confirmation',
      queryParameters: {
        'appointmentId': appointmentId,
        'decision': decision,
        'token': token,
      },
    );

    return uri.toString();
  }

  String _buildFinanceConfirmationLink({
    required String appointmentId,
    required String token,
  }) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _depositLinkBaseProd : _depositLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/finance-confirmation',
      queryParameters: {'appointmentId': appointmentId, 'token': token},
    );

    return uri.toString();
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
  /// Convenience wrapper that calls moveAppointmentToStage with email notification
  Future<void> moveToDepositRequested(
    String appointmentId, {
    String? customerName,
    String? contractId,
  }) async {
    final note = customerName != null && contractId != null
        ? 'Contract digitally signed by $customerName (Contract ID: $contractId). Deposit request email sent.'
        : customerName != null
        ? 'Contract digitally signed by $customerName. Moving to deposit requested stage for payment processing.'
        : 'Contract digitally signed. Moving to deposit requested stage for payment processing.';

    await moveAppointmentToStage(
      appointmentId: appointmentId,
      newStage: 'deposit_requested',
      note: note,
      userId: 'system',
      userName: 'System (Contract Signing)',
      shouldSendDepositEmail: true,
    );

    if (kDebugMode) {
      print('✅ Moved appointment $appointmentId to Deposit Requested stage');
      if (contractId != null) {
        print('   Contract ID: $contractId');
      }
    }
  }
}

enum DepositResponseStatus { confirmed, declined, invalid }

class DepositConfirmationResult {
  final bool success;
  final String message;
  final DepositResponseStatus status;

  const DepositConfirmationResult({
    required this.success,
    required this.message,
    required this.status,
  });
}
