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
  Future<void> initializeStockForProducts() async {
    try {
      // Get all products
      final productsSnapshot = await _productCollection.get();
      final products = productsSnapshot.docs
          .map(ProductItem.fromFirestore)
          .toList();

      // Get all existing stock records
      final stockSnapshot = await _stockCollection.get();
      final existingProductIds = stockSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .whereType<String>()
          .toSet();

      // Create stock records for products without one
      for (final product in products) {
        if (!existingProductIds.contains(product.id)) {
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
}

