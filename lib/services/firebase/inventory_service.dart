import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/inventory/inventory_stock.dart';
import '../../models/admin/product_item.dart';

/// Firestore service for inventory stock management
class InventoryService {
  final CollectionReference<Map<String, dynamic>> _stockCollection =
      FirebaseFirestore.instance.collection('inventory_stock');

  final CollectionReference<Map<String, dynamic>> _stockTakeCollection =
      FirebaseFirestore.instance.collection('stock_take_records');

  final CollectionReference<Map<String, dynamic>> _productCollection =
      FirebaseFirestore.instance.collection('product_items');

  /// Watch all inventory stock items
  Stream<List<InventoryStock>> watchInventoryStock() {
    return _stockCollection
        .orderBy('productName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(InventoryStock.fromFirestore)
              .toList(growable: false),
        );
  }

  /// Watch inventory stock items with low stock (below min level)
  Stream<List<InventoryStock>> watchLowStockItems() {
    return _stockCollection.snapshots().map((snapshot) => snapshot.docs
        .map(InventoryStock.fromFirestore)
        .where((stock) => stock.isLowStock)
        .toList(growable: false));
  }

  /// Get a single inventory stock item by ID
  Future<InventoryStock?> getInventoryStock(String id) async {
    final doc = await _stockCollection.doc(id).get();
    if (doc.exists) {
      return InventoryStock.fromFirestore(doc);
    }
    return null;
  }

