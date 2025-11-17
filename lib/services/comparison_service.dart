import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/comparison/comparison_models.dart';
import '../models/comparison/comparison_list_models.dart';
import '../models/facebook/facebook_ad_data.dart';
import 'firebase/campaign_service.dart';
import 'firebase/ad_set_service.dart';
import 'firebase/summary_service.dart';
import 'firebase/weekly_insights_service.dart';

/// Service for comparing campaigns, ad sets, and ads across time periods or against each other
class ComparisonService {
  final CampaignService _campaignService = CampaignService();
  final AdSetService _adSetService = AdSetService();
  final SummaryService _summaryService = SummaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // CAMPAIGN COMPARISONS
  // ============================================================================

  /// Compare a campaign across two months using pre-aggregated monthlyTotals (FAST)
  Future<ComparisonResult> compareCampaignMonths(
    String campaignId,
    String month1,
    String month2,
  ) async {
    try {
      // Fetch month-specific data using pre-aggregated totals
      final campaigns1 = await _campaignService.getCampaignsWithMonthTotals(
        month: month1,
        limit: 100,
      );
      final campaigns2 = await _campaignService.getCampaignsWithMonthTotals(
        month: month2,
        limit: 100,
      );

      // Find the specific campaign in both results
      final campaign1 = campaigns1.firstWhere(
        (c) => c.campaignId == campaignId,
        orElse: () => throw Exception('Campaign not found in $month1'),
      );
      final campaign2 = campaigns2.firstWhere(
        (c) => c.campaignId == campaignId,
        orElse: () => throw Exception('Campaign not found in $month2'),
      );

      return ComparisonResult.fromCampaigns(
        campaign1: campaign2, // Earlier period
        campaign2: campaign1, // Later period
        dateRange1: month2,
        dateRange2: month1,
        comparisonType: ComparisonType.TIME_PERIOD,
      );
    } catch (e) {
      print('Error comparing campaign months: $e');
      rethrow;
    }
  }

  /// Compare a campaign across two custom date ranges
  Future<ComparisonResult> compareCampaignDateRanges(
    String campaignId,
    DateTime startDate1,
    DateTime endDate1,
    DateTime startDate2,
    DateTime endDate2,
  ) async {
    try {
      // Calculate totals for each date range
      final totals1 = await _campaignService
          .calculateCampaignTotalsForDateRange(
            campaignId: campaignId,
            startDate: startDate1,
            endDate: endDate1,
          );

      final totals2 = await _campaignService
          .calculateCampaignTotalsForDateRange(
            campaignId: campaignId,
            startDate: startDate2,
            endDate: endDate2,
          );

      // Get campaign name
      final campaign = await _campaignService.getCampaign(campaignId);
      final campaignName = campaign?.campaignName ?? 'Unknown Campaign';

      return ComparisonResult.fromMetricsMap(
        entityId1: campaignId,
        entityName1: campaignName,
        dateRange1: '${_formatDate(startDate1)} - ${_formatDate(endDate1)}',
        metrics1: totals1,
        entityId2: campaignId,
        entityName2: campaignName,
        dateRange2: '${_formatDate(startDate2)} - ${_formatDate(endDate2)}',
        metrics2: totals2,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.CAMPAIGN,
      );
    } catch (e) {
      print('Error comparing campaign date ranges: $e');
      rethrow;
    }
  }

