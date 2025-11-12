import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/performance/ad_performance_data.dart' as perf_data;
import '../models/performance/ad_performance_cost.dart';
import '../models/performance/campaign_aggregate.dart';
import '../models/performance/ad_set_aggregate.dart';
import '../models/performance/advert_data_models.dart';
import '../services/firebase/ad_performance_service.dart';
import '../services/firebase/advert_data_service.dart';
import '../services/firebase/campaign_service.dart';
import '../services/firebase/ad_set_service.dart';
import '../services/firebase/ad_service.dart';
import '../models/performance/campaign.dart';
import '../models/performance/ad_set.dart';
import '../models/performance/ad.dart' as split_ad;

/// Provider for managing ad performance data (Facebook + GHL from Firebase)
class PerformanceCostProvider extends ChangeNotifier {
  // Feature flag for split collections
  static const bool USE_SPLIT_COLLECTIONS =
      true; // Set to true to enable new schema

  // Services for split collections
  final CampaignService _campaignService = CampaignService();
  final AdSetService _adSetService = AdSetService();
  final AdService _adService = AdService();

  // Data for split collections
  List<Campaign> _campaigns = [];
  List<AdSet> _adSets = [];
  List<split_ad.Ad> _ads = [];
  // Data
  List<perf_data.AdPerformanceData> _adPerformanceData = [];
  List<perf_data.AdPerformanceWithProduct> _adPerformanceWithProducts = [];

  // Month management
  List<String> _availableMonths = [];
  List<String> _selectedMonths = [];

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DateTime? _lastSync;
  bool _isSyncing = false;

  // Getters
  List<perf_data.AdPerformanceData> get adPerformanceData => _adPerformanceData;
  List<perf_data.AdPerformanceWithProduct> get adPerformanceWithProducts =>
      _adPerformanceWithProducts;
  List<String> get availableMonths => _availableMonths;
  List<String> get selectedMonths => _selectedMonths;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;

  // Deprecated: Product functionality removed
  @Deprecated(
    'Product functionality removed. Profit now comes from GHL opportunity values.',
  )
  List<dynamic> get products => [];

  // Getters for split collections
  List<Campaign> get campaigns => _campaigns;
  List<AdSet> get adSets => _adSets;
  List<split_ad.Ad> get ads => _ads;

  // Quick stats
  int get totalAds =>
      USE_SPLIT_COLLECTIONS ? _ads.length : _adPerformanceData.length;
  int get matchedAds => USE_SPLIT_COLLECTIONS
      ? _ads.where((ad) => ad.ghlStats.leads > 0).length
      : _adPerformanceData
            .where(
              (ad) => ad.matchingStatus == perf_data.MatchingStatus.matched,
            )
            .length;
  int get unmatchedAds => USE_SPLIT_COLLECTIONS
      ? _ads.where((ad) => ad.ghlStats.leads == 0).length
      : _adPerformanceData
            .where(
              (ad) => ad.matchingStatus == perf_data.MatchingStatus.unmatched,
            )
            .length;

