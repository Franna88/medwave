import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/streams/order.dart' as models;
import '../../models/streams/support_ticket.dart';
import '../emailjs_service.dart';
import '../whatsapp_service.dart';
import 'support_ticket_service.dart';
import '../pdf/invoice_pdf_service.dart';

// Base URLs for installation booking links
const String _installBookingLinkBaseProd = 'https://app.medwave.com';
const String _installBookingLinkBaseLocal = 'http://localhost:52961';

// Base URLs for payment confirmation links
const String _paymentLinkBaseProd = 'https://app.medwave.com';
const String _paymentLinkBaseLocal = 'http://localhost:52961';

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
      return snapshot.docs
          .map((doc) => models.Order.fromFirestore(doc))
          .toList();
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

      final orders = snapshot.docs
          .map((doc) => models.Order.fromFirestore(doc))
          .toList();
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
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => models.Order.fromFirestore(doc))
          .toList();
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
      await _firestore.collection('orders').doc(order.id).update(order.toMap());
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
    List<String>? proofOfInstallationPhotoUrls,
    String? customerSignaturePhotoUrl,
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
          updatedHistory[updatedHistory.length -
              1] = models.OrderStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: now,
            note: note,
          );
        }
      }

      // Add new stage history entry
      updatedHistory.add(
        models.OrderStageHistoryEntry(
          stage: newStage,
          enteredAt: now,
          note: note,
        ),
      );

      // Create note for the transition
      final transitionNote = models.OrderNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...order.notes, transitionNote];

      // Determine if we need to send invoice email (when moving to out_for_delivery)
      final movingToOutForDelivery = newStage == 'out_for_delivery';

      String? confirmationToken = order.paymentConfirmationToken;
      String? confirmationStatus = order.paymentConfirmationStatus;
      DateTime? confirmationSentAt = order.paymentConfirmationSentAt;

      if (movingToOutForDelivery) {
        confirmationToken = const Uuid().v4();
        confirmationStatus = 'pending';
        // Don't set confirmationSentAt here - it will be set when payment reminder email is sent
        // (when customer clicks the invoice link)
      }

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
        proofOfInstallationPhotoUrls:
            proofOfInstallationPhotoUrls ?? order.proofOfInstallationPhotoUrls,
        customerSignaturePhotoUrl:
            customerSignaturePhotoUrl ?? order.customerSignaturePhotoUrl,
        paymentConfirmationToken:
            confirmationToken ?? order.paymentConfirmationToken,
        paymentConfirmationStatus:
            confirmationStatus ?? order.paymentConfirmationStatus,
        paymentConfirmationSentAt:
            confirmationSentAt ?? order.paymentConfirmationSentAt,
      );

      await updateOrder(updatedOrder);

      // Send out for delivery email when moving to that stage
      // Skip for split orders (Order 2) - email was already sent with Order 1
      if (newStage == 'out_for_delivery' &&
          updatedOrder.splitFromOrderId == null) {
        // Always send email when order moves to out_for_delivery stage
        // Email template handles missing data gracefully
        final emailSent = await EmailJSService.sendOutForDeliveryEmail(
          order: updatedOrder,
        );
        if (kDebugMode) {
          print(
            'Out for delivery email ${emailSent ? 'sent' : 'failed'} for order $orderId',
          );
        }
      } else if (newStage == 'out_for_delivery' &&
          updatedOrder.splitFromOrderId != null) {
        if (kDebugMode) {
          print(
            'Skipping out for delivery email for split order $orderId (email already sent with Order 1)',
          );
        }
      }

      // Send invoice email if moving to out_for_delivery stage
      // Skip for split orders (Order 2) - invoice email was already sent with Order 1
      if (movingToOutForDelivery && updatedOrder.splitFromOrderId == null) {
        try {
          // Fetch deposit amount and shipping address from appointment
          double depositAmount = 0;
          String? shippingAddress;
          try {
            if (order.appointmentId.isNotEmpty) {
              final appointmentDoc = await _firestore
                  .collection('appointments')
                  .doc(order.appointmentId)
                  .get();

              if (appointmentDoc.exists) {
                final appointmentData = appointmentDoc.data();
                if (appointmentData != null) {
                  // Get deposit amount
                  final storedDeposit = appointmentData['depositAmount'];
                  if (storedDeposit != null) {
                    depositAmount = (storedDeposit as num).toDouble();
                  } else {
                    // Calculate 40% of total from optInProducts if deposit not stored
                    final optInProducts =
                        appointmentData['optInProducts'] as List<dynamic>?;
                    if (optInProducts != null && optInProducts.isNotEmpty) {
                      double total = 0;
                      for (final product in optInProducts) {
                        if (product is Map<String, dynamic>) {
                          final price = product['price'];
                          final quantity =
                              product['quantity'] ??
                              1; // Default to 1 if not set
                          if (price != null) {
                            total += (price as num).toDouble() * quantity;
                          }
                        }
                      }
                      depositAmount = total * 0.40; // 40% deposit
                    }
                  }

                  // Get shipping address
                  final optInQuestions =
                      appointmentData['optInQuestions']
                          as Map<String, dynamic>?;
                  if (optInQuestions != null) {
                    shippingAddress = optInQuestions['Shipping address']
                        ?.toString();
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fetching appointment for deposit/shipping: $e');
            }
            // Continue with depositAmount = 0 if fetch fails
          }

          // Calculate invoice amount (total - deposit)
          // For split orders, include items from both parent and split order
          List<models.OrderItem> allItems = List.from(updatedOrder.items);

          // Fix item quantities from appointment optInProducts if available
          // This ensures quantities are correct even if order data has incorrect quantities
          try {
            if (order.appointmentId.isNotEmpty) {
              final appointmentDoc = await _firestore
                  .collection('appointments')
                  .doc(order.appointmentId)
                  .get();

              if (appointmentDoc.exists) {
                final appointmentData = appointmentDoc.data();
                if (appointmentData != null) {
                  final optInProducts =
                      appointmentData['optInProducts'] as List<dynamic>?;
                  if (optInProducts != null && optInProducts.isNotEmpty) {
                    // Create a map of product name to quantity from appointment
                    final appointmentQuantities = <String, int>{};
                    for (final product in optInProducts) {
                      if (product is Map<String, dynamic>) {
                        final name = product['name']?.toString();
                        final quantity = product['quantity'];
                        if (name != null && quantity != null) {
                          final qty = (quantity is num) ? quantity.toInt() : 1;
                          // If same product appears multiple times, sum the quantities
                          appointmentQuantities[name] =
                              (appointmentQuantities[name] ?? 0) + qty;
                        }
                      }
                    }

                    // Update allItems with correct quantities from appointment
                    allItems = allItems.map((item) {
                      final correctQty = appointmentQuantities[item.name];
                      if (correctQty != null && correctQty != item.quantity) {
                        // Update quantity from appointment data
                        return models.OrderItem(
                          name: item.name,
                          quantity: correctQty,
                          price: item.price,
                        );
                      }
                      return item;
                    }).toList();
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error fixing item quantities from appointment: $e');
            }
            // Continue with existing items if fix fails
          }

          // If this is a split order (Order 2), include items from parent order (Order 1)
          if (updatedOrder.splitFromOrderId != null) {
            try {
              final parentOrder = await getOrder(
                updatedOrder.splitFromOrderId!,
              );
              if (parentOrder != null) {
                // Add parent order items to the list
                allItems.addAll(parentOrder.items);
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error fetching parent order for invoice: $e');
              }
              // Continue with current order items only if parent fetch fails
            }
          } else {
            // If this is Order 1, check if there's a split order (Order 2)
            try {
              // Find split order where splitFromOrderId matches this order's id
              final splitOrdersQuery = await _firestore
                  .collection('orders')
                  .where('splitFromOrderId', isEqualTo: order.id)
                  .limit(1)
                  .get();

              if (splitOrdersQuery.docs.isNotEmpty) {
                final splitOrder = models.Order.fromFirestore(
                  splitOrdersQuery.docs.first,
                );
                // Add split order items to the list
                allItems.addAll(splitOrder.items);
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error fetching split order for invoice: $e');
              }
              // Continue with current order items only if split order fetch fails
            }
          }

          // Calculate total from all items (both orders if split)
          final totalInvoice = allItems.fold<double>(
            0,
            (sum, item) => sum + ((item.price ?? 0) * item.quantity),
          );

          // Cap deposit amount at order total to prevent negative invoice amounts
          final cappedDepositAmount = depositAmount > totalInvoice
              ? totalInvoice
              : depositAmount;

          // Ensure invoice amount is never negative
          final invoiceAmount = max(0.0, totalInvoice - cappedDepositAmount);

          // Generate invoice number if not already set
          final invoiceNumber =
              updatedOrder.invoiceNumber ?? _generateInvoiceNumber(order.id);

          // Update order with invoice number and combined items (for split orders) before generating PDF
          final orderWithInvoiceNumber = updatedOrder.copyWith(
            invoiceNumber: invoiceNumber,
            items: allItems, // Use combined items from both orders if split
          );

          // Generate invoice PDF
          final invoicePdfService = InvoicePdfService();
          final pdfBytes = await invoicePdfService.generatePdfBytes(
            order: orderWithInvoiceNumber,
            depositAmount: cappedDepositAmount,
            shippingAddress: shippingAddress,
          );

          // Upload PDF to Firebase Storage
          final pdfUrl = await invoicePdfService.uploadPdfToStorage(
            pdfBytes: pdfBytes,
            orderId: order.id,
          );

          // Store invoice PDF URL and invoice number in order
          await _firestore.collection('orders').doc(orderId).update({
            'invoicePdfUrl': pdfUrl,
            'invoiceNumber': invoiceNumber,
          });

          // Build invoice link (for backward compatibility)
          final invoiceLink = _buildInvoiceLink(
            orderId: order.id,
            token: confirmationToken!,
          );

          // Send invoice email with PDF URL (use order with invoice number)
          final invoiceEmailSent = await EmailJSService.sendInvoiceEmail(
            order: orderWithInvoiceNumber,
            invoiceLink: invoiceLink,
            invoicePdfUrl: pdfUrl,
            invoiceAmount: invoiceAmount,
          );

          if (kDebugMode) {
            if (invoiceEmailSent) {
              print(
                'Invoice email sent for order $orderId (Invoice #: $invoiceNumber, Amount: R ${invoiceAmount.toStringAsFixed(2)}, Deposit: R ${cappedDepositAmount.toStringAsFixed(2)}, Total: R ${totalInvoice.toStringAsFixed(2)})',
              );
            } else {
              print('Failed to send invoice email for order $orderId');
            }
          }

          // Note: paymentConfirmationSentAt is set when the payment reminder email is sent
          // (when customer clicks the invoice link), not when the invoice email is sent
        } catch (e) {
          if (kDebugMode) {
            print('Error generating and sending invoice: $e');
          }
          // Don't throw - allow order to move to out_for_delivery stage even if invoice fails
        }
      } else if (movingToOutForDelivery &&
          updatedOrder.splitFromOrderId != null) {
        if (kDebugMode) {
          print(
            'Skipping invoice email for split order $orderId (invoice email already sent with Order 1)',
          );
        }
      }

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
        : (kReleaseMode
              ? _installBookingLinkBaseProd
              : _installBookingLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/installation-booking',
      queryParameters: {'orderId': orderId, 'token': token},
    );

    return uri.toString();
  }

  /// Send installation booking email to customer
  /// Generates token, saves it, and sends email with booking link
  /// Note: For split orders (Order 2), this email was already sent with Order 1
  Future<bool> sendInstallationBookingEmail({required String orderId}) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      // Skip for split orders - installation booking email was already sent with Order 1
      if (order.splitFromOrderId != null) {
        if (kDebugMode) {
          print(
            'Skipping installation booking email for split order $orderId (email already sent with Order 1)',
          );
        }
        return true; // Return true to indicate "handled" (even though we skipped it)
      }

      // Generate token if not exists
      final token = order.installBookingToken ?? _generateInstallBookingToken();
      final bookingUrl = _buildInstallBookingLink(
        orderId: orderId,
        token: token,
      );

      // Update order with token and email sent timestamp
      final now = DateTime.now();
      final updatedOrder = order.copyWith(
        installBookingToken: token,
        installBookingEmailSentAt: now,
        updatedAt: now,
      );
      await updateOrder(updatedOrder);

      // Send email
      final emailSent = await EmailJSService.sendInstallationBookingEmail(
        order: updatedOrder,
        bookingUrl: bookingUrl,
      );

      if (kDebugMode) {
        print('Installation booking email sent: $emailSent to ${order.email}');
      }

      // Also send WhatsApp notification to remind customer to check their email
      if (WhatsAppService.isConfigured() &&
          WhatsAppService.isValidPhoneNumber(order.phone)) {
        final whatsappResult =
            await WhatsAppService.sendInstallationBookingReminder(
              customerPhone: order.phone,
              customerName: order.customerName,
            );

        if (kDebugMode) {
          print(
            'Installation booking WhatsApp sent: ${whatsappResult.success} to ${order.phone}',
          );
          if (!whatsappResult.success) {
            print('WhatsApp error: ${whatsappResult.message}');
          }
        }
      } else if (kDebugMode) {
        if (!WhatsAppService.isConfigured()) {
          print('WhatsApp not configured - skipping notification');
        } else {
          print('Invalid phone number for WhatsApp: ${order.phone}');
        }
      }

      return emailSent;
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
      if (order.installBookingStatus ==
              models.InstallBookingStatus.datesSelected ||
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

      // Validate dates are at least 2 weeks from order creation
      // Normalize order creation date to start of day to ensure accurate calculation
      final orderDate = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      final minDate = orderDate.add(const Duration(days: 14));
      for (final date in selectedDates) {
        if (date.isBefore(minDate)) {
          return InstallationBookingResult(
            success: false,
            message:
                'Selected dates must be at least 2 weeks from order placement.',
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
          updatedHistory[updatedHistory.length -
              1] = models.OrderStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: now,
            note: 'Customer selected installation dates',
          );
        }
      }

      updatedHistory.add(
        models.OrderStageHistoryEntry(
          stage: 'priority_shipment',
          enteredAt: now,
          note: 'Moved after customer selected installation dates',
        ),
      );

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
        message:
            'Thank you! Your preferred installation dates have been saved.',
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
    String? installerPhone,
    String? installerEmail,
  }) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      final updatedOrder = order.copyWith(
        assignedInstallerId: installerId,
        assignedInstallerName: installerName,
        assignedInstallerPhone: installerPhone,
        assignedInstallerEmail: installerEmail,
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

      // Validate that installer is assigned or "No Installation Required" is selected
      // Allow "No Installation Required" option
      if (order.assignedInstallerId == null ||
          (order.assignedInstallerId!.isEmpty &&
              order.assignedInstallerId != 'NO_INSTALLATION_REQUIRED')) {
        throw Exception(
          'Installer must be assigned or "No Installation Required" must be selected before confirming installation date',
        );
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
    String? trackingNumber,
    String? deliveryType,
    String? vehicleRegistrationNumber,
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
      final deliveryTypeValue = deliveryType ?? 'courier';

      // Create note for shipping
      final identifier = deliveryTypeValue == 'courier'
          ? 'Tracking: ${trackingNumber ?? 'N/A'}'
          : 'Vehicle Registration: ${vehicleRegistrationNumber ?? 'N/A'}';
      final note = models.OrderNote(
        text:
            'Shipping details added via ${deliveryTypeValue == 'courier' ? 'courier' : 'manual delivery'}. $identifier',
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updateData = <String, dynamic>{
        'waybillPhotoUrl': waybillPhotoUrl,
        'deliveryType': deliveryTypeValue,
        'notes': [...order.notes.map((n) => n.toMap()), note.toMap()],
        'updatedAt': Timestamp.fromDate(now),
      };

      if (deliveryTypeValue == 'courier' && trackingNumber != null) {
        updateData['trackingNumber'] = trackingNumber;
        // Clear vehicle registration if switching to courier
        updateData['vehicleRegistrationNumber'] = null;
      } else if (deliveryTypeValue == 'manual' &&
          vehicleRegistrationNumber != null) {
        updateData['vehicleRegistrationNumber'] = vehicleRegistrationNumber;
        // Clear tracking number if switching to manual
        updateData['trackingNumber'] = null;
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);

      if (kDebugMode) {
        print(
          'Added shipping details for order $orderId (delivery type: $deliveryTypeValue)',
        );
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
  Future<void> deleteLeadCompletely({required String orderId}) async {
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
        final ticketRef = _firestore
            .collection('support_tickets')
            .doc(supportTicketId);
        batch.delete(ticketRef);
        if (kDebugMode) {
          print('Queued support ticket for deletion: $supportTicketId');
        }
      }

      // 3. Delete the sales appointment
      if (appointmentId.isNotEmpty) {
        final appointmentRef = _firestore
            .collection('appointments')
            .doc(appointmentId);
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
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));

      final orders = snapshot.docs
          .map((doc) => models.Order.fromFirestore(doc))
          .where((order) {
            // Check stage
            final validStage =
                order.currentStage == 'priority_shipment' ||
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

  // ============================================================
  // Payment Confirmation Methods
  // ============================================================

  String _buildPaymentConfirmationLink({
    required String orderId,
    required String decision,
    required String token,
  }) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _paymentLinkBaseProd : _paymentLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/payment-confirmation',
      queryParameters: {
        'orderId': orderId,
        'decision': decision,
        'token': token,
      },
    );

    return uri.toString();
  }

  String _buildFinancePaymentConfirmationLink({
    required String orderId,
    required String token,
  }) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _paymentLinkBaseProd : _paymentLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/finance-payment-confirmation',
      queryParameters: {'orderId': orderId, 'token': token},
    );

    return uri.toString();
  }

  String _buildInvoiceLink({required String orderId, required String token}) {
    final runtimeOrigin = Uri.base.origin;
    final baseOrigin = runtimeOrigin.isNotEmpty
        ? runtimeOrigin
        : (kReleaseMode ? _paymentLinkBaseProd : _paymentLinkBaseLocal);

    final uri = Uri.parse(baseOrigin).replace(
      path: '/invoice-view',
      queryParameters: {'orderId': orderId, 'token': token},
    );

    return uri.toString();
  }

  /// Handle payment confirmation response from public link
  Future<PaymentConfirmationResult> handlePaymentConfirmationResponse({
    required String orderId,
    required String decision,
    required String token,
  }) async {
    final normalizedDecision = decision.toLowerCase();
    if (normalizedDecision != 'yes' && normalizedDecision != 'no') {
      return const PaymentConfirmationResult(
        success: false,
        message: 'Unknown decision.',
        status: PaymentResponseStatus.invalid,
      );
    }

    try {
      // 1. Fetch the order to validate token
      final order = await getOrder(orderId);

      if (order == null) {
        return const PaymentConfirmationResult(
          success: false,
          message: 'Order not found.',
          status: PaymentResponseStatus.invalid,
        );
      }

      // 2. Validate token matches
      if (order.paymentConfirmationToken != token) {
        return const PaymentConfirmationResult(
          success: false,
          message: 'Invalid or expired confirmation link.',
          status: PaymentResponseStatus.invalid,
        );
      }

      // 3. Check if already responded
      if (order.paymentConfirmationStatus != null &&
          order.paymentConfirmationStatus != 'pending') {
        return const PaymentConfirmationResult(
          success: false,
          message: 'You have already responded to this confirmation.',
          status: PaymentResponseStatus.invalid,
        );
      }

      // 4. Prepare update data
      final now = DateTime.now();
      final isConfirmed = normalizedDecision == 'yes';
      final newStatus = isConfirmed ? 'confirmed' : 'declined';

      // Create stage history note
      final stageNote = isConfirmed
          ? 'Customer ${order.customerName} has made payment, finance department will confirm'
          : 'We will send a follow up email in 2 days';

      // Add new stage history entry (append to existing history)
      final updatedHistory = [...order.stageHistory];
      if (updatedHistory.isNotEmpty) {
        // Update the last entry's note if it's the current stage and has no exit time
        final lastEntry = updatedHistory.last;
        if (lastEntry.stage == 'installed' && lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length -
              1] = models.OrderStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: lastEntry.exitedAt,
            note: stageNote,
          );
        }
      }

      // 5. Update order in Firestore
      await _firestore.collection('orders').doc(orderId).update({
        'paymentConfirmationStatus': newStatus,
        'paymentConfirmationRespondedAt': Timestamp.fromDate(now),
        'stageHistory': updatedHistory.map((entry) => entry.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      print('✅ PAYMENT CONFIRMATION: $orderId -> $newStatus');
      print('📧 Customer: ${order.customerName} (${order.email})');

      if (isConfirmed) {
        print('🔵 Customer said YES - Sending finance notification...');
        try {
          final financeUrl = _buildFinancePaymentConfirmationLink(
            orderId: order.id,
            token: order.paymentConfirmationToken ?? token,
          );

          print('📤 Calling EmailJS.sendFinancePaymentNotification...');
          final sent = await EmailJSService.sendFinancePaymentNotification(
            order: order,
            financeEmail: 'tertiusva@gmail.com',
            yesUrl: financeUrl,
            noUrl: financeUrl,
            yesLabel: 'Payment received',
            noLabel: '',
            description:
                'Please confirm you have received the customer payment.',
          );

          print('✉️ Finance email sent status: $sent');
          if (sent) {
            print('✅ SUCCESS: Finance team notified at tertiusva@gmail.com');
          } else {
            print(
              '❌ FAILED: Finance email was not sent (EmailJS returned false)',
            );
          }
        } catch (e) {
          print('❌ ERROR sending finance notification: $e');
        }
      } else {
        print('🔴 Customer said NO - Will follow up in 2 days');
      }

      // 6. Return success result
      return PaymentConfirmationResult(
        success: true,
        message: isConfirmed
            ? 'Thank you for confirming your payment.'
            : 'Thank you for your response.',
        status: isConfirmed
            ? PaymentResponseStatus.confirmed
            : PaymentResponseStatus.declined,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error handling payment confirmation response: $e');
      }
      return const PaymentConfirmationResult(
        success: false,
        message: 'Something went wrong. Please try again later.',
        status: PaymentResponseStatus.invalid,
      );
    }
  }

  /// Handle finance confirmation (single button) to mark payment as received
  Future<PaymentConfirmationResult> handleFinancePaymentConfirmation({
    required String orderId,
    required String token,
  }) async {
    try {
      final order = await getOrder(orderId);

      if (order == null) {
        return const PaymentConfirmationResult(
          success: false,
          message: 'Order not found.',
          status: PaymentResponseStatus.invalid,
        );
      }

      if (order.paymentConfirmationToken != token) {
        return const PaymentConfirmationResult(
          success: false,
          message: 'Invalid or expired confirmation link.',
          status: PaymentResponseStatus.invalid,
        );
      }

      if (order.paymentConfirmationStatus != 'confirmed') {
        return const PaymentConfirmationResult(
          success: false,
          message: 'Customer has not confirmed payment yet.',
          status: PaymentResponseStatus.invalid,
        );
      }

      // Finance confirms receipt - update stage history
      final now = DateTime.now();
      final updatedHistory = [...order.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.stage == 'installed' && lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length -
              1] = models.OrderStageHistoryEntry(
            stage: lastEntry.stage,
            enteredAt: lastEntry.enteredAt,
            exitedAt: lastEntry.exitedAt,
            note:
                'Payment confirmed by finance department. Order completed successfully.',
          );
        }
      }

      await _firestore.collection('orders').doc(orderId).update({
        'stageHistory': updatedHistory.map((entry) => entry.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(now),
      });

      print('✅ FINANCE PAYMENT CONFIRMATION: $orderId');
      print('📧 Order: ${order.customerName} (${order.email})');

      // Send thank you email to customer
      try {
        final thankYouEmailSent = await EmailJSService.sendThankYouPaymentEmail(
          order: order,
        );
        if (kDebugMode) {
          if (thankYouEmailSent) {
            print('✅ Thank you email sent to customer');
          } else {
            print('❌ Failed to send thank you email to customer');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error sending thank you email: $e');
        }
      }

      return const PaymentConfirmationResult(
        success: true,
        message: 'Payment confirmed. Thank you!',
        status: PaymentResponseStatus.confirmed,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error handling finance payment confirmation: $e');
      }
      return const PaymentConfirmationResult(
        success: false,
        message: 'Something went wrong. Please try again later.',
        status: PaymentResponseStatus.invalid,
      );
    }
  }

  /// Send payment confirmation email after customer views invoice
  /// This is called when the customer clicks the invoice link
  /// Note: For split orders (Order 2), this email was already sent with Order 1
  Future<bool> sendPaymentConfirmationEmailAfterInvoice({
    required String orderId,
    required String token,
  }) async {
    try {
      // Get order
      final order = await getOrder(orderId);
      if (order == null) {
        if (kDebugMode) {
          print('Order not found: $orderId');
        }
        return false;
      }

      // Skip for split orders - payment confirmation email was already sent with Order 1
      if (order.splitFromOrderId != null) {
        if (kDebugMode) {
          print(
            'Skipping payment confirmation email for split order $orderId (email already sent with Order 1)',
          );
        }
        return true; // Return true to indicate "handled" (even though we skipped it)
      }

      // Validate token
      if (order.paymentConfirmationToken != token) {
        if (kDebugMode) {
          print('Invalid token for order: $orderId');
        }
        return false;
      }

      // Check if payment confirmation email was already sent (prevent duplicates)
      if (order.paymentConfirmationSentAt != null) {
        // Check if it was sent more than 1 minute ago (to allow retries for recent sends)
        final timeSinceSent = DateTime.now().difference(
          order.paymentConfirmationSentAt!,
        );
        if (timeSinceSent.inMinutes < 1) {
          if (kDebugMode) {
            print(
              'Payment confirmation email already sent recently for order: $orderId',
            );
          }
          return true; // Already sent, return success
        }
      }

      // Calculate remaining payment: total invoice - deposit
      final totalInvoice = order.items.fold<double>(
        0,
        (sum, item) => sum + ((item.price ?? 0) * item.quantity),
      );

      // Get deposit amount from appointment
      double depositAmount = 0;
      try {
        if (order.appointmentId.isNotEmpty) {
          final appointmentDoc = await _firestore
              .collection('appointments')
              .doc(order.appointmentId)
              .get();

          if (appointmentDoc.exists) {
            final appointmentData = appointmentDoc.data();
            if (appointmentData != null) {
              final storedDeposit = appointmentData['depositAmount'];
              if (storedDeposit != null) {
                depositAmount = (storedDeposit as num).toDouble();
              } else {
                // Calculate 40% of total from optInProducts
                final optInProducts =
                    appointmentData['optInProducts'] as List<dynamic>?;
                if (optInProducts != null && optInProducts.isNotEmpty) {
                  double total = 0;
                  for (final product in optInProducts) {
                    if (product is Map<String, dynamic>) {
                      final price = product['price'];
                      final quantity =
                          product['quantity'] ?? 1; // Default to 1 if not set
                      if (price != null) {
                        total += (price as num).toDouble() * quantity;
                      }
                    }
                  }
                  depositAmount = total * 0.40; // 40% deposit
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching appointment for deposit: $e');
        }
      }

      final remainingPayment = totalInvoice - depositAmount;

      // Build yes/no URLs
      final yesUrl = _buildPaymentConfirmationLink(
        orderId: order.id,
        decision: 'yes',
        token: token,
      );
      final noUrl = _buildPaymentConfirmationLink(
        orderId: order.id,
        decision: 'no',
        token: token,
      );

      // Send payment confirmation email
      final emailSent = await EmailJSService.sendCustomerPaymentRequest(
        order: order,
        yesUrl: yesUrl,
        noUrl: noUrl,
        remainingPaymentAmount: remainingPayment,
      );

      if (emailSent) {
        // Update order with paymentConfirmationSentAt timestamp
        await _firestore.collection('orders').doc(orderId).update({
          'paymentConfirmationSentAt': Timestamp.fromDate(DateTime.now()),
        });

        if (kDebugMode) {
          print(
            'Payment confirmation email sent for order $orderId (remaining: R ${remainingPayment.toStringAsFixed(2)})',
          );
        }
      } else {
        if (kDebugMode) {
          print('Failed to send payment confirmation email for order $orderId');
        }
      }

      return emailSent;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending payment confirmation email after invoice: $e');
      }
      return false;
    }
  }

  /// Split order for overridden items (out of stock items)
  /// Creates a new order (Order 2) with only the overridden items
  /// Removes overridden items from the original order (Order 1)
  Future<String> splitOrderForOverriddenItems({
    required String orderId,
    required List<String> overriddenItemNames, // Items to move to new order
    required String userId,
    String? userName,
  }) async {
    try {
      // Fetch the original order
      final originalOrder = await getOrder(orderId);
      if (originalOrder == null) {
        throw Exception('Order not found');
      }

      // Validate items exist
      final itemNames = originalOrder.items.map((i) => i.name).toList();
      for (final itemName in overriddenItemNames) {
        if (!itemNames.contains(itemName)) {
          throw Exception('Item "$itemName" not found in order');
        }
      }

      // Validate items are not already picked
      // Only prevent override of items that have been picked - allow override of unpicked out-of-stock items
      for (final itemName in overriddenItemNames) {
        if (originalOrder.pickedItems[itemName] == true) {
          throw Exception(
            'Item "$itemName" has already been picked by the warehouse team and cannot be overridden.',
          );
        }
      }

      final now = DateTime.now();

      // Extract overridden items
      final overriddenItems = originalOrder.items
          .where((item) => overriddenItemNames.contains(item.name))
          .toList();

      // Get remaining items for Order 1
      final remainingItems = originalOrder.items
          .where((item) => !overriddenItemNames.contains(item.name))
          .toList();

      // Build shipped items from parent order (Order 1)
      // Include ALL items from Order 1 that have shipping information
      final List<models.ShippedItemFromParent> shippedItems = [];
      if (originalOrder.trackingNumber != null &&
          originalOrder.trackingNumber!.isNotEmpty) {
        // Order 1 has shipping info - include all remaining items
        for (final item in remainingItems) {
          shippedItems.add(
            models.ShippedItemFromParent(
              itemName: item.name,
              quantity: item.quantity,
              trackingNumber: originalOrder.trackingNumber,
              waybillNumber: originalOrder
                  .trackingNumber, // Use trackingNumber as waybill number
              waybillPhotoUrl: originalOrder.waybillPhotoUrl,
            ),
          );
        }
      }

      // Create new order (Order 2) with overridden items
      final newOrder = models.Order(
        id: '', // Will be set by Firestore
        appointmentId: originalOrder.appointmentId,
        customerName: originalOrder.customerName,
        email: originalOrder.email,
        phone: originalOrder.phone,
        currentStage: originalOrder.currentStage, // Same stage as original
        orderDate: originalOrder.orderDate,
        items: overriddenItems, // Only overridden items
        deliveryDate: originalOrder.deliveryDate,
        invoiceNumber:
            originalOrder.invoiceNumber, // Same invoice number as Order 1
        installDate: originalOrder.installDate,
        createdAt: now,
        updatedAt: now,
        stageEnteredAt: originalOrder.stageEnteredAt,
        stageHistory: [
          models.OrderStageHistoryEntry(
            stage: originalOrder.currentStage,
            enteredAt: now,
            note:
                'Order split from Order #${originalOrder.id.substring(0, 8)} - Overridden items due to out of stock',
          ),
        ],
        notes: [
          models.OrderNote(
            text:
                'Order created by splitting Order #${originalOrder.id.substring(0, 8)}. Items overridden due to out of stock.',
            createdAt: now,
            createdBy: userId,
            createdByName: userName,
          ),
        ],
        createdBy: userId,
        createdByName: userName,
        formScore: originalOrder.formScore,
        // Installation booking fields
        installBookingToken: originalOrder.installBookingToken,
        customerSelectedDates: originalOrder.customerSelectedDates,
        confirmedInstallDate: originalOrder.confirmedInstallDate,
        assignedInstallerId: originalOrder.assignedInstallerId,
        assignedInstallerName: originalOrder.assignedInstallerName,
        assignedInstallerPhone: originalOrder.assignedInstallerPhone,
        assignedInstallerEmail: originalOrder.assignedInstallerEmail,
        installBookingStatus: originalOrder.installBookingStatus,
        installBookingEmailSentAt: originalOrder.installBookingEmailSentAt,
        // Inventory picking fields - start fresh for new order
        pickedItems: {},
        // Order splitting fields
        splitFromOrderId: originalOrder.id, // Reference to Order 1
        shippedItemsFromParentOrder: shippedItems, // Items shipped in Order 1
        remainingItemsFromParentOrder:
            remainingItems, // Items from Order 1 that were NOT overridden
        // Priority order flag
        isPriorityOrder: originalOrder.isPriorityOrder,
      );

      // Create the new order
      final newOrderId = await createOrder(newOrder);

      // Update original order (Order 1) to remove overridden items
      final updatedPickedItems = Map<String, bool>.from(
        originalOrder.pickedItems,
      );
      // Remove overridden items from pickedItems map
      for (final itemName in overriddenItemNames) {
        updatedPickedItems.remove(itemName);
      }

      // Add note to original order
      final splitNote = models.OrderNote(
        text:
            'Order split - Items ${overriddenItemNames.join(", ")} moved to Order #${newOrderId.substring(0, 8)} due to out of stock override',
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedOrder = originalOrder.copyWith(
        items: remainingItems, // Remove overridden items
        pickedItems:
            updatedPickedItems, // Remove overridden items from pickedItems
        notes: [...originalOrder.notes, splitNote],
        updatedAt: now,
      );

      await updateOrder(updatedOrder);

      if (kDebugMode) {
        print(
          'Order split: Order #$orderId -> Order #$newOrderId (${overriddenItemNames.length} items)',
        );
      }

      return newOrderId;
    } catch (e) {
      if (kDebugMode) {
        print('Error splitting order: $e');
      }
      rethrow;
    }
  }

  /// Generate invoice number in format: INV-YYYYMMDD-XXXX
  String _generateInvoiceNumber(String orderId) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final orderSuffix = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
    return 'INV-$dateStr-$orderSuffix';
  }
}

enum PaymentResponseStatus { confirmed, declined, invalid }

class PaymentConfirmationResult {
  final bool success;
  final String message;
  final PaymentResponseStatus status;

  const PaymentConfirmationResult({
    required this.success,
    required this.message,
    required this.status,
  });
}

/// Result status for installation booking
enum InstallationBookingStatus { success, invalid, alreadySelected }

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
