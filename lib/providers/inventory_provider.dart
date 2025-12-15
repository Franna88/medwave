import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/inventory/inventory_stock.dart';
import '../services/firebase/inventory_service.dart';

/// Provider to manage inventory stock state for warehouse operations
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service = InventoryService();
  StreamSubscription<List<InventoryStock>>? _stockSubscription;
  StreamSubscription<List<InventoryStock>>? _lowStockSubscription;

  List<InventoryStock> _stockItems = [];
  List<InventoryStock> _lowStockItems = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, in_stock, low_stock, out_of_stock

  // Getters
  List<InventoryStock> get stockItems => _filteredItems;
  List<InventoryStock> get allStockItems => _stockItems;
  List<InventoryStock> get lowStockItems => _lowStockItems;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get filterStatus => _filterStatus;

  /// Get filtered items based on search and filter
  List<InventoryStock> get _filteredItems {
    var items = _stockItems;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items
          .where((item) =>
              item.productName.toLowerCase().contains(query) ||
              item.warehouseLocation.toLowerCase().contains(query) ||
              item.shelfLocation.toLowerCase().contains(query))
          .toList();
    }

    // Apply status filter
    switch (_filterStatus) {
      case 'in_stock':
        items = items.where((item) => !item.isLowStock && !item.isOutOfStock).toList();
        break;
      case 'low_stock':
        items = items.where((item) => item.isLowStock && !item.isOutOfStock).toList();
        break;
      case 'out_of_stock':
        items = items.where((item) => item.isOutOfStock).toList();
        break;
    }

    return items;
  }

  /// Start listening to inventory stock
  Future<void> listenToInventory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _stockSubscription?.cancel();
    _stockSubscription = _service.watchInventoryStock().listen(
      (items) {
        _stockItems = items;
        _isLoading = false;
        _error = null;
        _updateStats();
        if (kDebugMode) {
          debugPrint('InventoryProvider: loaded ${items.length} stock items');
        }
        notifyListeners();
      },
      onError: (e, stack) {
        _isLoading = false;
        _error = 'Failed to load inventory: $e';
        if (kDebugMode) {
          debugPrint('InventoryProvider error: $e');
          debugPrintStack(stackTrace: stack);
        }
        notifyListeners();
      },
    );

    // Also listen to low stock items
    await _lowStockSubscription?.cancel();
    _lowStockSubscription = _service.watchLowStockItems().listen(
      (items) {
        _lowStockItems = items;
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('Low stock subscription error: $e');
        }
      },
    );
  }

  /// Update local stats from current items
  void _updateStats() {
    int totalProducts = _stockItems.length;
    int lowStockCount = _stockItems.where((s) => s.isLowStock && !s.isOutOfStock).length;
    int outOfStockCount = _stockItems.where((s) => s.isOutOfStock).length;
    int inStockCount = _stockItems.where((s) => !s.isLowStock && !s.isOutOfStock).length;

    _stats = {
      'total': totalProducts,
      'inStock': inStockCount,
      'lowStock': lowStockCount,
      'outOfStock': outOfStockCount,
    };
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update filter status
  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  /// Clear filters
  void clearFilters() {
    _searchQuery = '';
    _filterStatus = 'all';
    notifyListeners();
  }

  /// Update stock quantity (stock take)
  Future<void> updateStockQuantity({
    required String stockId,
    required int newQty,
    required String updatedBy,
    String? notes,
  }) async {
    try {
      await _service.updateStockQuantity(
        stockId: stockId,
        newQty: newQty,
        updatedBy: updatedBy,
        notes: notes,
      );
    } catch (e) {
      _error = 'Failed to update stock: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update inventory stock details
  Future<void> updateInventoryStock(InventoryStock stock) async {
    try {
      await _service.updateInventoryStock(stock);
    } catch (e) {
      _error = 'Failed to update inventory: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Create a new inventory stock record
  Future<String> createInventoryStock(InventoryStock stock) async {
    try {
      return await _service.createInventoryStock(stock);
    } catch (e) {
      _error = 'Failed to create inventory: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Initialize stock for all products
  Future<void> initializeStockForProducts() async {
    try {
      await _service.initializeStockForProducts();
    } catch (e) {
      _error = 'Failed to initialize stock: $e';
      notifyListeners();
    }
  }

  /// Get stock by product ID
  Future<InventoryStock?> getStockByProductId(String productId) async {
    return await _service.getStockByProductId(productId);
  }

  /// Refresh inventory data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _stats = await _service.getInventoryStats();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error refreshing stats: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    _lowStockSubscription?.cancel();
    super.dispose();
  }
}