  /// Filter campaigns by date range
  List<Campaign> getFilteredCampaigns({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (!USE_SPLIT_COLLECTIONS || (startDate == null && endDate == null)) {
      return _campaigns;
    }

    return _campaigns.where((campaign) {
      final campaignStart = campaign.firstAdDateAsDateTime;
      final campaignEnd = campaign.lastAdDateAsDateTime;

      if (campaignStart == null && campaignEnd == null) return true;

      if (campaignStart != null &&
          endDate != null &&
          campaignStart.isAfter(endDate)) {
        return false;
      }

      if (campaignEnd != null &&
          startDate != null &&
          campaignEnd.isBefore(startDate)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Filter ad sets by date range
  List<AdSet> getFilteredAdSets({DateTime? startDate, DateTime? endDate}) {
    if (!USE_SPLIT_COLLECTIONS || (startDate == null && endDate == null)) {
      return _adSets;
    }

    return _adSets.where((adSet) {
      final adSetStart = adSet.firstAdDateAsDateTime;
      final adSetEnd = adSet.lastAdDateAsDateTime;

      if (adSetStart == null && adSetEnd == null) return true;

      if (adSetStart != null &&
          endDate != null &&
          adSetStart.isAfter(endDate)) {
        return false;
      }

      if (adSetEnd != null &&
          startDate != null &&
          adSetEnd.isBefore(startDate)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Filter ads by date range
  List<split_ad.Ad> getFilteredAds({DateTime? startDate, DateTime? endDate}) {
    if (!USE_SPLIT_COLLECTIONS || (startDate == null && endDate == null)) {
      return _ads;
    }

    return _ads.where((ad) {
      // Try to parse the insight dates
      DateTime? adStart;
      DateTime? adEnd;

      try {
        if (ad.firstInsightDate != null && ad.firstInsightDate!.isNotEmpty) {
          adStart = DateTime.parse(ad.firstInsightDate!);
        }
        if (ad.lastInsightDate != null && ad.lastInsightDate!.isNotEmpty) {
          adEnd = DateTime.parse(ad.lastInsightDate!);
        }
      } catch (e) {
        // If parsing fails, include the ad
        return true;
      }

      if (adStart == null && adEnd == null) {
        return true;
      }

      if (adStart != null && endDate != null && adStart.isAfter(endDate)) {
        return false;
      }

      if (adEnd != null && startDate != null && adEnd.isBefore(startDate)) {
        return false;
      }

      return true;
    }).toList();
  }

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
      if (USE_SPLIT_COLLECTIONS) {
        if (kDebugMode) {
          print('📊 Using SPLIT COLLECTIONS schema');
          print(
            '   ⏸️  Campaigns will load on filter selection (no auto-load)',
          );
        }

        _isInitialized = true;
        _isLoading = false;

        if (kDebugMode) {
          print(
            '✅ Performance Cost Provider: Initialized successfully (Split Collections)',
          );
          print('   - Ready to load campaigns on demand');
        }
      } else {
        // OLD: Load from advertData
        if (kDebugMode) {
          print('📊 Using OLD advertData schema');
        }

        // Load available months first
        await loadAvailableMonths();

        // Load data with default months (last 3 months)
        await loadAdPerformanceData();

        if (kDebugMode) {
          print(
            '✅ Performance Cost Provider: Initialized successfully (advertData)',
          );
          print('   - Available months: ${_availableMonths.length}');
          print('   - Selected months: $_selectedMonths');
          print(
            '   - Ads: ${_adPerformanceData.length} (Matched: $matchedAds, Unmatched: $unmatchedAds)',
          );
        }

        _isInitialized = true;
        _isLoading = false;
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

  /// Load available months from Firebase
  Future<void> loadAvailableMonths() async {
    // Guard: Split collections don't use month-based structure
    if (USE_SPLIT_COLLECTIONS) {
      if (kDebugMode) {
        print(
          '⏭️  Skipping loadAvailableMonths() - Split collections don\'t use month structure',
        );
      }
      _availableMonths = [];
      _selectedMonths = [];
      return;
    }

    try {
      _availableMonths = await AdvertDataService.getAvailableMonths();

      // Default to current month only (November 2025)
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (_availableMonths.contains(currentMonth)) {
        _selectedMonths = [currentMonth];
      } else if (_availableMonths.isNotEmpty) {
        // Fallback to most recent month if current month not available
        _selectedMonths = [_availableMonths.first];
      } else {
        _selectedMonths = [];
      }

      if (kDebugMode) {
        print('✅ Loaded ${_availableMonths.length} available months');
        print('   - Current month: $currentMonth');
        print('   - Default selection: $_selectedMonths');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading available months: $e');
      }
      // Set empty lists on error
      _availableMonths = [];
      _selectedMonths = [];
    }
  }

  /// Set selected months and reload data
  Future<void> setSelectedMonths(
    List<String> months, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _selectedMonths = months;

    if (USE_SPLIT_COLLECTIONS) {
      // NEW: Split collections - Load campaigns with date range query
      if (kDebugMode) {
        print('🔄 Split Collections: Loading campaigns with date range');
        print(
          '   - Date range: ${startDate?.toIso8601String() ?? "any"} to ${endDate?.toIso8601String() ?? "any"}',
        );
      }

      // Call the new loadCampaignsWithDateRange method
      await loadCampaignsWithDateRange(startDate: startDate, endDate: endDate);

      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadAdPerformanceData(
        months: months,
        startDate: startDate,
        endDate: endDate,
      );

      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;

      if (kDebugMode) {
        print('❌ Error setting selected months: $e');
      }
    }

    notifyListeners();
  }

  /// Load all ad performance data from Firebase (using advertData collection)
  /// Uses month-first structure with optional date filtering
  Future<void> loadAdPerformanceData({
    List<String>? months,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ad performance data from advertData collection...');
      }

      // Use provided months or default to selected months
      final effectiveMonths = months ?? _selectedMonths;

      // If no months selected, default to last 3 available months
      if (effectiveMonths.isEmpty && _availableMonths.isNotEmpty) {
        effectiveMonths.addAll(_availableMonths.take(3));
      }

      if (effectiveMonths.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No months available to query');
        }
        _adPerformanceData = [];
        _adPerformanceWithProducts = [];
        notifyListeners();
        return;
      }

      // Fetch from advertData collection with aggregated totals
      final advertsWithTotals = await AdvertDataService.getAllAdvertsWithTotals(
        months: effectiveMonths,
        startDate: startDate,
        endDate: endDate,
      );

      _adPerformanceData = advertsWithTotals.map((advertWithTotals) {
        return _convertToAdPerformanceData(advertWithTotals);
      }).toList();

      // Wrap ad performance data (no product linking)
      _adPerformanceWithProducts = _adPerformanceData.map((ad) {
        return perf_data.AdPerformanceWithProduct(data: ad);
      }).toList();

      _lastSync = DateTime.now();

      if (kDebugMode) {
        print(
          '✅ Loaded ${_adPerformanceData.length} ad performance records from advertData',
        );
        print('   - Months queried: $effectiveMonths');
        print('   - Matched (FB + GHL): $matchedAds');
        print('   - Unmatched (FB only): $unmatchedAds');
        if (startDate != null || endDate != null) {
          print(
            '   - Date filter: ${startDate?.toIso8601String() ?? "any"} to ${endDate?.toIso8601String() ?? "any"}',
          );
        }

        // Print detailed stats for each ad
        print('\n📊 DETAILED AD STATS FOR SELECTED MONTHS:');
        print('═' * 80);
        for (var ad in _adPerformanceData) {
          print('🎯 ${ad.adName} (ID: ${ad.adId})');
          print('   Campaign: ${ad.campaignName}');
          print('   Ad Set: ${ad.adSetName}');
          print('   📱 Facebook Stats:');
          print('      Spend: \$${ad.facebookStats.spend.toStringAsFixed(2)}');
          print('      Impressions: ${ad.facebookStats.impressions}');
          print('      Clicks: ${ad.facebookStats.clicks}');
          print('      Reach: ${ad.facebookStats.reach}');
          print('      CPM: \$${ad.facebookStats.cpm.toStringAsFixed(2)}');
          print('      CPC: \$${ad.facebookStats.cpc.toStringAsFixed(2)}');
          print('      CTR: ${ad.facebookStats.ctr.toStringAsFixed(2)}%');
          if (ad.ghlStats != null) {
            print('   💰 GHL Stats:');
            print('      Leads: ${ad.ghlStats!.leads}');
            print(
              '      Cash Amount: \$${ad.ghlStats!.cashAmount.toStringAsFixed(2)}',
            );
            print('      Bookings: ${ad.ghlStats!.bookings}');
            print('      Deposits: ${ad.ghlStats!.deposits}');
            print(
              '   📈 PROFIT: \$${(ad.ghlStats!.cashAmount - ad.facebookStats.spend).toStringAsFixed(2)}',
            );
          } else {
            print('   💰 GHL Stats: No data');
            print(
              '   📈 PROFIT: -\$${ad.facebookStats.spend.toStringAsFixed(2)} (loss)',
            );
          }
          print('   ' + '─' * 76);
        }
        print('═' * 80);

        // Print aggregated totals
        double totalSpend = _adPerformanceData.fold(
          0.0,
          (sum, ad) => sum + ad.facebookStats.spend,
        );
        int totalImpressions = _adPerformanceData.fold(
          0,
          (sum, ad) => sum + ad.facebookStats.impressions,
        );
        int totalClicks = _adPerformanceData.fold(
          0,
          (sum, ad) => sum + ad.facebookStats.clicks,
        );
        int totalReach = _adPerformanceData.fold(
          0,
          (sum, ad) => sum + ad.facebookStats.reach,
        );
        int totalGHLLeads = _adPerformanceData.fold(
          0,
          (sum, ad) => sum + (ad.ghlStats?.leads ?? 0),
        );
        double totalCash = _adPerformanceData.fold(
          0.0,
          (sum, ad) => sum + (ad.ghlStats?.cashAmount ?? 0),
        );
        double totalProfit = totalCash - totalSpend;

        print('📊 AGGREGATED TOTALS:');
        print('   Total Ads: ${_adPerformanceData.length}');
        print('   Total Spend: \$${totalSpend.toStringAsFixed(2)}');
        print('   Total Impressions: $totalImpressions');
        print('   Total Clicks: $totalClicks');
        print('   Total Reach: $totalReach');
        print('   Total GHL Leads: $totalGHLLeads');
        print('   Total Cash (GHL): \$${totalCash.toStringAsFixed(2)}');
        print('   TOTAL PROFIT: \$${totalProfit.toStringAsFixed(2)}');

        // Check if GHL data is missing
        int adsWithGHL = _adPerformanceData
            .where((ad) => ad.ghlStats != null)
            .length;
        if (adsWithGHL == 0) {
          print('');
          print('⚠️  WARNING: NO GHL DATA FOUND!');
          print('   This month may not have GHL data populated yet.');
          print(
            '   Check Firebase: advertData/$effectiveMonths/ads/{adId}/ghlWeekly/',
          );
          print('   Run populate_ghl_data.py to add GHL data for this month.');
        } else {
          print(
            '   Ads with GHL data: $adsWithGHL / ${_adPerformanceData.length}',
          );
        }

        print('═' * 80);
        print('');
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

  /// Convert AdvertDataWithTotals to AdPerformanceData format
  perf_data.AdPerformanceData _convertToAdPerformanceData(
    AdvertDataWithTotals advertWithTotals,
  ) {
    final advert = advertWithTotals.advert;
    final fbTotals = advertWithTotals.facebookTotals;
    final ghlTotals = advertWithTotals.ghlTotals;

    // Create FacebookStats from aggregated totals
    final facebookStats = perf_data.FacebookStats(
      spend: fbTotals.totalSpend,
      impressions: fbTotals.totalImpressions,
      reach: fbTotals.totalReach,
      clicks: fbTotals.totalClicks,
      cpm: fbTotals.avgCPM,
      cpc: fbTotals.avgCPC,
      ctr: fbTotals.avgCTR,
      dateStart: fbTotals.dateStart,
      dateStop: fbTotals.dateStop,
      lastSync: advert.lastFacebookSync ?? DateTime.now(),
    );

    // Create GHLStats from aggregated totals (using actual opportunity values)
    perf_data.GHLStats? ghlStats;
    if (ghlTotals.totalLeads > 0) {
      ghlStats = perf_data.GHLStats(
        campaignKey: advert.campaignId,
        leads: ghlTotals.totalLeads,
        bookings: ghlTotals.totalBookedAppointments,
        deposits: ghlTotals.totalDeposits,
        cashCollected: ghlTotals.totalCashCollected,
        cashAmount: ghlTotals
            .totalCashAmount, // CRITICAL: Using actual opportunity values
        lastSync: advert.lastGHLSync ?? DateTime.now(),
      );
    }

    // Determine matching status
    final matchingStatus = ghlStats != null
        ? perf_data.MatchingStatus.matched
        : perf_data.MatchingStatus.unmatched;

    return perf_data.AdPerformanceData(
      adId: advert.adId,
      adName: advert.adName,
      campaignId: advert.campaignId,
      campaignName: advert.campaignName,
      adSetId: advert.adSetId,
      adSetName: advert.adSetName,
      matchingStatus: matchingStatus,
      lastUpdated: advert.lastUpdated ?? DateTime.now(),
      facebookStats: facebookStats,
      ghlStats: ghlStats,
    );
  }

  /// Refresh all data with optional months and date range
  Future<void> refreshData({
    List<String>? months,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadAdPerformanceData(
        months: months,
        startDate: startDate,
        endDate: endDate,
      );

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

  // ========== AD PERFORMANCE OPERATIONS ==========

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Deprecated product methods

  @Deprecated(
    'Product functionality removed. Profit now comes from GHL opportunity values.',
  )
  Future<dynamic> createProduct({
    required String name,
    required double depositAmount,
    required double expenseCost,
    String? createdBy,
  }) async {
    throw UnimplementedError(
      'Product functionality has been removed. Profit now comes directly from GHL opportunity values.',
    );
  }

  @Deprecated(
    'Product functionality removed. Profit now comes from GHL opportunity values.',
  )
  Future<void> updateProduct(dynamic product) async {
    throw UnimplementedError(
      'Product functionality has been removed. Profit now comes directly from GHL opportunity values.',
    );
  }

  @Deprecated(
    'Product functionality removed. Profit now comes from GHL opportunity values.',
  )
  Future<void> deleteProduct(String productId) async {
    throw UnimplementedError(
      'Product functionality has been removed. Profit now comes directly from GHL opportunity values.',
    );
  }

  @Deprecated(
    'Product functionality removed. Profit now comes from GHL opportunity values.',
  )
  dynamic getProductById(String productId) {
    return null;
  }

  // Compatibility methods

  /// Get merged data
  List<perf_data.AdPerformanceWithProduct> getMergedData(dynamic ghlProvider) {
    return _adPerformanceWithProducts;
  }

  /// Merge with cumulative data
  Future<void> mergeWithCumulativeData(
    dynamic ghlProvider, {
    List<String>? months,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Data is already merged in Firebase by Cloud Functions
    // Just refresh to get latest with months and date range
    await refreshData(months: months, startDate: startDate, endDate: endDate);
  }

  /// Refresh Facebook data
  Future<void> refreshFacebookData() async {
    await syncFacebookData();
  }

  /// Check if has Facebook data
  bool get hasFacebookData => _adPerformanceData.isNotEmpty;

  /// Last Facebook sync time
  DateTime? get lastFacebookSync => _lastSync;

  /// Is Facebook data loading
  bool get isFacebookDataLoading => _isSyncing;

  /// Get Facebook campaigns
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

  /// Get ad costs
  List<dynamic> get adCosts => [];

  /// Create ad performance cost
  Future<void> createAdPerformanceCost({
    required String campaignName,
    required String campaignKey,
    required String adId,
    required String adName,
    required double budget,
    String? facebookCampaignId,
  }) async {
    throw UnimplementedError(
      'Use syncFacebookData() to add ads from Facebook API',
    );
  }

  /// Update ad performance cost
  Future<void> updateAdPerformanceCost(
    AdPerformanceCost cost, {
    double? budget,
  }) async {
    // In the new system, budget and product linking are not used
    // Profit comes directly from GHL opportunity values
    throw UnimplementedError(
      'Budget and product configuration removed - profit comes from GHL',
    );
  }

  /// Delete ad performance cost
  Future<void> deleteAdPerformanceCost(String id) async {
    throw UnimplementedError(
      'Ads are synced from Facebook API and should not be manually deleted',
    );
  }

  // ========== AGGREGATION METHODS ==========

  /// Get campaign-level aggregates from ad performance data
  List<CampaignAggregate> getCampaignAggregates(
    List<perf_data.AdPerformanceWithProduct> ads,
  ) {
    final Map<String, List<perf_data.AdPerformanceWithProduct>> campaignGroups =
        {};

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

        // Budget field removed - no longer used

        if (latestUpdate == null || ad.lastUpdated.isAfter(latestUpdate)) {
          latestUpdate = ad.lastUpdated;
        }
      }

      aggregates.add(
        CampaignAggregate(
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
        ),
      );
    }

    return aggregates;
  }

  /// Get ad set-level aggregates from ad performance data
  List<AdSetAggregate> getAdSetAggregates(
    List<perf_data.AdPerformanceWithProduct> ads,
  ) {
    final Map<String, List<perf_data.AdPerformanceWithProduct>> adSetGroups =
        {};

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

        // Budget field removed - no longer used

        if (latestUpdate == null || ad.lastUpdated.isAfter(latestUpdate)) {
          latestUpdate = ad.lastUpdated;
        }
      }

      aggregates.add(
        AdSetAggregate(
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
        ),
      );
    }

    return aggregates;
  }

  /// Get top performing ads by profit
  List<perf_data.AdPerformanceWithProduct> getTopAdsByProfit(
    List<perf_data.AdPerformanceWithProduct> ads, {
    int limit = 5,
  }) {
    final sortedAds = List<perf_data.AdPerformanceWithProduct>.from(ads)
      ..sort((a, b) => b.profit.compareTo(a.profit));
    return sortedAds.take(limit).toList();
  }

  /// Get top performing ad sets by profit
  List<AdSetAggregate> getTopAdSetsByProfit(
    List<perf_data.AdPerformanceWithProduct> ads, {
    int limit = 5,
  }) {
    final adSets = getAdSetAggregates(ads);
    adSets.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return adSets.take(limit).toList();
  }

  /// Get top performing campaigns by profit
  List<CampaignAggregate> getTopCampaignsByProfit(
    List<perf_data.AdPerformanceWithProduct> ads, {
    int limit = 5,
  }) {
    final campaigns = getCampaignAggregates(ads);
    campaigns.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return campaigns.take(limit).toList();
  }

  // ============================================================================
  // SPLIT COLLECTIONS ADAPTER METHODS (Convert new models to UI models)
  // ============================================================================

  /// Convert Campaign to CampaignAggregate
  CampaignAggregate campaignToCampaignAggregate(Campaign campaign) {
    return CampaignAggregate(
      campaignId: campaign.campaignId,
      campaignName: campaign.campaignName,
      totalAds: campaign.adCount,
      totalAdSets: campaign.adSetCount,
      totalFbSpend: campaign.totalSpend,
      totalImpressions: campaign.totalImpressions,
      totalReach: campaign.totalReach,
      totalClicks: campaign.totalClicks,
      totalLeads: campaign.totalLeads,
      totalBookings: campaign.totalBookings,
      totalDeposits: campaign.totalDeposits,
      totalCashCollected: campaign.totalCashCollected,
      totalCashAmount: campaign.totalCashAmount,
      totalBudget: 0, // Not used in new schema
      lastUpdated: campaign.lastUpdated ?? DateTime.now(),
      ads: [], // Loaded on-demand when campaign clicked
    );
  }

  /// Convert AdSet to AdSetAggregate
  AdSetAggregate adSetToAdSetAggregate(AdSet adSet) {
    return AdSetAggregate(
      adSetId: adSet.adSetId,
      adSetName: adSet.adSetName,
      campaignId: adSet.campaignId,
      campaignName: adSet.campaignName,
      totalAds: adSet.adCount,
      totalFbSpend: adSet.totalSpend,
      totalImpressions: adSet.totalImpressions,
      totalReach: adSet.totalReach,
      totalClicks: adSet.totalClicks,
      totalLeads: adSet.totalLeads,
      totalBookings: adSet.totalBookings,
      totalDeposits: adSet.totalDeposits,
      totalCashCollected: adSet.totalCashCollected,
      totalCashAmount: adSet.totalCashAmount,
      totalBudget: 0, // Not used in new schema
      lastUpdated: adSet.lastUpdated ?? DateTime.now(),
      ads: [], // Loaded on-demand when ad set clicked
    );
  }

  /// Convert Ad to AdPerformanceWithProduct
  perf_data.AdPerformanceWithProduct adToAdPerformanceWithProduct(
    split_ad.Ad ad,
  ) {
    // Convert FacebookStats from Ad model to AdPerformanceData model
    final fbStats = perf_data.FacebookStats(
      spend: ad.facebookStats.spend,
      impressions: ad.facebookStats.impressions,
      reach: ad.facebookStats.reach,
      clicks: ad.facebookStats.clicks,
      cpm: ad.facebookStats.cpm,
      cpc: ad.facebookStats.cpc,
      ctr: ad.facebookStats.ctr,
      dateStart: ad.facebookStats.dateStart,
      dateStop: ad.facebookStats.dateStop,
      lastSync: ad.lastFacebookSync ?? DateTime.now(),
    );

    // Convert GHLStats from Ad model to AdPerformanceData model (only if has leads)
    perf_data.GHLStats? ghlStats;
    if (ad.ghlStats.leads > 0) {
      ghlStats = perf_data.GHLStats(
        campaignKey: ad.campaignId,
        leads: ad.ghlStats.leads,
        bookings: ad.ghlStats.bookings,
        deposits: ad.ghlStats.deposits,
        cashCollected: ad.ghlStats.cashCollected,
        cashAmount: ad.ghlStats.cashAmount,
        lastSync: ad.lastGHLSync ?? DateTime.now(),
      );
    }

    return perf_data.AdPerformanceWithProduct(
      data: perf_data.AdPerformanceData(
        adId: ad.adId,
        adName: ad.adName,
        campaignId: ad.campaignId,
        campaignName: ad.campaignName,
        adSetId: ad.adSetId,
        adSetName: ad.adSetName,
        matchingStatus: ad.ghlStats.leads > 0
            ? perf_data.MatchingStatus.matched
            : perf_data.MatchingStatus.unmatched,
        lastUpdated: ad.lastUpdated ?? DateTime.now(),
        facebookStats: fbStats,
        ghlStats: ghlStats,
      ),
    );
  }

  // ============================================================================
  // SPLIT COLLECTIONS METHODS (NEW SCHEMA)
  // ============================================================================

  /// Load campaigns from split collections
  Future<void> loadCampaignsFromSplitCollections({
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading campaigns from split collections...');
      }

      _campaigns = await _campaignService.getAllCampaigns(
        limit: limit,
        orderBy: orderBy,
        descending: descending,
      );

      if (kDebugMode) {
        print('✅ Loaded ${_campaigns.length} campaigns from split collections');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading campaigns from split collections: $e');
      }
      rethrow;
    }
  }

  /// Load campaigns with date range filter
  Future<void> loadCampaignsWithDateRange({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 Loading campaigns with date range from split collections...');
        print('   - Start date: ${startDate?.toIso8601String() ?? "any"}');
        print('   - End date: ${endDate?.toIso8601String() ?? "any"}');
        print('   - Order by: $orderBy (${descending ? "desc" : "asc"})');
      }

      // Use dynamic calculation to get date-range-specific totals
      // This calculates from ads collection filtered by date range
      // Includes BOTH Facebook stats AND GHL stats for the date range
      _campaigns = await _campaignService.getCampaignsWithDateRangeTotals(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        orderBy: orderBy,
        descending: descending,
      );

      _filterStartDate = startDate;
      _filterEndDate = endDate;

      _adSets = [];
      _ads = [];

      _isLoading = false;

      if (kDebugMode) {
        print('✅ Loaded ${_campaigns.length} campaigns from split collections');
        final totalSpend = _campaigns.fold(0.0, (sum, c) => sum + c.totalSpend);
        final totalLeads = _campaigns.fold(0, (sum, c) => sum + c.totalLeads);
        print('   - Total spend: \$${totalSpend.toStringAsFixed(2)}');
        print('   - Total leads: $totalLeads');
        
        // Show top 3 campaigns by SPEND for verification
        if (_campaigns.isNotEmpty) {
          print('   📋 Top 3 campaigns by PROFIT (current sort):');
          for (var i = 0; i < (_campaigns.length > 3 ? 3 : _campaigns.length); i++) {
            final c = _campaigns[i];
            print('      ${i + 1}. ${c.campaignName}');
            print('          Spend: \$${c.totalSpend.toStringAsFixed(2)}, Profit: \$${c.totalProfit.toStringAsFixed(2)}');
          }
          
          // Also show top 3 by SPEND
          final bySpend = List<Campaign>.from(_campaigns)..sort((a, b) => b.totalSpend.compareTo(a.totalSpend));
          print('   💰 Top 3 campaigns by SPEND:');
          for (var i = 0; i < (bySpend.length > 3 ? 3 : bySpend.length); i++) {
            final c = bySpend[i];
            print('      ${i + 1}. ${c.campaignName}');
            print('          Spend: \$${c.totalSpend.toStringAsFixed(2)}, Profit: \$${c.totalProfit.toStringAsFixed(2)}');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;

      if (kDebugMode) {
        print('❌ Error loading campaigns with date range: $e');
      }

      notifyListeners();
      rethrow;
    }
  }

  /// Load ad sets for a campaign from split collections
  /// Uses date-range-specific totals when date filters are active
  Future<void> loadAdSetsForCampaign(
    String campaignId, {
    String orderBy = 'totalProfit',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ad sets for campaign $campaignId...');
        if (_filterStartDate != null || _filterEndDate != null) {
          print('   📅 With date filtering: ${_filterStartDate?.toIso8601String() ?? "any"} to ${_filterEndDate?.toIso8601String() ?? "any"}');
        }
      }

      // Use dynamic calculation if date filters are active
      // This calculates from ads collection filtered by date range
      // Includes BOTH Facebook stats AND GHL stats for the date range
      if (_filterStartDate != null || _filterEndDate != null) {
        _adSets = await _adSetService.getAdSetsWithDateRangeTotals(
          campaignId: campaignId,
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          orderBy: orderBy,
          descending: descending,
        );
      } else {
        // Use pre-aggregated lifetime totals if no date filtering
        _adSets = await _adSetService.getAdSetsForCampaign(
          campaignId,
          orderBy: orderBy,
          descending: descending,
        );
      }

      if (kDebugMode) {
        print('✅ Loaded ${_adSets.length} ad sets');
        if (_adSets.isNotEmpty) {
          final totalSpend = _adSets.fold(0.0, (sum, adSet) => sum + adSet.totalSpend);
          print('   💰 Total ad set spend: \$${totalSpend.toStringAsFixed(2)}');
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading ad sets: $e');
      }
      rethrow;
    }
  }

  /// Load ads for an ad set from split collections
  Future<void> loadAdsForAdSet(
    String adSetId, {
    String orderBy = 'facebookStats.spend',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ads for ad set $adSetId...');
      }

      _ads = await _adService.getAdsForAdSet(
        adSetId,
        orderBy: orderBy,
        descending: descending,
      );

      if (kDebugMode) {
        print('✅ Loaded ${_ads.length} ads');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading ads: $e');
      }
      rethrow;
    }
  }

  /// Load ads for a campaign from split collections
  Future<void> loadAdsForCampaign(
    String campaignId, {
    String orderBy = 'lastUpdated',
    bool descending = true,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading ads for campaign $campaignId...');
      }

      _ads = await _adService.getAdsForCampaign(
        campaignId,
        orderBy: orderBy,
        descending: descending,
      );

      if (kDebugMode) {
        print('✅ Loaded ${_ads.length} ads');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading ads: $e');
      }
      rethrow;
    }
  }

  /// Get ad sets for a specific campaign (from loaded data)
  List<AdSet> getAdSetsForCampaignLocal(String campaignId) {
    return _adSets.where((adSet) => adSet.campaignId == campaignId).toList();
  }

  /// Get ads for a specific ad set (from loaded data)
  List<split_ad.Ad> getAdsForAdSetLocal(String adSetId) {
    return _ads.where((ad) => ad.adSetId == adSetId).toList();
  }

  /// Get ads for a specific campaign (from loaded data)
  List<split_ad.Ad> getAdsForCampaignLocal(String campaignId) {
    return _ads.where((ad) => ad.campaignId == campaignId).toList();
  }
}

/// Helper class for Facebook campaign summary
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