  /// Compare two different campaigns in the same month
  Future<ComparisonResult> compareCampaigns(
    String campaignId1,
    String campaignId2,
    String month,
  ) async {
    try {
      // Fetch month-specific data for both campaigns
      final campaigns = await _campaignService.getCampaignsWithMonthTotals(
        month: month,
        limit: 100,
      );

      final campaign1 = campaigns.firstWhere(
        (c) => c.campaignId == campaignId1,
        orElse: () => throw Exception('Campaign 1 not found in $month'),
      );
      final campaign2 = campaigns.firstWhere(
        (c) => c.campaignId == campaignId2,
        orElse: () => throw Exception('Campaign 2 not found in $month'),
      );

      return ComparisonResult.fromCampaigns(
        campaign1: campaign1,
        campaign2: campaign2,
        dateRange1: month,
        dateRange2: month,
        comparisonType: ComparisonType.ENTITY_VS_ENTITY,
      );
    } catch (e) {
      print('Error comparing campaigns: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AD SET COMPARISONS
  // ============================================================================

  /// Compare an ad set across two months using pre-aggregated monthlyTotals (FAST)
  Future<ComparisonResult> compareAdSetMonths(
    String campaignId,
    String adSetId,
    String month1,
    String month2,
  ) async {
    try {
      // Fetch month-specific data for both months
      final adSets1 = await _adSetService.getAdSetsWithMonthTotals(
        campaignId: campaignId,
        month: month1,
      );
      final adSets2 = await _adSetService.getAdSetsWithMonthTotals(
        campaignId: campaignId,
        month: month2,
      );

      // Find the specific ad set in both results
      final adSet1 = adSets1.firstWhere(
        (a) => a.adSetId == adSetId,
        orElse: () => throw Exception('Ad Set not found in $month1'),
      );
      final adSet2 = adSets2.firstWhere(
        (a) => a.adSetId == adSetId,
        orElse: () => throw Exception('Ad Set not found in $month2'),
      );

      return ComparisonResult.fromAdSets(
        adSet1: adSet2, // Earlier period
        adSet2: adSet1, // Later period
        dateRange1: month2,
        dateRange2: month1,
        comparisonType: ComparisonType.TIME_PERIOD,
      );
    } catch (e) {
      print('Error comparing ad set months: $e');
      rethrow;
    }
  }

  /// Compare an ad set across two custom date ranges
  Future<ComparisonResult> compareAdSetDateRanges(
    String adSetId,
    DateTime startDate1,
    DateTime endDate1,
    DateTime startDate2,
    DateTime endDate2,
  ) async {
    try {
      // Calculate totals for each date range
      final totals1 = await _adSetService.calculateAdSetTotalsForDateRange(
        adSetId: adSetId,
        startDate: startDate1,
        endDate: endDate1,
      );

      final totals2 = await _adSetService.calculateAdSetTotalsForDateRange(
        adSetId: adSetId,
        startDate: startDate2,
        endDate: endDate2,
      );

      // Get ad set name
      final adSet = await _adSetService.getAdSet(adSetId);
      final adSetName = adSet?.adSetName ?? 'Unknown Ad Set';

      return ComparisonResult.fromMetricsMap(
        entityId1: adSetId,
        entityName1: adSetName,
        dateRange1: '${_formatDate(startDate1)} - ${_formatDate(endDate1)}',
        metrics1: totals1,
        entityId2: adSetId,
        entityName2: adSetName,
        dateRange2: '${_formatDate(startDate2)} - ${_formatDate(endDate2)}',
        metrics2: totals2,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.AD_SET,
      );
    } catch (e) {
      print('Error comparing ad set date ranges: $e');
      rethrow;
    }
  }

  /// Compare two different ad sets in the same month
  Future<ComparisonResult> compareAdSets(
    String campaignId,
    String adSetId1,
    String adSetId2,
    String month,
  ) async {
    try {
      // Fetch month-specific data for both ad sets
      final adSets = await _adSetService.getAdSetsWithMonthTotals(
        campaignId: campaignId,
        month: month,
      );

      final adSet1 = adSets.firstWhere(
        (a) => a.adSetId == adSetId1,
        orElse: () => throw Exception('Ad Set 1 not found in $month'),
      );
      final adSet2 = adSets.firstWhere(
        (a) => a.adSetId == adSetId2,
        orElse: () => throw Exception('Ad Set 2 not found in $month'),
      );

      return ComparisonResult.fromAdSets(
        adSet1: adSet1,
        adSet2: adSet2,
        dateRange1: month,
        dateRange2: month,
        comparisonType: ComparisonType.ENTITY_VS_ENTITY,
      );
    } catch (e) {
      print('Error comparing ad sets: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AD COMPARISONS (Uses Weekly Insights)
  // ============================================================================

  /// Compare two ads across a date range using weekly insights
  Future<ComparisonResult> compareAds(
    String adId1,
    String adId2,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Fetch weekly insights for the date range
      final weeklyDataMap =
          await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
            startDate: startDate,
            endDate: endDate,
          );

      // Get insights for each ad
      final ad1Insights = weeklyDataMap[adId1] ?? [];
      final ad2Insights = weeklyDataMap[adId2] ?? [];

      if (ad1Insights.isEmpty && ad2Insights.isEmpty) {
        throw Exception(
          'No weekly insights found for either ad in the specified date range',
        );
      }

      // Aggregate metrics for each ad
      final metrics1 = _aggregateWeeklyInsights(ad1Insights);
      final metrics2 = _aggregateWeeklyInsights(ad2Insights);

      // Get ad names
      final ad1Name = ad1Insights.isNotEmpty
          ? 'Ad ${adId1.substring(0, 8)}'
          : 'Unknown Ad';
      final ad2Name = ad2Insights.isNotEmpty
          ? 'Ad ${adId2.substring(0, 8)}'
          : 'Unknown Ad';

      final dateRange = '${_formatDate(startDate)} - ${_formatDate(endDate)}';

      return ComparisonResult.fromMetricsMap(
        entityId1: adId1,
        entityName1: ad1Name,
        dateRange1: dateRange,
        metrics1: metrics1,
        entityId2: adId2,
        entityName2: ad2Name,
        dateRange2: dateRange,
        metrics2: metrics2,
        comparisonType: ComparisonType.ENTITY_VS_ENTITY,
        entityLevel: EntityLevel.ADVERT,
      );
    } catch (e) {
      print('Error comparing ads: $e');
      rethrow;
    }
  }

  /// Compare an ad across two different date ranges
  Future<ComparisonResult> compareAdDateRanges(
    String adId,
    DateTime startDate1,
    DateTime endDate1,
    DateTime startDate2,
    DateTime endDate2,
  ) async {
    try {
      // Fetch insights for first date range
      final weeklyDataMap1 =
          await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
            startDate: startDate1,
            endDate: endDate1,
          );
      final insights1 = weeklyDataMap1[adId] ?? [];

      // Fetch insights for second date range
      final weeklyDataMap2 =
          await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
            startDate: startDate2,
            endDate: endDate2,
          );
      final insights2 = weeklyDataMap2[adId] ?? [];

      if (insights1.isEmpty && insights2.isEmpty) {
        throw Exception(
          'No weekly insights found for this ad in either date range',
        );
      }

      // Aggregate metrics for each period
      final metrics1 = _aggregateWeeklyInsights(insights1);
      final metrics2 = _aggregateWeeklyInsights(insights2);

      final adName = insights1.isNotEmpty || insights2.isNotEmpty
          ? 'Ad ${adId.substring(0, 8)}'
          : 'Unknown Ad';

      return ComparisonResult.fromMetricsMap(
        entityId1: adId,
        entityName1: adName,
        dateRange1: '${_formatDate(startDate1)} - ${_formatDate(endDate1)}',
        metrics1: metrics1,
        entityId2: adId,
        entityName2: adName,
        dateRange2: '${_formatDate(startDate2)} - ${_formatDate(endDate2)}',
        metrics2: metrics2,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.ADVERT,
      );
    } catch (e) {
      print('Error comparing ad date ranges: $e');
      rethrow;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Aggregate weekly insights into a metrics map
  Map<String, dynamic> _aggregateWeeklyInsights(
    List<FacebookWeeklyInsight> insights,
  ) {
    if (insights.isEmpty) {
      return {
        'totalSpend': 0.0,
        'totalImpressions': 0,
        'totalClicks': 0,
        'totalReach': 0,
        'totalLeads': 0,
        'totalBookings': 0,
        'totalDeposits': 0,
        'totalCashAmount': 0.0,
        'totalProfit': 0.0,
        'cpl': 0.0,
        'cpb': 0.0,
        'cpa': 0.0,
        'roi': 0.0,
        'cpm': 0.0,
        'cpc': 0.0,
        'ctr': 0.0,
      };
    }

    double totalSpend = 0;
    int totalImpressions = 0;
    int totalClicks = 0;
    int totalReach = 0;

    for (final insight in insights) {
      totalSpend += insight.spend;
      totalImpressions += insight.impressions;
      totalClicks += insight.clicks;
      totalReach += insight.reach;
    }

    // Calculate derived metrics
    final cpm = totalImpressions > 0
        ? (totalSpend / totalImpressions) * 1000
        : 0.0;
    final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0.0;
    final ctr = totalImpressions > 0
        ? (totalClicks / totalImpressions) * 100
        : 0.0;

    return {
      'totalSpend': totalSpend,
      'totalImpressions': totalImpressions,
      'totalClicks': totalClicks,
      'totalReach': totalReach,
      'totalLeads': 0, // GHL data not available in weekly insights
      'totalBookings': 0,
      'totalDeposits': 0,
      'totalCashAmount': 0.0,
      'totalProfit': -totalSpend, // Negative since we don't have revenue
      'cpl': 0.0,
      'cpb': 0.0,
      'cpa': 0.0,
      'roi': 0.0,
      'cpm': cpm,
      'cpc': cpc,
      'ctr': ctr,
    };
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // AUTOMATIC ANALYSIS COMPARISONS
  // ============================================================================

  /// Get overall aggregated comparison for all campaigns
  Future<ComparisonResult> getOverallComparison(TimePeriod timePeriod) async {
    try {
      // Get all campaign comparisons
      final campaignComparisons = await getAllCampaignsComparison(timePeriod);

      if (campaignComparisons.isEmpty) {
        throw Exception('No campaigns found for the selected period');
      }

      // Aggregate all metrics
      double currentSpend = 0, previousSpend = 0;
      int currentImpressions = 0, previousImpressions = 0;
      int currentClicks = 0, previousClicks = 0;
      int currentLeads = 0, previousLeads = 0;
      int currentBookings = 0, previousBookings = 0;
      int currentDeposits = 0, previousDeposits = 0;
      double currentCash = 0, previousCash = 0;
      double currentProfit = 0, previousProfit = 0;

      for (final campaign in campaignComparisons) {
        currentSpend += campaign.comparison.dataset2.getMetric('totalSpend');
        previousSpend += campaign.comparison.dataset1.getMetric('totalSpend');
        currentImpressions += campaign.comparison.dataset2.getIntMetric(
          'totalImpressions',
        );
        previousImpressions += campaign.comparison.dataset1.getIntMetric(
          'totalImpressions',
        );
        currentClicks += campaign.comparison.dataset2.getIntMetric(
          'totalClicks',
        );
        previousClicks += campaign.comparison.dataset1.getIntMetric(
          'totalClicks',
        );
        currentLeads += campaign.comparison.dataset2.getIntMetric('totalLeads');
        previousLeads += campaign.comparison.dataset1.getIntMetric(
          'totalLeads',
        );
        currentBookings += campaign.comparison.dataset2.getIntMetric(
          'totalBookings',
        );
        previousBookings += campaign.comparison.dataset1.getIntMetric(
          'totalBookings',
        );
        currentDeposits += campaign.comparison.dataset2.getIntMetric(
          'totalDeposits',
        );
        previousDeposits += campaign.comparison.dataset1.getIntMetric(
          'totalDeposits',
        );
        currentCash += campaign.comparison.dataset2.getMetric(
          'totalCashAmount',
        );
        previousCash += campaign.comparison.dataset1.getMetric(
          'totalCashAmount',
        );
        currentProfit += campaign.comparison.dataset2.getMetric('totalProfit');
        previousProfit += campaign.comparison.dataset1.getMetric('totalProfit');
      }

      // Calculate derived metrics
      final currentCPL = currentLeads > 0 ? currentSpend / currentLeads : 0.0;
      final previousCPL = previousLeads > 0
          ? previousSpend / previousLeads
          : 0.0;
      final currentCPB = currentBookings > 0
          ? currentSpend / currentBookings
          : 0.0;
      final previousCPB = previousBookings > 0
          ? previousSpend / previousBookings
          : 0.0;
      final currentROI = currentSpend > 0
          ? (currentProfit / currentSpend) * 100
          : 0.0;
      final previousROI = previousSpend > 0
          ? (previousProfit / previousSpend) * 100
          : 0.0;

      final dateRanges = TimePeriodCalculator.calculateDateRanges(timePeriod);
      final currentRange = TimePeriodCalculator.formatDateRange(
        dateRanges['currentStart']!,
        dateRanges['currentEnd']!,
      );
      final previousRange = TimePeriodCalculator.formatDateRange(
        dateRanges['previousStart']!,
        dateRanges['previousEnd']!,
      );

      return ComparisonResult.fromMetricsMap(
        entityId1: 'overall',
        entityName1: 'Overall Performance',
        dateRange1: previousRange,
        metrics1: {
          'totalSpend': previousSpend,
          'totalImpressions': previousImpressions,
          'totalClicks': previousClicks,
          'totalLeads': previousLeads,
          'totalBookings': previousBookings,
          'totalDeposits': previousDeposits,
          'totalCashAmount': previousCash,
          'totalProfit': previousProfit,
          'cpl': previousCPL,
          'cpb': previousCPB,
          'roi': previousROI,
        },
        entityId2: 'overall',
        entityName2: 'Overall Performance',
        dateRange2: currentRange,
        metrics2: {
          'totalSpend': currentSpend,
          'totalImpressions': currentImpressions,
          'totalClicks': currentClicks,
          'totalLeads': currentLeads,
          'totalBookings': currentBookings,
          'totalDeposits': currentDeposits,
          'totalCashAmount': currentCash,
          'totalProfit': currentProfit,
          'cpl': currentCPL,
          'cpb': currentCPB,
          'roi': currentROI,
        },
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.CAMPAIGN,
      );
    } catch (e) {
      print('Error getting overall comparison: $e');
      rethrow;
    }
  }

  /// Get all campaigns with comparisons for a time period
  Future<List<CampaignComparison>> getAllCampaignsComparison(
    TimePeriod timePeriod, {
    String countryFilter = 'all',
    DateTime? selectedMonth,
  }) async {
    try {
      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAllCampaignsMonthComparison(
          countryFilter: countryFilter,
          selectedMonth: selectedMonth,
        );
      } else {
        return await _getAllCampaignsDateRangeComparison(
          timePeriod,
          countryFilter: countryFilter,
        );
      }
    } catch (e) {
      print('Error getting all campaigns comparison: $e');
      rethrow;
    }
  }

  /// Get campaigns comparison using summary collection (optimized with parallel processing)
  /// Uses same campaign filtering as campaign screen (getCampaignsWithDateFilteredTotals)
  Future<List<CampaignComparison>> _getAllCampaignsMonthComparison({
    String countryFilter = 'all',
    DateTime? selectedMonth,
  }) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(
      TimePeriod.THIS_MONTH,
      selectedMonth: selectedMonth,
    );
    final currentStart = dateRanges['currentStart']!;
    final currentEnd = dateRanges['currentEnd']!;
    final previousStart = dateRanges['previousStart']!;
    final previousEnd = dateRanges['previousEnd']!;

    if (kDebugMode) {
      print('📊 Fetching campaigns for THIS_MONTH comparison');
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get campaigns that ran in the current month (same filtering as campaign screen)
    final campaigns = await _campaignService.getCampaignsWithDateFilteredTotals(
      startDate: currentStart,
      endDate: currentEnd,
      limit: 200, // Fetch enough to account for filtering
      countryFilter: countryFilter,
    );

    if (kDebugMode) {
      print(
        '📊 Found ${campaigns.length} campaigns that ran in current period (from campaigns collection)',
      );
    }

    // Process all campaigns in parallel
    final comparisonFutures = campaigns.map((campaign) async {
      final campaignId = campaign.campaignId;
      final campaignName = campaign.campaignName;

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateCampaignTotalsFromSummaryForComparison(
              campaignId: campaignId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateCampaignTotalsFromSummaryForComparison(
              campaignId: campaignId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: campaignId,
          entityName1: campaignName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: campaignId,
          entityName2: campaignName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.CAMPAIGN,
        );

        return CampaignComparison(
          campaignId: campaignId,
          campaignName: campaignName,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for campaign $campaignId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final comparisons = comparisonResults
        .whereType<CampaignComparison>()
        .toList();

    // Sort by current spend descending
    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${comparisons.length} campaign comparisons');
    }

    return comparisons;
  }

  /// Get campaigns comparison using summary collection for date ranges (THIS_WEEK) - optimized
  /// Uses same campaign filtering as campaign screen (getCampaignsWithDateFilteredTotals)
  Future<List<CampaignComparison>> _getAllCampaignsDateRangeComparison(
    TimePeriod timePeriod, {
    String countryFilter = 'all',
  }) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(timePeriod);
    final currentStart = dateRanges['currentStart']!;
    final currentEnd = dateRanges['currentEnd']!;
    final previousStart = dateRanges['previousStart']!;
    final previousEnd = dateRanges['previousEnd']!;

    if (kDebugMode) {
      print('📊 Fetching campaigns for $timePeriod comparison');
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get campaigns that ran in the current period (same filtering as campaign screen)
    final campaigns = await _campaignService.getCampaignsWithDateFilteredTotals(
      startDate: currentStart,
      endDate: currentEnd,
      limit: 200, // Fetch enough to account for filtering
      countryFilter: countryFilter,
    );

    if (kDebugMode) {
      print(
        '📊 Found ${campaigns.length} campaigns that ran in current period (from campaigns collection)',
      );
    }

    // Process all campaigns in parallel
    final comparisonFutures = campaigns.map((campaign) async {
      final campaignId = campaign.campaignId;
      final campaignName = campaign.campaignName;

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateCampaignTotalsFromSummaryForComparison(
              campaignId: campaignId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateCampaignTotalsFromSummaryForComparison(
              campaignId: campaignId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: campaignId,
          entityName1: campaignName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: campaignId,
          entityName2: campaignName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.CAMPAIGN,
        );

        return CampaignComparison(
          campaignId: campaignId,
          campaignName: campaignName,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for campaign $campaignId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final comparisons = comparisonResults
        .whereType<CampaignComparison>()
        .toList();

    // Sort by current spend descending
    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${comparisons.length} campaign comparisons');
    }

    return comparisons;
  }

  /// Get ad sets for a campaign with comparisons
  Future<List<AdSetComparison>> getCampaignAdSetsComparison(
    String campaignId,
    TimePeriod timePeriod, {
    DateTime? selectedMonth,
  }) async {
    try {
      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAdSetsMonthComparison(
          campaignId,
          selectedMonth: selectedMonth,
        );
      } else {
        return await _getAdSetsDateRangeComparison(campaignId, timePeriod);
      }
    } catch (e) {
      print('Error getting ad sets comparison: $e');
      rethrow;
    }
  }

  /// Get ad sets comparison using summary collection
  /// Uses same pattern as campaign screen: fetch all ad sets first, then calculate metrics
  Future<List<AdSetComparison>> _getAdSetsMonthComparison(
    String campaignId, {
    DateTime? selectedMonth,
  }) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(
      TimePeriod.THIS_MONTH,
      selectedMonth: selectedMonth,
    );
    final currentStart = dateRanges['currentStart']!;
    final currentEnd = dateRanges['currentEnd']!;
    final previousStart = dateRanges['previousStart']!;
    final previousEnd = dateRanges['previousEnd']!;

    if (kDebugMode) {
      print(
        '📊 Fetching ad sets for comparison (THIS_MONTH) for campaign $campaignId',
      );
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get all ad sets for this campaign (same pattern as campaign screen)
    final adSets = await _adSetService.getAdSetsForCampaign(campaignId);

    if (kDebugMode) {
      print(
        '📊 Found ${adSets.length} ad sets in campaign (from adSets collection)',
      );
    }

    // Process all ad sets in parallel
    final comparisonFutures = adSets.map((adSet) async {
      final adSetId = adSet.adSetId;

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateAdSetTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adSetId: adSetId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateAdSetTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adSetId: adSetId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        // Check if ad set has activity in current period (adsInRange > 0)
        final currentAdsInRange = currentMetrics['adsInRange'] as int? ?? 0;
        if (currentAdsInRange == 0) {
          if (kDebugMode) {
            print(
              '   ⏭️ Skipping ad set $adSetId (no activity in current period)',
            );
          }
          return null;
        }

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: adSetId,
          entityName1: adSet.adSetName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: adSetId,
          entityName2: adSet.adSetName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.AD_SET,
        );

        return AdSetComparison(
          adSetId: adSetId,
          adSetName: adSet.adSetName,
          campaignId: campaignId,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for ad set $adSetId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final validComparisons = comparisonResults
        .whereType<AdSetComparison>()
        .toList();

    validComparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${validComparisons.length} ad set comparisons');
    }

    return validComparisons;
  }

  /// Get ad sets comparison using summary collection for date ranges (THIS_WEEK)
  /// Uses same pattern as campaign screen: fetch all ad sets first, then calculate metrics
  Future<List<AdSetComparison>> _getAdSetsDateRangeComparison(
    String campaignId,
    TimePeriod timePeriod,
  ) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(timePeriod);
    final currentStart = dateRanges['currentStart']!;
    final currentEnd = dateRanges['currentEnd']!;
    final previousStart = dateRanges['previousStart']!;
    final previousEnd = dateRanges['previousEnd']!;

    if (kDebugMode) {
      print(
        '📊 Fetching ad sets for comparison ($timePeriod) for campaign $campaignId',
      );
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get all ad sets for this campaign (same pattern as campaign screen)
    final adSets = await _adSetService.getAdSetsForCampaign(campaignId);

    if (kDebugMode) {
      print(
        '📊 Found ${adSets.length} ad sets in campaign (from adSets collection)',
      );
    }

    // Process all ad sets in parallel
    final comparisonFutures = adSets.map((adSet) async {
      final adSetId = adSet.adSetId;

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateAdSetTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adSetId: adSetId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateAdSetTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adSetId: adSetId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        // Check if ad set has activity in current period (adsInRange > 0)
        final currentAdsInRange = currentMetrics['adsInRange'] as int? ?? 0;
        if (currentAdsInRange == 0) {
          if (kDebugMode) {
            print(
              '   ⏭️ Skipping ad set $adSetId (no activity in current period)',
            );
          }
          return null;
        }

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: adSetId,
          entityName1: adSet.adSetName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: adSetId,
          entityName2: adSet.adSetName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.AD_SET,
        );

        return AdSetComparison(
          adSetId: adSetId,
          adSetName: adSet.adSetName,
          campaignId: campaignId,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for ad set $adSetId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final validComparisons = comparisonResults
        .whereType<AdSetComparison>()
        .toList();

    validComparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${validComparisons.length} ad set comparisons');
    }

    return validComparisons;
  }

  // ============================================================================
  // SINGLE ENTITY COMPARISON METHODS (for drill-down UI)
  // ============================================================================

  /// Get comparison for a single campaign
  /// Returns the campaign's performance comparison for the selected time period
  Future<CampaignComparison?> getCampaignComparison(
    String campaignId,
    TimePeriod timePeriod, {
    String countryFilter = 'all',
    DateTime? selectedMonth,
  }) async {
    try {
      print('📊 Fetching comparison for campaign: $campaignId');

      // Get all campaigns comparison and find the one we need
      final allComparisons = await getAllCampaignsComparison(
        timePeriod,
        countryFilter: countryFilter,
        selectedMonth: selectedMonth,
      );

      final comparison = allComparisons.firstWhere(
        (c) => c.campaignId == campaignId,
        orElse: () => throw Exception('Campaign $campaignId not found'),
      );

      print('✅ Found comparison for campaign: ${comparison.campaignName}');
      return comparison;
    } catch (e) {
      print('❌ Error getting campaign comparison: $e');
      rethrow;
    }
  }

  /// Get comparison for a single ad set
  /// Returns the ad set's performance comparison for the selected time period
  Future<AdSetComparison?> getAdSetComparison(
    String adSetId,
    TimePeriod timePeriod, {
    DateTime? selectedMonth,
  }) async {
    try {
      print('📊 Fetching comparison for ad set: $adSetId');

      // First, find which campaign this ad set belongs to
      final adSetDoc = await _firestore.collection('adSets').doc(adSetId).get();
      if (!adSetDoc.exists) {
        throw Exception('Ad set $adSetId not found');
      }

      final campaignId = adSetDoc.data()?['campaignId'] as String?;
      if (campaignId == null) {
        throw Exception('Ad set $adSetId has no campaign ID');
      }

      // Get all ad sets for this campaign
      final allAdSets = await getCampaignAdSetsComparison(
        campaignId,
        timePeriod,
        selectedMonth: selectedMonth,
      );

      final comparison = allAdSets.firstWhere(
        (a) => a.adSetId == adSetId,
        orElse: () =>
            throw Exception('Ad set $adSetId not found in comparisons'),
      );

      print('✅ Found comparison for ad set: ${comparison.adSetName}');
      return comparison;
    } catch (e) {
      print('❌ Error getting ad set comparison: $e');
      rethrow;
    }
  }

  /// Get comparisons for all ads within an ad set
  /// Returns a list of ad comparisons for the selected time period
  Future<List<AdComparison>> getAdSetAdsComparison(
    String adSetId,
    TimePeriod timePeriod, {
    DateTime? selectedMonth,
  }) async {
    try {
      if (kDebugMode) {
        print('📊 Fetching ads comparison for ad set: $adSetId');
      }

      // Get the ad set to find the campaign ID
      final adSet = await _adSetService.getAdSet(adSetId);
      if (adSet == null) {
        throw Exception('Ad set $adSetId not found');
      }

      final campaignId = adSet.campaignId;
      if (campaignId.isEmpty) {
        throw Exception('Ad set $adSetId has no campaign ID');
      }

      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAdsMonthComparison(
          campaignId,
          adSetId,
          selectedMonth: selectedMonth,
        );
      } else {
        return await _getAdsDateRangeComparison(
          campaignId,
          adSetId,
          timePeriod,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting ads comparison: $e');
      }
      rethrow;
    }
  }

  /// Get comparison for a single ad
  /// Returns the ad's performance comparison for the selected time period
  Future<AdComparison?> getAdComparison(
    String adId,
    TimePeriod timePeriod, {
    DateTime? selectedMonth,
  }) async {
    try {
      print('📊 Fetching comparison for ad: $adId');

      // First, find which ad set this ad belongs to
      final adDoc = await _firestore.collection('ads').doc(adId).get();
      if (!adDoc.exists) {
        throw Exception('Ad $adId not found');
      }

      final data = adDoc.data();
      final adSetId = data?['adSetId'] as String?;
      if (adSetId == null) {
        throw Exception('Ad $adId has no ad set ID');
      }

      // Get all ads for this ad set
      final allAds = await getAdSetAdsComparison(
        adSetId,
        timePeriod,
        selectedMonth: selectedMonth,
      );

      final comparison = allAds.firstWhere(
        (a) => a.adId == adId,
        orElse: () => throw Exception('Ad $adId not found in comparisons'),
      );

      print('✅ Found comparison for ad: ${comparison.adName}');
      return comparison;
    } catch (e) {
      print('❌ Error getting ad comparison: $e');
      rethrow;
    }
  }

  /// Get ads comparison using summary collection for THIS_MONTH
  /// Uses same pattern as campaign screen: fetch all ads first, then calculate metrics
  Future<List<AdComparison>> _getAdsMonthComparison(
    String campaignId,
    String adSetId, {
    DateTime? selectedMonth,
  }) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(
      TimePeriod.THIS_MONTH,
      selectedMonth: selectedMonth,
    );
    final currentStart = dateRanges['currentStart']!;
    final currentEnd = dateRanges['currentEnd']!;
    final previousStart = dateRanges['previousStart']!;
    final previousEnd = dateRanges['previousEnd']!;

    if (kDebugMode) {
      print('📊 Fetching ads for comparison (THIS_MONTH) for ad set $adSetId');
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get all ads for this ad set (same pattern as campaign screen)
    final snapshot = await _firestore
        .collection('ads')
        .where('adSetId', isEqualTo: adSetId)
        .get();

    if (kDebugMode) {
      print(
        '📊 Found ${snapshot.docs.length} ads in ad set (from ads collection)',
      );
    }

    // Process all ads in parallel
    final comparisonFutures = snapshot.docs.map((doc) async {
      final adData = doc.data();
      final adId = doc.id;
      final adName = adData['adName'] as String? ?? 'Unknown Ad';

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateAdTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adId: adId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateAdTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adId: adId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        // Check if ad has activity in current period (adsInRange > 0)
        final currentAdsInRange = currentMetrics['adsInRange'] as int? ?? 0;
        if (currentAdsInRange == 0) {
          if (kDebugMode) {
            print('   ⏭️ Skipping ad $adId (no activity in current period)');
          }
          return null;
        }

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: adId,
          entityName1: adName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: adId,
          entityName2: adName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.ADVERT,
        );

        return AdComparison(
          adId: adId,
          adName: adName,
          adSetId: adSetId,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for ad $adId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final validComparisons = comparisonResults
        .whereType<AdComparison>()
        .toList();

    validComparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${validComparisons.length} ad comparisons');
    }

    return validComparisons;
  }

  /// Get ads comparison using summary collection for date range (THIS_WEEK)
  /// Uses same pattern as campaign screen: fetch all ads first, then calculate metrics
  Future<List<AdComparison>> _getAdsDateRangeComparison(
    String campaignId,
    String adSetId,
    TimePeriod timePeriod,
  ) async {
    final ranges = TimePeriodCalculator.calculateDateRanges(timePeriod);
    final currentStart = ranges['currentStart']!;
    final currentEnd = ranges['currentEnd']!;
    final previousStart = ranges['previousStart']!;
    final previousEnd = ranges['previousEnd']!;

    if (kDebugMode) {
      print('📊 Fetching ads for comparison ($timePeriod) for ad set $adSetId');
      print(
        '   Current: ${_formatDate(currentStart)} to ${_formatDate(currentEnd)}',
      );
      print(
        '   Previous: ${_formatDate(previousStart)} to ${_formatDate(previousEnd)}',
      );
    }

    // Get all ads for this ad set (same pattern as campaign screen)
    final snapshot = await _firestore
        .collection('ads')
        .where('adSetId', isEqualTo: adSetId)
        .get();

    if (kDebugMode) {
      print(
        '📊 Found ${snapshot.docs.length} ads in ad set (from ads collection)',
      );
    }

    // Process all ads in parallel
    final comparisonFutures = snapshot.docs.map((doc) async {
      final adData = doc.data();
      final adId = doc.id;
      final adName = adData['adName'] as String? ?? 'Unknown Ad';

      try {
        // Get both period metrics in parallel using summary collection
        final currentMetricsFuture = _summaryService
            .calculateAdTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adId: adId,
              startDate: currentStart,
              endDate: currentEnd,
            );

        final previousMetricsFuture = _summaryService
            .calculateAdTotalsFromSummaryForComparison(
              campaignId: campaignId,
              adId: adId,
              startDate: previousStart,
              endDate: previousEnd,
            );

        // Wait for both metrics in parallel
        final results = await Future.wait([
          currentMetricsFuture,
          previousMetricsFuture,
        ]);

        final currentMetrics = results[0];
        final previousMetrics = results[1];

        // Check if ad has activity in current period (adsInRange > 0)
        final currentAdsInRange = currentMetrics['adsInRange'] as int? ?? 0;
        if (currentAdsInRange == 0) {
          if (kDebugMode) {
            print('   ⏭️ Skipping ad $adId (no activity in current period)');
          }
          return null;
        }

        final currentRange = TimePeriodCalculator.formatDateRange(
          currentStart,
          currentEnd,
        );
        final previousRange = TimePeriodCalculator.formatDateRange(
          previousStart,
          previousEnd,
        );

        final comparison = ComparisonResult.fromMetricsMap(
          entityId1: adId,
          entityName1: adName,
          dateRange1: previousRange,
          metrics1: previousMetrics,
          entityId2: adId,
          entityName2: adName,
          dateRange2: currentRange,
          metrics2: currentMetrics,
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.ADVERT,
        );

        return AdComparison(
          adId: adId,
          adName: adName,
          adSetId: adSetId,
          comparison: comparison,
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error getting comparison for ad $adId: $e');
        }
        return null;
      }
    }).toList();

    // Wait for all comparisons to complete
    final comparisonResults = await Future.wait(comparisonFutures);
    final validComparisons = comparisonResults
        .whereType<AdComparison>()
        .toList();

    validComparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    if (kDebugMode) {
      print('✅ Returning ${validComparisons.length} ad comparisons');
    }

    return validComparisons;
  }
}
