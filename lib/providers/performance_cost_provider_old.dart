import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/performance/product.dart';
import '../models/performance/ad_performance_cost.dart';
import '../models/facebook/facebook_ad_data.dart';
import '../services/performance_cost_service.dart';
import '../services/facebook/facebook_ads_service.dart';
import 'gohighlevel_provider.dart';

/// Provider for managing performance cost data and state
class PerformanceCostProvider extends ChangeNotifier {
  // Data
  List<Product> _products = [];
  List<AdPerformanceCost> _adCosts = [];
  List<AdPerformanceCostWithMetrics> _mergedData = [];
  
  // Facebook data
  List<FacebookCampaignData> _facebookCampaigns = [];
  Map<String, List<FacebookAdData>> _facebookAdsByCampaign = {};
  List<FacebookAdData> _allFacebookAds = []; // Flattened list of all ads with Ad Set info
  Map<String, dynamic> _facebookHierarchy = {}; // Complete hierarchy: Campaign → Ad Sets → Ads
  bool _isFacebookDataLoading = false;
  DateTime? _lastFacebookSync;
  String? _facebookError;
  
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
  
  // Facebook getters
  List<FacebookCampaignData> get facebookCampaigns => _facebookCampaigns;
  Map<String, List<FacebookAdData>> get facebookAdsByCampaign => _facebookAdsByCampaign;
  List<FacebookAdData> get allFacebookAds => _allFacebookAds;
  Map<String, dynamic> get facebookHierarchy => _facebookHierarchy;
  bool get isFacebookDataLoading => _isFacebookDataLoading;
  DateTime? get lastFacebookSync => _lastFacebookSync;
  String? get facebookError => _facebookError;
  bool get hasFacebookData => _facebookCampaigns.isNotEmpty;

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

  // ========== FACEBOOK ADS DATA ==========

  /// Fetch Facebook Ads data with complete hierarchy (Campaign → Ad Sets → Ads)
  Future<void> fetchFacebookData({bool forceRefresh = false}) async {
    // Prevent multiple simultaneous fetches
    if (_isFacebookDataLoading) {
      if (kDebugMode) {
        print('⏳ Facebook data fetch already in progress, skipping...');
      }
      return;
    }
    
    _isFacebookDataLoading = true;
    _facebookError = null;
    notifyListeners();
    
    try {
      if (kDebugMode) {
        print('🌐 Fetching Facebook Ads data with complete hierarchy...');
      }
      
      // Fetch complete hierarchy: Campaign → Ad Sets → Ads
      _facebookHierarchy = await FacebookAdsService.fetchCompleteHierarchy(
        forceRefresh: forceRefresh,
      );
      
      // Extract campaigns from hierarchy
      _facebookCampaigns = [];
      _allFacebookAds = [];
      _facebookAdsByCampaign = {};
      
      for (final entry in _facebookHierarchy.entries) {
        final campaignData = entry.value;
        final campaign = campaignData['campaign'] as FacebookCampaignData;
        final adSets = campaignData['adSets'] as Map<String, dynamic>;
        
        _facebookCampaigns.add(campaign);
        
        // Flatten ads from all ad sets
        final List<FacebookAdData> campaignAds = [];
        for (final adSetEntry in adSets.entries) {
          final adSetData = adSetEntry.value;
          final ads = adSetData['ads'] as List<FacebookAdData>;
          campaignAds.addAll(ads);
          _allFacebookAds.addAll(ads);
        }
        
        _facebookAdsByCampaign[campaign.id] = campaignAds;
      }
      
      _lastFacebookSync = DateTime.now();
      _isFacebookDataLoading = false;
      
      if (kDebugMode) {
        print('✅ Facebook Ads data fetched successfully');
        print('   - Campaigns: ${_facebookCampaigns.length}');
        print('   - Total ads: ${_allFacebookAds.length}');
        
        // Count ad sets
        int totalAdSets = 0;
        for (final entry in _facebookHierarchy.entries) {
          final campaignData = entry.value;
          final adSets = campaignData['adSets'] as Map<String, dynamic>;
          totalAdSets += adSets.length;
        }
        print('   - Total ad sets: $totalAdSets');
      }
    } catch (e) {
      _facebookError = e.toString();
      _isFacebookDataLoading = false;
      
      if (kDebugMode) {
        print('❌ Error fetching Facebook data: $e');
      }
    }
    
    notifyListeners();
  }

  /// Refresh Facebook data (force fetch)
  Future<void> refreshFacebookData() async {
    return fetchFacebookData(forceRefresh: true);
  }

  /// Clear Facebook cache
  void clearFacebookCache() {
    FacebookAdsService.clearCache();
    _lastFacebookSync = null;
    if (kDebugMode) {
      print('🗑️ Facebook cache cleared');
    }
    notifyListeners();
  }

