import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for inventory stock tracking
/// Each record represents the stock status of a product item
class InventoryStock {
  final String id;
  final String productId;
  final String productName;
  final int currentQty;
  final String warehouseLocation;
  final String shelfLocation;
  final int minStockLevel;
  final DateTime? lastStockTakeDate;
  final String? lastUpdatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryStock({
    required this.id,
    required this.productId,
    required this.productName,
    required this.currentQty,
    required this.warehouseLocation,
    required this.shelfLocation,
    required this.minStockLevel,
    this.lastStockTakeDate,
    this.lastUpdatedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if stock is below minimum level
  bool get isLowStock => currentQty < minStockLevel;

  /// Check if stock is out
  bool get isOutOfStock => currentQty <= 0;

  /// Get stock status for display
  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  InventoryStock copyWith({
    String? id,
    String? productId,
    String? productName,
    int? currentQty,
    String? warehouseLocation,
    String? shelfLocation,
    int? minStockLevel,
    DateTime? lastStockTakeDate,
    String? lastUpdatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryStock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentQty: currentQty ?? this.currentQty,
      warehouseLocation: warehouseLocation ?? this.warehouseLocation,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      lastStockTakeDate: lastStockTakeDate ?? this.lastStockTakeDate,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InventoryStock.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InventoryStock(
      id: doc.id,
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? '').toString(),
      currentQty: (data['currentQty'] is num) ? (data['currentQty'] as num).toInt() : 0,
      warehouseLocation: (data['warehouseLocation'] ?? '').toString(),
      shelfLocation: (data['shelfLocation'] ?? '').toString(),
      minStockLevel: (data['minStockLevel'] is num) ? (data['minStockLevel'] as num).toInt() : 0,
      lastStockTakeDate: (data['lastStockTakeDate'] as Timestamp?)?.toDate(),
      lastUpdatedBy: data['lastUpdatedBy']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'currentQty': currentQty,
      'warehouseLocation': warehouseLocation,
      'shelfLocation': shelfLocation,
      'minStockLevel': minStockLevel,
      'lastStockTakeDate': lastStockTakeDate != null 
          ? Timestamp.fromDate(lastStockTakeDate!) 
          : null,
      'lastUpdatedBy': lastUpdatedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create an initial stock record for a new product
  factory InventoryStock.initial({
    required String productId,
    required String productName,
    String warehouseLocation = 'Main Warehouse',
    String shelfLocation = '',
    int minStockLevel = 10,
  }) {
    return InventoryStock(
      id: '',
      productId: productId,
      productName: productName,
      currentQty: 0,
      warehouseLocation: warehouseLocation,
      shelfLocation: shelfLocation,
      minStockLevel: minStockLevel,
      createdAt: DateTime.now(),
    );
  }
}

/// Model for recording stock take history
class StockTakeRecord {
  final String id;
  final String inventoryStockId;
  final String productId;
  final int previousQty;
  final int newQty;
  final int difference;
  final String? notes;
  final String updatedBy;
  final DateTime timestamp;

  const StockTakeRecord({
    required this.id,
    required this.inventoryStockId,
    required this.productId,
    required this.previousQty,
    required this.newQty,
    required this.difference,
    this.notes,
    required this.updatedBy,
    required this.timestamp,
  });

  factory StockTakeRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return StockTakeRecord(
      id: doc.id,
      inventoryStockId: (data['inventoryStockId'] ?? '').toString(),
      productId: (data['productId'] ?? '').toString(),
      previousQty: (data['previousQty'] is num) ? (data['previousQty'] as num).toInt() : 0,
      newQty: (data['newQty'] is num) ? (data['newQty'] as num).toInt() : 0,
      difference: (data['difference'] is num) ? (data['difference'] as num).toInt() : 0,
      notes: data['notes']?.toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inventoryStockId': inventoryStockId,
      'productId': productId,
      'previousQty': previousQty,
      'newQty': newQty,
      'difference': difference,
      'notes': notes,
      'updatedBy': updatedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