  /// Get inventory stock by product ID
  Future<InventoryStock?> getStockByProductId(String productId) async {
    final query = await _stockCollection
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return InventoryStock.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Create a new inventory stock record
  Future<String> createInventoryStock(InventoryStock stock) async {
    final now = FieldValue.serverTimestamp();
    final data = stock.toMap();
    data['createdAt'] = now;
    data['updatedAt'] = now;
    
    final doc = await _stockCollection.add(data);
    return doc.id;
  }

  /// Update stock quantity (stock take)
  Future<void> updateStockQuantity({
    required String stockId,
    required int newQty,
    required String updatedBy,
    String? notes,
  }) async {
    // Get current stock to record the change
    final currentStock = await getInventoryStock(stockId);
    if (currentStock == null) {
      throw Exception('Stock record not found');
    }

    final previousQty = currentStock.currentQty;
    final difference = newQty - previousQty;

    // Update the stock record
    await _stockCollection.doc(stockId).update({
      'currentQty': newQty,
      'lastStockTakeDate': FieldValue.serverTimestamp(),
      'lastUpdatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create a stock take record for history
    await _stockTakeCollection.add({
      'inventoryStockId': stockId,
      'productId': currentStock.productId,
      'previousQty': previousQty,
      'newQty': newQty,
      'difference': difference,
      'notes': notes,
      'updatedBy': updatedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      debugPrint(
        'Stock updated: ${currentStock.productName} from $previousQty to $newQty (diff: $difference)',
      );
    }
  }

  /// Update inventory stock details (location, min level, etc.)
  Future<void> updateInventoryStock(InventoryStock stock) async {
    await _stockCollection.doc(stock.id).update({
      'warehouseLocation': stock.warehouseLocation,
      'shelfLocation': stock.shelfLocation,
      'minStockLevel': stock.minStockLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete an inventory stock record
  Future<void> deleteInventoryStock(String id) async {
    await _stockCollection.doc(id).delete();
  }

  /// Get stock take history for a specific product
  Stream<List<StockTakeRecord>> watchStockTakeHistory(String inventoryStockId) {
    return _stockTakeCollection
        .where('inventoryStockId', isEqualTo: inventoryStockId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(StockTakeRecord.fromFirestore)
              .toList(growable: false),
        );
  }

  /// Initialize stock records for products that don't have them
  /// Also cleans up duplicates and orphaned records
  Future<void> initializeStockForProducts() async {
    try {
      // Get all active products
      final productsSnapshot = await _productCollection.get();
      final products = productsSnapshot.docs
          .map(ProductItem.fromFirestore)
          .toList();
      
      // Create a set of valid product IDs
      final validProductIds = products.map((p) => p.id).toSet();

      // Get all existing stock records
      final stockSnapshot = await _stockCollection.get();
      
      // Track which product IDs already have stock records
      final Map<String, String> productIdToStockId = {};
      final List<String> duplicatesToDelete = [];
      final List<String> orphansToDelete = [];

      for (final doc in stockSnapshot.docs) {
        final productId = doc.data()['productId'] as String?;
        
        if (productId == null || !validProductIds.contains(productId)) {
          // Orphaned stock record (product no longer exists)
          orphansToDelete.add(doc.id);
        } else if (productIdToStockId.containsKey(productId)) {
          // Duplicate stock record
          duplicatesToDelete.add(doc.id);
        } else {
          // First stock record for this product
          productIdToStockId[productId] = doc.id;
        }
      }

      // Delete orphaned records
      for (final orphanId in orphansToDelete) {
        await _stockCollection.doc(orphanId).delete();
        if (kDebugMode) {
          debugPrint('Deleted orphaned stock record: $orphanId');
        }
      }

      // Delete duplicate records
      for (final duplicateId in duplicatesToDelete) {
        await _stockCollection.doc(duplicateId).delete();
        if (kDebugMode) {
          debugPrint('Deleted duplicate stock record: $duplicateId');
        }
      }

      // Create stock records for products that don't have one
      for (final product in products) {
        if (!productIdToStockId.containsKey(product.id)) {
          final stock = InventoryStock.initial(
            productId: product.id,
            productName: product.name,
          );
          await createInventoryStock(stock);
          if (kDebugMode) {
            debugPrint('Created stock record for product: ${product.name}');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('Inventory sync complete: ${orphansToDelete.length} orphans removed, '
            '${duplicatesToDelete.length} duplicates removed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing stock for products: $e');
      }
    }
  }

  /// Get inventory statistics
  Future<Map<String, int>> getInventoryStats() async {
    final snapshot = await _stockCollection.get();
    final stocks = snapshot.docs
        .map(InventoryStock.fromFirestore)
        .toList();

    int totalProducts = stocks.length;
    int lowStockCount = stocks.where((s) => s.isLowStock && !s.isOutOfStock).length;
    int outOfStockCount = stocks.where((s) => s.isOutOfStock).length;
    int inStockCount = stocks.where((s) => !s.isLowStock && !s.isOutOfStock).length;

    return {
      'total': totalProducts,
      'inStock': inStockCount,
      'lowStock': lowStockCount,
      'outOfStock': outOfStockCount,
    };
  }

  /// Deduct stock for multiple items (used when order items are picked)
  /// Returns a map of item names to success status
  Future<Map<String, bool>> deductStockForOrderItems({
    required List<Map<String, dynamic>> items, // [{name, quantity}]
    required String orderId,
    required String updatedBy,
  }) async {
    final results = <String, bool>{};

    for (final item in items) {
      final itemName = item['name'] as String;
      final quantity = item['quantity'] as int;

      try {
        // Find stock by product name
        final stockQuery = await _stockCollection
            .where('productName', isEqualTo: itemName)
            .limit(1)
            .get();

        if (stockQuery.docs.isEmpty) {
          if (kDebugMode) {
            debugPrint('No stock record found for product: $itemName');
          }
          results[itemName] = false;
          continue;
        }

        final stockDoc = stockQuery.docs.first;
        final stock = InventoryStock.fromFirestore(stockDoc);
        final newQty = stock.currentQty - quantity;

        // Update stock (allow negative for tracking purposes)
        await updateStockQuantity(
          stockId: stock.id,
          newQty: newQty < 0 ? 0 : newQty,
          updatedBy: updatedBy,
          notes: 'Deducted $quantity for order $orderId',
        );

        results[itemName] = true;

        if (kDebugMode) {
          debugPrint('Deducted $quantity of $itemName for order $orderId');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error deducting stock for $itemName: $e');
        }
        results[itemName] = false;
      }
    }

    return results;
  }

  /// Get stock by product name
  Future<InventoryStock?> getStockByProductName(String productName) async {
    final query = await _stockCollection
        .where('productName', isEqualTo: productName)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return InventoryStock.fromFirestore(query.docs.first);
    }
    return null;
  }
}

