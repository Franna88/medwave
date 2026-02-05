import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../models/admin/product_package.dart';
import '../../models/installation/installation_signoff.dart';
import '../../models/streams/order.dart' as models;
import 'order_service.dart';

/// Service for managing installation sign-offs in Firebase
class InstallationSignoffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionPath = 'installation_signoffs';
  static const String _secretKey =
      'medwave_signoff_secret_2024'; // In production, use env variable

  /// Generate a secure HMAC-SHA256 access token
  String generateAccessToken(String signoffId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$signoffId:$timestamp';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(data));
    return '${digest.toString()}:$timestamp';
  }

  /// Validate an access token
  bool validateToken(String signoffId, String token) {
    try {
      final parts = token.split(':');
      if (parts.length != 2) return false;

      final expectedHash = parts[0];
      final timestamp = parts[1];
      final data = '$signoffId:$timestamp';

      final hmac = Hmac(sha256, utf8.encode(_secretKey));
      final digest = hmac.convert(utf8.encode(data));

      return digest.toString() == expectedHash;
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error validating token: $e');
      }
      return false;
    }
  }

  /// Create a sign-off from an order
  Future<InstallationSignoff> createSignoff({
    required models.Order order,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      // Extract delivery address from opt-in questions if available
      final deliveryAddress = order.optInQuestions?['Shipping address'];

      // Create sign-off document reference
      final docRef = _firestore.collection(_collectionPath).doc();

      // Generate access token
      final accessToken = generateAccessToken(docRef.id);

      // Convert order items to signoff items; expand packages to product-level and add includedServiceLabels
      final signoffItems = <SignoffItem>[];
      for (final item in order.items) {
        if (item.packageId == null) {
          signoffItems.add(
            SignoffItem(name: item.name, quantity: item.quantity),
          );
          continue;
        }
        try {
          final packageDoc = await _firestore
              .collection('product_packages')
              .doc(item.packageId)
              .get();
          if (!packageDoc.exists || packageDoc.data() == null) {
            signoffItems.add(
              SignoffItem(name: item.name, quantity: item.quantity),
            );
            continue;
          }
          final package = ProductPackage.fromFirestore(packageDoc);
          if (package.packageItems.isEmpty) {
            signoffItems.add(
              SignoffItem(name: item.name, quantity: item.quantity),
            );
            continue;
          }
          for (final entry in package.packageItems) {
            String productName = 'Product ${entry.productId}';
            try {
              final productDoc = await _firestore
                  .collection('product_items')
                  .doc(entry.productId)
                  .get();
              if (productDoc.exists && productDoc.data() != null) {
                productName =
                    (productDoc.data()!['name'] as String?) ?? productName;
              }
            } catch (_) {}
            signoffItems.add(
              SignoffItem(
                name: productName,
                quantity: entry.quantity * item.quantity,
              ),
            );
          }
          if (package.includedServiceLabels != null) {
            for (final label in package.includedServiceLabels!) {
              if (label.isNotEmpty) {
                signoffItems.add(SignoffItem(name: label, quantity: 1));
              }
            }
          }
        } catch (_) {
          signoffItems.add(
            SignoffItem(name: item.name, quantity: item.quantity),
          );
        }
      }

      // Create sign-off object
      final signoff = InstallationSignoff(
        id: docRef.id,
        accessToken: accessToken,
        status: SignoffStatus.pending,
        orderId: order.id,
        appointmentId: order.appointmentId,
        customerName: order.customerName,
        email: order.email,
        phone: order.phone,
        deliveryAddress: deliveryAddress,
        items: signoffItems,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
      );

      // Save to Firestore
      await docRef.set(signoff.toMap());

      if (kDebugMode) {
        print('✅ InstallationSignoffService: Sign-off created: ${signoff.id}');
      }

      return signoff;
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error creating sign-off: $e');
      }
      rethrow;
    }
  }

  /// Get sign-off by ID and validate token
  Future<InstallationSignoff?> getSignoffByIdAndToken(
    String signoffId,
    String? token,
  ) async {
    try {
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('❌ InstallationSignoffService: Token is required');
        }
        return null;
      }

      // Validate token
      if (!validateToken(signoffId, token)) {
        if (kDebugMode) {
          print(
            '❌ InstallationSignoffService: Invalid token for sign-off $signoffId',
          );
        }
        return null;
      }

      final doc = await _firestore
          .collection(_collectionPath)
          .doc(signoffId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('❌ InstallationSignoffService: Sign-off not found: $signoffId');
        }
        return null;
      }

      return InstallationSignoff.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error getting sign-off: $e');
      }
      return null;
    }
  }

  /// Mark sign-off as viewed (first time opened)
  Future<void> markAsViewed(String signoffId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(signoffId)
          .get();

      if (doc.exists) {
        final signoff = InstallationSignoff.fromFirestore(doc);
        // Only mark as viewed if it's still pending
        if (signoff.status == SignoffStatus.pending &&
            signoff.viewedAt == null) {
          await _firestore.collection(_collectionPath).doc(signoffId).update({
            'status': SignoffStatus.viewed.name,
            'viewedAt': Timestamp.fromDate(DateTime.now()),
          });

          if (kDebugMode) {
            print(
              '✅ InstallationSignoffService: Sign-off marked as viewed: $signoffId',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ InstallationSignoffService: Error marking sign-off as viewed: $e',
        );
      }
    }
  }

  /// Sign a sign-off
  Future<void> signSignoff({
    required String signoffId,
    required String digitalSignature,
    required Map<String, bool> itemsConfirmed,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Generate unique digital signature token
      const uuid = Uuid();
      final digitalSignatureToken = 'DST-${uuid.v4()}';

      // Improve IP address placeholder
      final finalIpAddress =
          ipAddress ??
          'IP-capture-pending-${DateTime.now().millisecondsSinceEpoch}';

      // Sign sign-off
      await _firestore.collection(_collectionPath).doc(signoffId).update({
        'status': SignoffStatus.signed.name,
        'hasSigned': true,
        'digitalSignature': digitalSignature,
        'digitalSignatureToken': digitalSignatureToken,
        'signedAt': Timestamp.fromDate(DateTime.now()),
        'ipAddress': finalIpAddress,
        'userAgent': userAgent,
        'itemsConfirmed': itemsConfirmed,
      });

      if (kDebugMode) {
        print('✅ InstallationSignoffService: Sign-off signed: $signoffId');
      }

      // Update the order document with sign-off reference
      try {
        final signoffDoc = await _firestore
            .collection(_collectionPath)
            .doc(signoffId)
            .get();

        if (signoffDoc.exists) {
          final signoff = InstallationSignoff.fromFirestore(signoffDoc);

          // Update order with sign-off reference
          await _firestore.collection('orders').doc(signoff.orderId).update({
            'installationSignoffId': signoffId,
            'hasInstallationSignoff': true,
            'installationSignedOffAt': Timestamp.fromDate(DateTime.now()),
          });

          if (kDebugMode) {
            print(
              '✅ InstallationSignoffService: Order updated with sign-off reference',
            );
          }

          // Check if both conditions are met (signoff signed AND finance confirmed payment)
          // If so, automatically move order to payment stage
          try {
            final orderDoc = await _firestore
                .collection('orders')
                .doc(signoff.orderId)
                .get();

            if (orderDoc.exists) {
              final order = models.Order.fromFirestore(orderDoc);

              // Check both conditions
              final signoffSigned = order.hasInstallationSignoff == true;
              final financeConfirmed =
                  order.paymentConfirmationStatus == 'confirmed';

              if (signoffSigned &&
                  financeConfirmed &&
                  order.currentStage == 'installed') {
                // Both conditions met - auto-move to payment stage
                final orderService = OrderService();
                await orderService.moveOrderToStage(
                  orderId: order.id,
                  newStage: 'payment',
                  note:
                      'Installation signoff signed and payment confirmed by finance. Automatically moved to payment stage.',
                  userId: 'system',
                  userName: 'System (Auto-move)',
                );

                if (kDebugMode) {
                  print(
                    '✅ Auto-moved order ${order.id} to payment stage (both conditions met)',
                  );
                }
              }
            }
          } catch (autoMoveError) {
            if (kDebugMode) {
              print('❌ Error checking auto-move conditions: $autoMoveError');
            }
            // Don't throw - signoff is still signed successfully
          }
        }
      } catch (orderUpdateError) {
        // Log but don't throw - sign-off is still signed successfully
        if (kDebugMode) {
          print(
            '⚠️ Sign-off signed but order update failed: $orderUpdateError',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error signing sign-off: $e');
      }
      rethrow;
    }
  }

  /// Get sign-offs by order ID
  Future<List<InstallationSignoff>> getSignoffsByOrderId(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('orderId', isEqualTo: orderId)
          .get();

      final signoffs =
          snapshot.docs
              .map((doc) => InstallationSignoff.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return signoffs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error getting sign-offs: $e');
      }
      return [];
    }
  }

  /// Get sign-off by ID (admin access, no token validation)
  Future<InstallationSignoff?> getSignoffById(String signoffId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(signoffId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return InstallationSignoff.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstallationSignoffService: Error getting sign-off by ID: $e');
      }
      return null;
    }
  }

  /// Stream sign-offs by order ID
  Stream<List<InstallationSignoff>> watchSignoffsByOrderId(String orderId) {
    return _firestore
        .collection(_collectionPath)
        .where('orderId', isEqualTo: orderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => InstallationSignoff.fromFirestore(doc))
              .toList();
        });
  }

  /// Generate sign-off link (relative path)
  String generateSignoffLink(InstallationSignoff signoff) {
    return '/installation-signoff/${signoff.id}?token=${signoff.accessToken}';
  }

  /// Get full sign-off URL (for copying)
  String getFullSignoffUrl(InstallationSignoff signoff) {
    if (kIsWeb) {
      // On web, get the current domain dynamically
      final baseUrl = Uri.base.origin;
      return '$baseUrl/installation-signoff/${signoff.id}?token=${signoff.accessToken}';
    }
    // For mobile, use a configurable base URL
    // TODO: Store this in environment config
    return 'https://yourdomain.com/installation-signoff/${signoff.id}?token=${signoff.accessToken}';
  }
}
