import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/streams/order.dart' as models;
import '../../models/streams/support_ticket.dart';
import '../emailjs_service.dart';
import 'support_ticket_service.dart';

// Base URLs for installation booking links
const String _installBookingLinkBaseProd = 'https://app.medwave.com';
const String _installBookingLinkBaseLocal = 'http://localhost:52961';

/// Service for managing orders in Firebase
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupportTicketService _supportTicketService = SupportTicketService();

  /// Get all orders
  Future<List<models.Order>> getAllOrders({
    String? orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('orders');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => models.Order.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all orders: $e');
      }
      rethrow;
    }
  }

  /// Get orders by stage
  Future<List<models.Order>> getOrdersByStage(String stage) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('currentStage', isEqualTo: stage)
          .get();

      final orders = snapshot.docs.map((doc) => models.Order.fromFirestore(doc)).toList();
      // Sort in memory to avoid index requirement
      orders.sort((a, b) => a.stageEnteredAt.compareTo(b.stageEnteredAt));
      return orders;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting orders by stage: $e');
      }
      rethrow;
    }
  }

  /// Get a single order by ID
  Future<models.Order?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();

      if (!doc.exists) {
        return null;
      }

      return models.Order.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting order $orderId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all orders
  Stream<List<models.Order>> ordersStream() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => models.Order.fromFirestore(doc)).toList();
          // Sort in memory instead of using orderBy to avoid index requirement
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  /// Create a new order
  Future<String> createOrder(models.Order order) async {
    try {
      final docRef = await _firestore.collection('orders').add(order.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating order: $e');
      }
      rethrow;
    }
  }

  /// Update an existing order
  Future<void> updateOrder(models.Order order) async {
    try {
      await _firestore
          .collection('orders')
          .doc(order.id)
          .update(order.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order: $e');
      }
      rethrow;
    }
  }

  /// Delete an order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting order: $e');
      }
      rethrow;
    }
  }

  /// Move order to a new stage with note
  Future<void> moveOrderToStage({
    required String orderId,
    required String newStage,
    required String note,
    required String userId,
    String? userName,
    List<models.OrderItem>? items,
    DateTime? deliveryDate,
    String? invoiceNumber,
    DateTime? installDate,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final now = DateTime.now();

      // Create stage history entry for current stage exit
      final updatedHistory = [...order.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length - 1] =
              models.OrderStageHistoryEntry(
                stage: lastEntry.stage,
                enteredAt: lastEntry.enteredAt,
                exitedAt: now,
                note: note,
              );
        }
      }

      // Add new stage history entry
      updatedHistory.add(models.OrderStageHistoryEntry(
        stage: newStage,
        enteredAt: now,
        note: note,
      ));

      // Create note for the transition
      final transitionNote = models.OrderNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...order.notes, transitionNote];

      // Update order
      final updatedOrder = order.copyWith(
        currentStage: newStage,
        stageEnteredAt: now,
        updatedAt: now,
        stageHistory: updatedHistory,
        notes: updatedNotes,
        items: items ?? order.items,
        deliveryDate: deliveryDate ?? order.deliveryDate,
        invoiceNumber: invoiceNumber ?? order.invoiceNumber,
        installDate: installDate ?? order.installDate,
      );

      await updateOrder(updatedOrder);

      // Check if we need to convert to Support Ticket (final stage)
      if (newStage == 'installed') {
        await convertToSupportTicket(
          orderId: orderId,
          userId: userId,
          userName: userName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error moving order to stage: $e');
      }
      rethrow;
    }
  }

  /// Convert order to support ticket (when reaching "Installed" stage)
  Future<String> convertToSupportTicket({
    required String orderId,
    required String userId,
    String? userName,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      // Check if already converted
      if (order.convertedToTicketId != null) {
        return order.convertedToTicketId!;
      }

      final now = DateTime.now();

      // Create new support ticket from order data
      final ticket = SupportTicket(
        id: '',
        orderId: orderId,
        customerName: order.customerName,
        email: order.email,
        phone: order.phone,
        currentStage: 'welcome', // First stage in Support stream
        issueDescription: 'Welcome to support - installation completed',
        priority: TicketPriority.low,
        createdAt: now,
        updatedAt: now,
        stageEnteredAt: now,
        stageHistory: [
          TicketStageHistoryEntry(
            stage: 'welcome',
            enteredAt: now,
            note: 'Converted from Operations order',
          ),
        ],
        notes: [
          TicketNote(
            text: 'Support ticket created from order ${order.id}',
            createdAt: now,
            createdBy: userId,
            createdByName: userName,
          ),
        ],
        createdBy: userId,
        createdByName: userName,
      );

      // Create the support ticket
      final ticketId = await _supportTicketService.createTicket(ticket);

      // Update order with ticket reference
      final updatedOrder = order.copyWith(
        convertedToTicketId: ticketId,
        updatedAt: now,
      );
      await updateOrder(updatedOrder);

      if (kDebugMode) {
        print('Converted order $orderId to support ticket $ticketId');
      }

      return ticketId;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting order to support ticket: $e');
      }
      rethrow;
    }
  }

  /// Add a note to an order
  Future<void> addNote({
    required String orderId,
    required String noteText,
    required String userId,
    String? userName,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final note = models.OrderNote(
        text: noteText,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...order.notes, note];

      await _firestore.collection('orders').doc(orderId).update({
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

  /// Search orders by customer name, email, or phone
  Future<List<models.Order>> searchOrders(String query) async {
    try {
      // Get all orders
      final allOrders = await getAllOrders();

      // Filter by query
      final lowerQuery = query.toLowerCase();
      return allOrders.where((order) {
        return order.customerName.toLowerCase().contains(lowerQuery) ||
            order.email.toLowerCase().contains(lowerQuery) ||
            order.phone.contains(query);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching orders: $e');
      }
      rethrow;
    }
  }

  /// Get order count by stage
  Future<Map<String, int>> getOrderCountsByStage() async {
    try {
      final orders = await getAllOrders();
      final counts = <String, int>{};

      for (final order in orders) {
        counts[order.currentStage] = (counts[order.currentStage] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting order counts by stage: $e');
      }
      rethrow;
    }
  }

  // ============================================================
  // Installation Booking Methods
  // ============================================================

  /// Generate a secure token for installation booking
  String _generateInstallBookingToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Build the installation booking link URL
  String _buildInstallBookingLink({
    required String orderId,
    required String token,
  }) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _installBookingLinkBaseProd : _installBookingLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/installation-booking',
      queryParameters: {
        'orderId': orderId,
        'token': token,
      },
    );

    return uri.toString();
  }

  /// Send installation booking email to customer
  /// Generates token, saves it, and sends email with booking link
  Future<bool> sendInstallationBookingEmail({
    required String orderId,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      // Generate token if not exists
      final token = order.installBookingToken ?? _generateInstallBookingToken();
      final bookingUrl = _buildInstallBookingLink(orderId: orderId, token: token);

      // Update order with token and email sent timestamp
      final now = DateTime.now();
      final updatedOrder = order.copyWith(
        installBookingToken: token,
        installBookingEmailSentAt: now,
        updatedAt: now,
      );
      await updateOrder(updatedOrder);

      // Send email
      final sent = await EmailJSService.sendInstallationBookingEmail(
        order: updatedOrder,
        bookingUrl: bookingUrl,
      );

      if (kDebugMode) {
        print('Installation booking email sent: $sent to ${order.email}');
      }

      return sent;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending installation booking email: $e');
      }
      rethrow;
    }
  }

  /// Handle customer's installation date selection
  /// Validates token, saves selected dates, moves to Priority Shipment
  Future<InstallationBookingResult> handleInstallationDateSelection({
    required String orderId,
    required String token,
    required List<DateTime> selectedDates,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        return const InstallationBookingResult(
          success: false,
          message: 'Order not found.',
          status: InstallationBookingStatus.invalid,
        );
      }

      // Validate token
      if (order.installBookingToken == null ||
          order.installBookingToken != token) {
        return const InstallationBookingResult(
          success: false,
          message: 'This link is invalid or has already been used.',
          status: InstallationBookingStatus.invalid,
        );
      }

      // Check if dates already selected
      if (order.installBookingStatus == models.InstallBookingStatus.datesSelected ||
          order.installBookingStatus == models.InstallBookingStatus.confirmed) {
        return const InstallationBookingResult(
          success: false,
          message: 'Installation dates have already been selected.',
          status: InstallationBookingStatus.alreadySelected,
        );
      }

      // Validate 3 dates selected
      if (selectedDates.length != 3) {
        return const InstallationBookingResult(
          success: false,
          message: 'Please select exactly 3 preferred dates.',
          status: InstallationBookingStatus.invalid,
        );
      }

      // Validate dates are at least 3 weeks from order creation
      final minDate = order.createdAt.add(const Duration(days: 21));
      for (final date in selectedDates) {
        if (date.isBefore(minDate)) {
          return InstallationBookingResult(
            success: false,
            message:
                'Selected dates must be at least 3 weeks from order placement.',
            status: InstallationBookingStatus.invalid,
          );
        }
      }

      final now = DateTime.now();

      // Sort dates chronologically
      final sortedDates = List<DateTime>.from(selectedDates)
        ..sort((a, b) => a.compareTo(b));

      // Update order with selected dates and move to Priority Shipment
      final updatedHistory = [...order.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length - 1] =
              models.OrderStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: now,
            note: 'Customer selected installation dates',
          );
        }
      }

      updatedHistory.add(models.OrderStageHistoryEntry(
        stage: 'priority_shipment',
        enteredAt: now,
        note: 'Moved after customer selected installation dates',
      ));

      final updatedOrder = order.copyWith(
        customerSelectedDates: sortedDates,
        installBookingStatus: models.InstallBookingStatus.datesSelected,
        currentStage: 'priority_shipment',
        stageEnteredAt: now,
        stageHistory: updatedHistory,
        updatedAt: now,
      );

      await updateOrder(updatedOrder);

      if (kDebugMode) {
        print('Installation dates selected for order $orderId: $sortedDates');
      }

      return const InstallationBookingResult(
        success: true,
        message: 'Thank you! Your preferred installation dates have been saved.',
        status: InstallationBookingStatus.success,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error handling installation date selection: $e');
      }
      return InstallationBookingResult(
        success: false,
        message: 'Something went wrong. Please try again later.',
        status: InstallationBookingStatus.invalid,
      );
    }
  }

  /// Assign installer to an order
  Future<void> assignInstaller({
    required String orderId,
    required String installerId,
    required String installerName,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final updatedOrder = order.copyWith(
        assignedInstallerId: installerId,
        assignedInstallerName: installerName,
        updatedAt: DateTime.now(),
      );

      await updateOrder(updatedOrder);

      if (kDebugMode) {
        print('Assigned installer $installerName to order $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error assigning installer: $e');
      }
      rethrow;
    }
  }

  /// Set confirmed install date (by admin)
  Future<void> setConfirmedInstallDate({
    required String orderId,
    required DateTime installDate,
    required String userId,
    String? userName,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final now = DateTime.now();
      final note = models.OrderNote(
        text: 'Install date confirmed: ${installDate.toString().split(' ')[0]}',
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedOrder = order.copyWith(
        confirmedInstallDate: installDate,
        installBookingStatus: models.InstallBookingStatus.confirmed,
        notes: [...order.notes, note],
        updatedAt: now,
      );

      await updateOrder(updatedOrder);

      if (kDebugMode) {
        print('Confirmed install date $installDate for order $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting confirmed install date: $e');
      }
      rethrow;
    }
  }

  /// Get orders sorted by earliest selected date (for Priority Shipment)
  Future<List<models.Order>> getOrdersSortedByInstallDate(String stage) async {
    try {
      final orders = await getOrdersByStage(stage);

      // Sort by earliest selected date (closest first)
      orders.sort((a, b) {
        final dateA = a.earliestSelectedDate;
        final dateB = b.earliestSelectedDate;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1; // Orders without dates go to end
        if (dateB == null) return -1;

        return dateA.compareTo(dateB);
      });

      return orders;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting orders sorted by install date: $e');
      }
      rethrow;
    }
  }

  // ============================================================
  // Inventory Picking Methods
  // ============================================================

  /// Update picked items status for an order
  Future<void> updatePickedItems({
    required String orderId,
    required Map<String, bool> pickedItems,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'pickedItems': pickedItems,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('Updated picked items for order $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating picked items: $e');
      }
      rethrow;
    }
  }

  /// Set picked details (timestamp and user)
  Future<void> setPickedDetails({
    required String orderId,
    required String pickedBy,
    String? pickedByName,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'pickedAt': Timestamp.fromDate(DateTime.now()),
        'pickedBy': pickedBy,
        'pickedByName': pickedByName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('Set picked details for order $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting picked details: $e');
      }
      rethrow;
    }
  }

  /// Add shipping details (tracking number and waybill photo)
  Future<void> addShippingDetails({
    required String orderId,
    required String trackingNumber,
    required String waybillPhotoUrl,
    required String userId,
    String? userName,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final now = DateTime.now();

      // Create note for shipping
      final note = models.OrderNote(
        text: 'Shipping details added. Tracking: $trackingNumber',
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      await _firestore.collection('orders').doc(orderId).update({
        'trackingNumber': trackingNumber,
        'waybillPhotoUrl': waybillPhotoUrl,
        'notes': [...order.notes.map((n) => n.toMap()), note.toMap()],
        'updatedAt': Timestamp.fromDate(now),
      });

      if (kDebugMode) {
        print('Added shipping details for order $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding shipping details: $e');
      }
      rethrow;
    }
  }

  // ============================================================
  // Lead Deletion Methods (Testing)
  // ============================================================

  /// Delete a lead completely along with all related data
  /// This is a destructive action intended for testing purposes.
  /// Deletes: Order, Sales Appointment, Contracts, Support Ticket (if exists)
  Future<void> deleteLeadCompletely({
    required String orderId,
  }) async {
    try {
      // Get the order first
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final appointmentId = order.appointmentId;
      final supportTicketId = order.convertedToTicketId;

      // Use a batch for atomic deletion
      final batch = _firestore.batch();

      // 1. Delete all contracts linked to the appointment
      if (appointmentId.isNotEmpty) {
        final contractsSnapshot = await _firestore
            .collection('contracts')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        for (final doc in contractsSnapshot.docs) {
          batch.delete(doc.reference);
          if (kDebugMode) {
            print('Queued contract for deletion: ${doc.id}');
          }
        }
      }

      // 2. Delete support ticket if it exists
      if (supportTicketId != null && supportTicketId.isNotEmpty) {
        final ticketRef = _firestore.collection('support_tickets').doc(supportTicketId);
        batch.delete(ticketRef);
        if (kDebugMode) {
          print('Queued support ticket for deletion: $supportTicketId');
        }
      }

      // 3. Delete the sales appointment
      if (appointmentId.isNotEmpty) {
        final appointmentRef = _firestore.collection('appointments').doc(appointmentId);
        batch.delete(appointmentRef);
        if (kDebugMode) {
          print('Queued appointment for deletion: $appointmentId');
        }
      }

      // 4. Delete the order itself
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.delete(orderRef);
      if (kDebugMode) {
        print('Queued order for deletion: $orderId');
      }

      // Commit the batch
      await batch.commit();

      if (kDebugMode) {
        print('Successfully deleted lead completely: $orderId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting lead completely: $e');
      }
      rethrow;
    }
  }

  /// Get orders for warehouse (priority_shipment and inventory_packing_list)
  /// with confirmedInstallDate within next 30 days
  Stream<List<models.Order>> getWarehouseOrdersStream() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final thirtyDaysFromNow = now.add(const Duration(days: 30));

          final orders = snapshot.docs
              .map((doc) => models.Order.fromFirestore(doc))
              .where((order) {
                // Check stage
                final validStage = order.currentStage == 'priority_shipment' ||
                    order.currentStage == 'inventory_packing_list';
                if (!validStage) return false;

                // Check install date within 30 days
                if (order.confirmedInstallDate == null) return false;
                final installDate = order.confirmedInstallDate!;
                return installDate.isAfter(now.subtract(const Duration(days: 1))) &&
                    installDate.isBefore(thirtyDaysFromNow);
              })
              .toList();

          // Sort by confirmedInstallDate ascending
          orders.sort((a, b) {
            final dateA = a.confirmedInstallDate;
            final dateB = b.confirmedInstallDate;
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateA.compareTo(dateB);
          });

          return orders;
        });
  }
}

/// Result status for installation booking
enum InstallationBookingStatus {
  success,
  invalid,
  alreadySelected,
}

/// Result of installation booking operation
class InstallationBookingResult {
  final bool success;
  final String message;
  final InstallationBookingStatus status;

  const InstallationBookingResult({
    required this.success,
    required this.message,
    required this.status,
  });
}