  /// Merge ad costs with cumulative campaign data and Facebook data
  Future<void> mergeWithCumulativeData(GoHighLevelProvider ghlProvider) async {
    try {
      if (kDebugMode) {
        print('🔄 Merging ad costs with cumulative data and Facebook data...');
      }

      // Fetch Facebook data first (using cache if available)
      if (_facebookCampaigns.isEmpty && !_isFacebookDataLoading) {
        await fetchFacebookData();
      } else if (_isFacebookDataLoading) {
        if (kDebugMode) {
          print('⏳ Facebook data is loading, waiting for it to complete...');
        }
        // Wait for Facebook data to finish loading (max 30 seconds)
        int attempts = 0;
        const maxAttempts = 60; // 60 * 500ms = 30 seconds max
        while (_isFacebookDataLoading && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }
        
        if (_isFacebookDataLoading) {
          if (kDebugMode) {
            print('⚠️ Facebook data loading timeout after ${attempts * 500}ms, proceeding without Facebook data');
          }
          // Don't return - proceed with merge even without Facebook data
        } else {
          if (kDebugMode) {
            print('✅ Facebook data finished loading after ${attempts * 500}ms');
          }
        }
      }

      // Sync Facebook data with adCosts (update spend, impressions, etc.)
      final updatedAdCosts = _syncFacebookDataWithAdCosts(_adCosts);

      _mergedData = await PerformanceCostService.getMergedPerformanceData(
        adCosts: updatedAdCosts,
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

  /// Sync Facebook data with AdPerformanceCost records
  /// NEW APPROACH: Start with ALL Facebook ads, then enrich with GHL data
  /// This ensures we show ALL Facebook ads (279) instead of just GHL ads (3)
  List<AdPerformanceCost> _syncFacebookDataWithAdCosts(List<AdPerformanceCost> adCosts) {
    if (_allFacebookAds.isEmpty) {
      // If no Facebook data, return empty list
      if (kDebugMode) {
        print('⚠️ No Facebook ads loaded - showing no ads until Facebook data is available');
      }
      return [];
    }

    if (kDebugMode) {
      print('🔍 Creating ad entries from ${_allFacebookAds.length} Facebook ads, enriching with ${adCosts.length} GHL records...');
    }

    // Create a map of GHL ads by normalized name for quick lookup
    final ghlAdsByName = <String, AdPerformanceCost>{};
    for (final ghlAd in adCosts) {
      final normalizedName = _normalizeAdName(ghlAd.adName);
      ghlAdsByName[normalizedName] = ghlAd;
    }

    // Start with ALL Facebook ads and enrich with GHL data where available
    final allAds = <AdPerformanceCost>[];
    
    for (final fbAd in _allFacebookAds) {
      final normalizedFbAdName = _normalizeAdName(fbAd.name);
      final matchingGhlAd = ghlAdsByName[normalizedFbAdName];
      
      if (matchingGhlAd != null) {
        // Facebook ad HAS GHL data - merge them
        allAds.add(matchingGhlAd.copyWith(
          facebookCampaignId: fbAd.campaignId,
          facebookSpend: fbAd.spend,
          impressions: fbAd.impressions,
          reach: fbAd.reach,
          clicks: fbAd.clicks,
          cpm: fbAd.cpm,
          cpc: fbAd.cpc,
          ctr: fbAd.ctr,
          lastFacebookSync: DateTime.now(),
        ));
        
        if (kDebugMode) {
          final adSetInfo = fbAd.adSetName != null ? ' [Ad Set: ${fbAd.adSetName}]' : '';
          print('✅ Matched: ${fbAd.name}$adSetInfo → Has GHL data (${matchingGhlAd.adName})');
        }
      } else {
        // Facebook ad WITHOUT GHL data - create new entry with Facebook data only
        // Find the campaign name for this ad
        final campaign = _facebookCampaigns.firstWhere(
          (c) => c.id == fbAd.campaignId,
          orElse: () => _facebookCampaigns.first,
        );
        
        allAds.add(AdPerformanceCost(
          id: fbAd.id, // Use Facebook ad ID
          campaignName: campaign.name,
          campaignKey: fbAd.campaignId,
          adId: fbAd.id,
          adName: fbAd.name,
          budget: 0, // No GHL budget data
          linkedProductId: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'facebook_sync',
          facebookCampaignId: fbAd.campaignId,
          facebookSpend: fbAd.spend,
          impressions: fbAd.impressions,
          reach: fbAd.reach,
          clicks: fbAd.clicks,
          cpm: fbAd.cpm,
          cpc: fbAd.cpc,
          ctr: fbAd.ctr,
          lastFacebookSync: DateTime.now(),
        ));
        
        if (kDebugMode) {
          final adSetInfo = fbAd.adSetName != null ? ' [Ad Set: ${fbAd.adSetName}]' : '';
          print('ℹ️ Facebook-only: ${fbAd.name}$adSetInfo (no GHL data)');
        }
      }
    }

    if (kDebugMode) {
      final withGhl = allAds.where((ad) => ad.createdBy != 'facebook_sync').length;
      final fbOnly = allAds.length - withGhl;
      print('📊 Created ${allAds.length} total ads: $withGhl with GHL data, $fbOnly Facebook-only');
    }

    return allAds;
  }
  
  /// Helper: Normalize ad name for matching (remove special chars, lowercase, trim)
  String _normalizeAdName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
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
    String? facebookCampaignId,
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
        facebookCampaignId: facebookCampaignId,
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

