import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/performance/product.dart';
import '../models/performance/ad_performance_data.dart';
import '../models/performance/ad_performance_cost.dart';
import '../models/performance/campaign_aggregate.dart';
import '../models/performance/ad_set_aggregate.dart';
import '../services/firebase/ad_performance_service.dart';
import '../services/performance_cost_service.dart';

/// Provider for managing ad performance data (Facebook + GHL from Firebase)
class PerformanceCostProvider extends ChangeNotifier {
  // Data
  List<Product> _products = [];
  List<AdPerformanceData> _adPerformanceData = [];
  List<AdPerformanceWithProduct> _adPerformanceWithProducts = [];
  
  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DateTime? _lastSync;
  bool _isSyncing = false;
  
  // Getters
  List<Product> get products => _products;
  List<AdPerformanceData> get adPerformanceData => _adPerformanceData;
  List<AdPerformanceWithProduct> get adPerformanceWithProducts => _adPerformanceWithProducts;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  
  // Quick stats
  int get totalAds => _adPerformanceData.length;
  int get matchedAds => _adPerformanceData.where((ad) => ad.matchingStatus == MatchingStatus.matched).length;
  int get unmatchedAds => _adPerformanceData.where((ad) => ad.matchingStatus == MatchingStatus.unmatched).length;
  
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
      await loadAdPerformanceData();
      
      _isInitialized = true;
      _isLoading = false;
      
      if (kDebugMode) {
        print('✅ Performance Cost Provider: Initialized successfully');
        print('   - Products: ${_products.length}');
        print('   - Ads: ${_adPerformanceData.length} (Matched: $matchedAds, Unmatched: $unmatchedAds)');
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

  /// Load all ad performance data from Firebase
  Future<void> loadAdPerformanceData() async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ad performance data from Firebase...');
      }
      
      _adPerformanceData = await AdPerformanceService.getAllAdPerformance();
      
