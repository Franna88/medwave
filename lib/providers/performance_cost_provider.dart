import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/performance/product.dart';
import '../models/performance/ad_performance_cost.dart';
import '../services/performance_cost_service.dart';
import 'gohighlevel_provider.dart';

/// Provider for managing performance cost data and state
class PerformanceCostProvider extends ChangeNotifier {
  // Data
  List<Product> _products = [];
  List<AdPerformanceCost> _adCosts = [];
  List<AdPerformanceCostWithMetrics> _mergedData = [];
  
  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  
  // Getters
  List<Product> get products => _products;
  List<AdPerformanceCost> get adCosts => _adCosts;
  List<AdPerformanceCostWithMetrics> get mergedData => _mergedData;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      print('🔄 Performance Cost Provider: Initializing...');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await loadProducts();
      await loadAdCosts();
      
      _isInitialized = true;
      _isLoading = false;
      
      if (kDebugMode) {
        print('✅ Performance Cost Provider: Initialized successfully');
        print('   - Products: ${_products.length}');
        print('   - Ad Costs: ${_adCosts.length}');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      
      if (kDebugMode) {
        print('❌ Performance Cost Provider ERROR: Initialization failed: $e');
      }
    }
    
    notifyListeners();
  }

  /// Load all products
  Future<void> loadProducts() async {
    try {
      if (kDebugMode) {
        print('🔄 Loading products...');
      }
      
      _products = await PerformanceCostService.getProducts();
      
      if (kDebugMode) {
        print('✅ Loaded ${_products.length} products');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading products: $e');
      }
      _error = 'Failed to load products: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Load all ad performance costs
  Future<void> loadAdCosts() async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ad performance costs...');
      }
      
      _adCosts = await PerformanceCostService.getAdPerformanceCosts();
      
      if (kDebugMode) {
        print('✅ Loaded ${_adCosts.length} ad performance costs');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading ad costs: $e');
      }
      _error = 'Failed to load ad costs: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await loadProducts();
      await loadAdCosts();
      
      _isLoading = false;
      
      if (kDebugMode) {
        print('✅ Performance data refreshed');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      
      if (kDebugMode) {
        print('❌ Error refreshing data: $e');
      }
    }
    
    notifyListeners();
  }

  /// Merge ad costs with cumulative campaign data
  Future<void> mergeWithCumulativeData(GoHighLevelProvider ghlProvider) async {
    try {
      if (kDebugMode) {
        print('🔄 Merging ad costs with cumulative data...');
      }

      _mergedData = await PerformanceCostService.getMergedPerformanceData(
        adCosts: _adCosts,
        cumulativeCampaigns: ghlProvider.pipelineCampaigns,
        products: _products,
      );

      if (kDebugMode) {
        print('✅ Merged ${_mergedData.length} ad performance entries');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error merging data: $e');
      }
      _error = 'Failed to merge data: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Get merged data (synchronous, returns cached data)
  List<AdPerformanceCostWithMetrics> getMergedData(GoHighLevelProvider ghlProvider) {
    // Trigger async merge in background if needed
    if (_mergedData.isEmpty && _adCosts.isNotEmpty) {
      mergeWithCumulativeData(ghlProvider);
    }
    return _mergedData;
  }

  // ========== PRODUCT CRUD OPERATIONS ==========

  /// Create a new product
  Future<Product> createProduct({
    required String name,
    required double depositAmount,
    required double expenseCost,
    String? createdBy,
  }) async {
    try {
      if (kDebugMode) {
        print('📝 Creating product: $name');
      }

      final product = Product(
        id: '', // Will be set by Firestore
        name: name,
        depositAmount: depositAmount,
        expenseCost: expenseCost,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      );

      final createdProduct = await PerformanceCostService.createProduct(product);
      _products.add(createdProduct);
      _products.sort((a, b) => a.name.compareTo(b.name));
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Product created: ${createdProduct.id}');
      }
      
      return createdProduct;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating product: $e');
      }
      _error = 'Failed to create product: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    try {
      if (kDebugMode) {
        print('📝 Updating product: ${product.id}');
      }

      await PerformanceCostService.updateProduct(product);
      
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        _products.sort((a, b) => a.name.compareTo(b.name));
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Product updated: ${product.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating product: $e');
      }
      _error = 'Failed to update product: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting product: $productId');
      }

      await PerformanceCostService.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Product deleted: $productId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting product: $e');
      }
      _error = 'Failed to delete product: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // ========== AD PERFORMANCE COST CRUD OPERATIONS ==========

  /// Create a new ad performance cost
  Future<AdPerformanceCost> createAdPerformanceCost({
    required String campaignName,
    required String campaignKey,
    required String adId,
    required String adName,
    required double budget,
    String? linkedProductId,
    String? createdBy,
  }) async {
    try {
      if (kDebugMode) {
        print('📝 Creating ad performance cost: $adName');
      }

      final cost = AdPerformanceCost(
        id: '', // Will be set by Firestore
        campaignName: campaignName,
        campaignKey: campaignKey,
        adId: adId,
        adName: adName,
        budget: budget,
        linkedProductId: linkedProductId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      );

      final createdCost = await PerformanceCostService.createAdPerformanceCost(cost);
      _adCosts.add(createdCost);
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Ad performance cost created: ${createdCost.id}');
      }
      
      return createdCost;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating ad performance cost: $e');
      }
      _error = 'Failed to create ad cost: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing ad performance cost
  Future<void> updateAdPerformanceCost(AdPerformanceCost cost) async {
    try {
      if (kDebugMode) {
        print('📝 Updating ad performance cost: ${cost.id}');
      }

      await PerformanceCostService.updateAdPerformanceCost(cost);
      
      final index = _adCosts.indexWhere((c) => c.id == cost.id);
      if (index != -1) {
        _adCosts[index] = cost;
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Ad performance cost updated: ${cost.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating ad performance cost: $e');
      }
      _error = 'Failed to update ad cost: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete an ad performance cost
  Future<void> deleteAdPerformanceCost(String costId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting ad performance cost: $costId');
      }

      await PerformanceCostService.deleteAdPerformanceCost(costId);
      _adCosts.removeWhere((c) => c.id == costId);
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Ad performance cost deleted: $costId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting ad performance cost: $e');
      }
      _error = 'Failed to delete ad cost: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get product by ID
  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }
}

