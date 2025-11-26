import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/streams/order.dart' as models;
import '../../models/streams/support_ticket.dart';
import 'support_ticket_service.dart';

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
}