      // Combine with products
      _adPerformanceWithProducts = _adPerformanceData.map((ad) {
        Product? product;
        if (ad.adminConfig?.linkedProductId != null) {
          product = _products.firstWhere(
            (p) => p.id == ad.adminConfig!.linkedProductId,
            orElse: () => Product(
              id: '',
              name: 'Unknown',
              depositAmount: 0,
              expenseCost: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
        
        return AdPerformanceWithProduct(
          data: ad,
          product: product,
        );
      }).toList();
      
      _lastSync = DateTime.now();
      
      if (kDebugMode) {
        print('✅ Loaded ${_adPerformanceData.length} ad performance records');
        print('   - Matched (FB + GHL): $matchedAds');
        print('   - Unmatched (FB only): $unmatchedAds');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading ad performance data: $e');
      }
      _error = 'Failed to load ad performance data: ${e.toString()}';
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
      await loadAdPerformanceData();
      
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

  // ========== SYNC OPERATIONS ==========

  /// Trigger Facebook data sync
  Future<void> syncFacebookData() async {
    if (_isSyncing) {
      if (kDebugMode) {
        print('⏳ Sync already in progress, skipping...');
      }
      return;
    }
    
    _isSyncing = true;
    _error = null;
    notifyListeners();
    
    try {
      if (kDebugMode) {
        print('🔄 Triggering Facebook sync...');
      }
      
      final result = await AdPerformanceService.triggerFacebookSync();
      
      if (kDebugMode) {
        print('✅ Facebook sync completed: ${result['message']}');
      }
      
      // Reload data after sync
      await loadAdPerformanceData();
      
      _isSyncing = false;
    } catch (e) {
      _error = 'Failed to sync Facebook data: ${e.toString()}';
      _isSyncing = false;
      
      if (kDebugMode) {
        print('❌ Error syncing Facebook data: $e');
      }
    }
    
    notifyListeners();
  }

  /// Trigger GHL data sync
  Future<void> syncGHLData() async {
    if (_isSyncing) {
      if (kDebugMode) {
        print('⏳ Sync already in progress, skipping...');
      }
      return;
    }
    
    _isSyncing = true;
    _error = null;
    notifyListeners();
    
    try {
      if (kDebugMode) {
        print('🔄 Triggering GHL sync...');
      }
      
      final result = await AdPerformanceService.triggerGHLSync();
      
      if (kDebugMode) {
        print('✅ GHL sync completed: ${result['message']}');
      }
      
      // Reload data after sync
      await loadAdPerformanceData();
      
      _isSyncing = false;
    } catch (e) {
      _error = 'Failed to sync GHL data: ${e.toString()}';
      _isSyncing = false;
      
      if (kDebugMode) {
        print('❌ Error syncing GHL data: $e');
      }
    }
    
    notifyListeners();
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

  // ========== AD PERFORMANCE OPERATIONS ==========

  /// Update budget for an ad
  Future<void> updateAdBudget(String adId, double budget) async {
    try {
      if (kDebugMode) {
        print('📝 Updating budget for ad: $adId to R$budget');
      }

      await AdPerformanceService.updateBudget(adId, budget);
      
      // Update local data
      final index = _adPerformanceData.indexWhere((ad) => ad.adId == adId);
      if (index != -1) {
        final ad = _adPerformanceData[index];
        final updatedConfig = ad.adminConfig?.copyWith(
          budget: budget,
          updatedAt: DateTime.now(),
        ) ?? AdminConfig(
          budget: budget,
          createdBy: 'system',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        _adPerformanceData[index] = ad.copyWith(
          adminConfig: updatedConfig,
          lastUpdated: DateTime.now(),
        );
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Budget updated for ad: $adId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating budget: $e');
      }
      _error = 'Failed to update budget: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Update linked product for an ad
  Future<void> updateAdLinkedProduct(String adId, String? productId) async {
    try {
      if (kDebugMode) {
        print('📝 Updating linked product for ad: $adId to $productId');
      }

      await AdPerformanceService.updateLinkedProduct(adId, productId);
      
      // Update local data
      final index = _adPerformanceData.indexWhere((ad) => ad.adId == adId);
      if (index != -1) {
        final ad = _adPerformanceData[index];
        final updatedConfig = ad.adminConfig?.copyWith(
          linkedProductId: productId,
          updatedAt: DateTime.now(),
        ) ?? AdminConfig(
          budget: 0,
          linkedProductId: productId,
          createdBy: 'system',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        _adPerformanceData[index] = ad.copyWith(
          adminConfig: updatedConfig,
          lastUpdated: DateTime.now(),
        );
      }
      
      // Rebuild with products list
      await loadAdPerformanceData();
      
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Linked product updated for ad: $adId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating linked product: $e');
      }
      _error = 'Failed to update linked product: ${e.toString()}';
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

  // ========== BACKWARD COMPATIBILITY METHODS ==========
  // These methods provide compatibility with old UI code
  
  /// Get merged data (compatibility method)
  List<AdPerformanceWithProduct> getMergedData(dynamic ghlProvider) {
    return _adPerformanceWithProducts;
  }

  /// Merge with cumulative data (compatibility method - now handled by Cloud Functions)
  Future<void> mergeWithCumulativeData(dynamic ghlProvider) async {
    // Data is already merged in Firebase by Cloud Functions
    // Just refresh to get latest
    await refreshData();
  }

  /// Refresh Facebook data (compatibility method)
  Future<void> refreshFacebookData() async {
    await syncFacebookData();
  }

  /// Check if has Facebook data (compatibility getter)
  bool get hasFacebookData => _adPerformanceData.isNotEmpty;

  /// Last Facebook sync time (compatibility getter)
  DateTime? get lastFacebookSync => _lastSync;

  /// Is Facebook data loading (compatibility getter)
  bool get isFacebookDataLoading => _isSyncing;

  /// Get Facebook campaigns (compatibility getter)
  List<FacebookCampaignSummary> get facebookCampaigns {
    // Group ads by campaign
    final campaigns = <String, FacebookCampaignSummary>{};
    
    for (final ad in _adPerformanceData) {
      if (!campaigns.containsKey(ad.campaignId)) {
        // Calculate total spend for this campaign
        double campaignSpend = _adPerformanceData
            .where((a) => a.campaignId == ad.campaignId)
            .fold(0.0, (sum, a) => sum + a.facebookStats.spend);
        
        campaigns[ad.campaignId] = FacebookCampaignSummary(
          id: ad.campaignId,
          name: ad.campaignName,
          spend: campaignSpend,
        );
      }
    }
    
    return campaigns.values.toList();
  }

  /// Get ad costs (compatibility getter) - returns empty list
  List<dynamic> get adCosts => [];

  /// Create ad performance cost (compatibility method - not used in new system)
  Future<void> createAdPerformanceCost({
    required String campaignName,
    required String campaignKey,
    required String adId,
    required String adName,
    required double budget,
    String? linkedProductId,
    String? facebookCampaignId,
  }) async {
    // In the new system, ads come from Facebook API
    // This method is not used but kept for compatibility
    throw UnimplementedError('Use syncFacebookData() to add ads from Facebook API');
  }

  /// Update ad performance cost (compatibility method)
  Future<void> updateAdPerformanceCost(
    AdPerformanceCost cost, {
    double? budget,
    String? linkedProductId,
  }) async {
    // Update budget if provided
    if (budget != null) {
      await updateAdBudget(cost.id, budget);
    }
    
    // Update linked product if provided
    if (linkedProductId != null) {
      await updateAdLinkedProduct(cost.id, linkedProductId);
    }
  }

  /// Delete ad performance cost (compatibility method - not used in new system)
  Future<void> deleteAdPerformanceCost(String id) async {
    // In the new system, ads come from Facebook and shouldn't be manually deleted
    // This method is not used but kept for compatibility
    throw UnimplementedError('Ads are synced from Facebook API and should not be manually deleted');
  }

  // ========== AGGREGATION METHODS ==========

  /// Get campaign-level aggregates from ad performance data
  List<CampaignAggregate> getCampaignAggregates(List<AdPerformanceWithProduct> ads) {
    final Map<String, List<AdPerformanceWithProduct>> campaignGroups = {};
    
    // Group ads by campaign
    for (final ad in ads) {
      if (!campaignGroups.containsKey(ad.campaignId)) {
        campaignGroups[ad.campaignId] = [];
      }
      campaignGroups[ad.campaignId]!.add(ad);
    }
    
    // Create aggregates for each campaign
    final aggregates = <CampaignAggregate>[];
    for (final entry in campaignGroups.entries) {
      final campaignId = entry.key;
      final campaignAds = entry.value;
      
      if (campaignAds.isEmpty) continue;
      
      // Count unique ad sets
      final uniqueAdSets = campaignAds
          .where((ad) => ad.adSetId != null && ad.adSetId!.isNotEmpty)
          .map((ad) => ad.adSetId)
          .toSet()
          .length;
      
      // Aggregate metrics
      double totalFbSpend = 0;
      int totalImpressions = 0;
      int totalReach = 0;
      int totalClicks = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      double totalBudget = 0;
      DateTime? latestUpdate;
      
      for (final ad in campaignAds) {
        totalFbSpend += ad.facebookStats.spend;
        totalImpressions += ad.facebookStats.impressions;
        totalReach += ad.facebookStats.reach;
        totalClicks += ad.facebookStats.clicks;
        
        if (ad.ghlStats != null) {
          totalLeads += ad.ghlStats!.leads;
          totalBookings += ad.ghlStats!.bookings;
          totalDeposits += ad.ghlStats!.deposits;
          totalCashCollected += ad.ghlStats!.cashCollected;
          totalCashAmount += ad.ghlStats!.cashAmount;
        }
        
        if (ad.adminConfig != null) {
          totalBudget += ad.adminConfig!.budget;
        }
        
        if (latestUpdate == null || ad.lastUpdated.isAfter(latestUpdate)) {
          latestUpdate = ad.lastUpdated;
        }
      }
      
      aggregates.add(CampaignAggregate(
        campaignId: campaignId,
        campaignName: campaignAds.first.campaignName,
        totalAds: campaignAds.length,
        totalAdSets: uniqueAdSets,
        totalFbSpend: totalFbSpend,
        totalImpressions: totalImpressions,
        totalReach: totalReach,
        totalClicks: totalClicks,
        totalLeads: totalLeads,
        totalBookings: totalBookings,
        totalDeposits: totalDeposits,
        totalCashCollected: totalCashCollected,
        totalCashAmount: totalCashAmount,
        totalBudget: totalBudget,
        lastUpdated: latestUpdate ?? DateTime.now(),
        ads: campaignAds,
      ));
    }
    
    return aggregates;
  }

  /// Get ad set-level aggregates from ad performance data
  List<AdSetAggregate> getAdSetAggregates(List<AdPerformanceWithProduct> ads) {
    final Map<String, List<AdPerformanceWithProduct>> adSetGroups = {};
    
    // Group ads by ad set
    for (final ad in ads) {
      // Skip ads without ad set ID
      if (ad.adSetId == null || ad.adSetId!.isEmpty) continue;
      
      if (!adSetGroups.containsKey(ad.adSetId)) {
        adSetGroups[ad.adSetId!] = [];
      }
      adSetGroups[ad.adSetId]!.add(ad);
    }
    
    // Create aggregates for each ad set
    final aggregates = <AdSetAggregate>[];
    for (final entry in adSetGroups.entries) {
      final adSetId = entry.key;
      final adSetAds = entry.value;
      
      if (adSetAds.isEmpty) continue;
      
      // Aggregate metrics
      double totalFbSpend = 0;
      int totalImpressions = 0;
      int totalReach = 0;
      int totalClicks = 0;
      int totalLeads = 0;
      int totalBookings = 0;
      int totalDeposits = 0;
      int totalCashCollected = 0;
      double totalCashAmount = 0;
      double totalBudget = 0;
      DateTime? latestUpdate;
      
      for (final ad in adSetAds) {
        totalFbSpend += ad.facebookStats.spend;
        totalImpressions += ad.facebookStats.impressions;
        totalReach += ad.facebookStats.reach;
        totalClicks += ad.facebookStats.clicks;
        
        if (ad.ghlStats != null) {
          totalLeads += ad.ghlStats!.leads;
          totalBookings += ad.ghlStats!.bookings;
          totalDeposits += ad.ghlStats!.deposits;
          totalCashCollected += ad.ghlStats!.cashCollected;
          totalCashAmount += ad.ghlStats!.cashAmount;
        }
        
        if (ad.adminConfig != null) {
          totalBudget += ad.adminConfig!.budget;
        }
        
        if (latestUpdate == null || ad.lastUpdated.isAfter(latestUpdate)) {
          latestUpdate = ad.lastUpdated;
        }
      }
      
      aggregates.add(AdSetAggregate(
        adSetId: adSetId,
        adSetName: adSetAds.first.adSetName ?? 'Unknown Ad Set',
        campaignId: adSetAds.first.campaignId,
        campaignName: adSetAds.first.campaignName,
        totalAds: adSetAds.length,
        totalFbSpend: totalFbSpend,
        totalImpressions: totalImpressions,
        totalReach: totalReach,
        totalClicks: totalClicks,
        totalLeads: totalLeads,
        totalBookings: totalBookings,
        totalDeposits: totalDeposits,
        totalCashCollected: totalCashCollected,
        totalCashAmount: totalCashAmount,
        totalBudget: totalBudget,
        lastUpdated: latestUpdate ?? DateTime.now(),
        ads: adSetAds,
      ));
    }
    
    return aggregates;
  }

  /// Get top performing ads by profit
  List<AdPerformanceWithProduct> getTopAdsByProfit(List<AdPerformanceWithProduct> ads, {int limit = 5}) {
    final sortedAds = List<AdPerformanceWithProduct>.from(ads)
      ..sort((a, b) => b.profit.compareTo(a.profit));
    return sortedAds.take(limit).toList();
  }

  /// Get top performing ad sets by profit
  List<AdSetAggregate> getTopAdSetsByProfit(List<AdPerformanceWithProduct> ads, {int limit = 5}) {
    final adSets = getAdSetAggregates(ads);
    adSets.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return adSets.take(limit).toList();
  }

  /// Get top performing campaigns by profit
  List<CampaignAggregate> getTopCampaignsByProfit(List<AdPerformanceWithProduct> ads, {int limit = 5}) {
    final campaigns = getCampaignAggregates(ads);
    campaigns.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return campaigns.take(limit).toList();
  }
}

/// Helper class for Facebook campaign summary (compatibility)
class FacebookCampaignSummary {
  final String id;
  final String name;
  final double spend;

  FacebookCampaignSummary({
    required this.id,
    required this.name,
    required this.spend,
  });
}

