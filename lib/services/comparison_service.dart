import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comparison/comparison_models.dart';
import '../models/comparison/comparison_list_models.dart';
import '../models/facebook/facebook_ad_data.dart';
import 'firebase/campaign_service.dart';
import 'firebase/ad_set_service.dart';
import 'firebase/weekly_insights_service.dart';

/// Service for comparing campaigns, ad sets, and ads across time periods or against each other
class ComparisonService {
  final CampaignService _campaignService = CampaignService();
  final AdSetService _adSetService = AdSetService();
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
    TimePeriod timePeriod,
  ) async {
    try {
      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAllCampaignsMonthComparison();
      } else {
        return await _getAllCampaignsDateRangeComparison(timePeriod);
      }
    } catch (e) {
      print('Error getting all campaigns comparison: $e');
      rethrow;
    }
  }

  /// Get campaigns comparison using monthlyTotals (fast for THIS_MONTH)
  Future<List<CampaignComparison>> _getAllCampaignsMonthComparison() async {
    final months = TimePeriodCalculator.getMonthStrings();
    final currentMonth = months['current']!;
    final previousMonth = months['previous']!;

    print(
      '📊 Fetching campaigns with monthlyTotals for: $currentMonth and $previousMonth',
    );

    // Fetch both months
    final currentCampaigns = await _campaignService.getCampaignsWithMonthTotals(
      month: currentMonth,
      limit: 100,
    );
    final previousCampaigns = await _campaignService
        .getCampaignsWithMonthTotals(month: previousMonth, limit: 100);

    print(
      '📊 Found ${currentCampaigns.length} campaigns for $currentMonth, ${previousCampaigns.length} for $previousMonth',
    );

    // FALLBACK: If no campaigns have monthlyTotals, use date range aggregation instead
    if (currentCampaigns.isEmpty) {
      print(
        '⚠️ No campaigns with monthlyTotals found, falling back to date range aggregation',
      );
      return await _getAllCampaignsThisMonthFallback();
    }

    // Create map of previous campaigns for easy lookup
    final previousMap = {for (var c in previousCampaigns) c.campaignId: c};

    final comparisons = <CampaignComparison>[];

    // Only include campaigns that have data in current period
    for (final currentCampaign in currentCampaigns) {
      final previousCampaign = previousMap[currentCampaign.campaignId];

      ComparisonResult comparison;
      if (previousCampaign != null) {
        comparison = ComparisonResult.fromCampaigns(
          campaign1: previousCampaign,
          campaign2: currentCampaign,
          dateRange1: previousMonth,
          dateRange2: currentMonth,
          comparisonType: ComparisonType.TIME_PERIOD,
        );
      } else {
        // Campaign only has current period data
        comparison = ComparisonResult.fromMetricsMap(
          entityId1: currentCampaign.campaignId,
          entityName1: currentCampaign.campaignName,
          dateRange1: previousMonth,
          metrics1: _createZeroMetrics(),
          entityId2: currentCampaign.campaignId,
          entityName2: currentCampaign.campaignName,
          dateRange2: currentMonth,
          metrics2: {
            'totalSpend': currentCampaign.totalSpend,
            'totalImpressions': currentCampaign.totalImpressions,
            'totalClicks': currentCampaign.totalClicks,
            'totalLeads': currentCampaign.totalLeads,
            'totalBookings': currentCampaign.totalBookings,
            'totalDeposits': currentCampaign.totalDeposits,
            'totalCashAmount': currentCampaign.totalCashAmount,
            'totalProfit': currentCampaign.totalProfit,
            'cpl': currentCampaign.cpl,
            'cpb': currentCampaign.cpb,
            'roi': currentCampaign.roi,
          },
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.CAMPAIGN,
        );
      }

      comparisons.add(
        CampaignComparison(
          campaignId: currentCampaign.campaignId,
          campaignName: currentCampaign.campaignName,
          comparison: comparison,
        ),
      );
    }

    // Sort by current spend descending
    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    return comparisons;
  }

  /// Fallback method for THIS_MONTH when monthlyTotals is not available
  /// Uses date range aggregation like LAST_7_DAYS/LAST_30_DAYS
  Future<List<CampaignComparison>> _getAllCampaignsThisMonthFallback() async {
    print('📊 Using date range fallback for THIS_MONTH');

    // Calculate this month vs last month date ranges
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthStart = DateTime(lastMonthDate.year, lastMonthDate.month, 1);
    // Use the same day of month in the previous month for fair comparison
    final lastMonthDay = now.day;
    final daysInLastMonth = DateTime(
      lastMonthDate.year,
      lastMonthDate.month + 1,
      0,
    ).day;
    final adjustedDay = lastMonthDay > daysInLastMonth
        ? daysInLastMonth
        : lastMonthDay;
    final lastMonthEnd = DateTime(
      lastMonthDate.year,
      lastMonthDate.month,
      adjustedDay,
      23,
      59,
      59,
    );

    print('📊 Date ranges:');
    print('   Current: $currentMonthStart to $currentMonthEnd');
    print('   Previous: $lastMonthStart to $lastMonthEnd');

    // Fetch weekly insights for both periods
    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: currentMonthStart,
          endDate: currentMonthEnd,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: lastMonthStart,
          endDate: lastMonthEnd,
        );

    print(
      '📊 Found weekly insights: ${currentData.length} ads in current period, ${previousData.length} ads in previous period',
    );

    // Aggregate by campaign
    final currentByCampaign = await _aggregateByCampaign(currentData);
    final previousByCampaign = await _aggregateByCampaign(previousData);

    print(
      '📊 Aggregated: ${currentByCampaign.length} campaigns in current period, ${previousByCampaign.length} in previous period',
    );

    final comparisons = <CampaignComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      currentMonthStart,
      currentMonthEnd,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      lastMonthStart,
      lastMonthEnd,
    );

    // Only include campaigns with data in current period
    for (final campaignId in currentByCampaign.keys) {
      final currentMetrics = currentByCampaign[campaignId]!;
      final previousMetrics =
          previousByCampaign[campaignId] ?? _createZeroMetrics();

      final comparison = ComparisonResult.fromMetricsMap(
        entityId1: campaignId,
        entityName1: currentMetrics['campaignName'] as String? ?? 'Unknown',
        dateRange1: previousRange,
        metrics1: previousMetrics,
        entityId2: campaignId,
        entityName2: currentMetrics['campaignName'] as String? ?? 'Unknown',
        dateRange2: currentRange,
        metrics2: currentMetrics,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.CAMPAIGN,
      );

      comparisons.add(
        CampaignComparison(
          campaignId: campaignId,
          campaignName: currentMetrics['campaignName'] as String? ?? 'Unknown',
          comparison: comparison,
        ),
      );
    }

    // Sort by current spend descending
    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    return comparisons;
  }

  /// Get campaigns comparison using date ranges (for LAST_7_DAYS, LAST_30_DAYS)
  Future<List<CampaignComparison>> _getAllCampaignsDateRangeComparison(
    TimePeriod timePeriod,
  ) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(timePeriod);

    print('📊 Fetching weekly insights for date ranges:');
    print(
      '   Current: ${dateRanges['currentStart']} to ${dateRanges['currentEnd']}',
    );
    print(
      '   Previous: ${dateRanges['previousStart']} to ${dateRanges['previousEnd']}',
    );

    // Fetch weekly insights for both periods
    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: dateRanges['currentStart']!,
          endDate: dateRanges['currentEnd']!,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: dateRanges['previousStart']!,
          endDate: dateRanges['previousEnd']!,
        );

    print(
      '📊 Found weekly insights: ${currentData.length} ads in current period, ${previousData.length} ads in previous period',
    );

    // Aggregate by campaign
    final currentByCampaign = await _aggregateByCampaign(currentData);
    final previousByCampaign = await _aggregateByCampaign(previousData);

    print(
      '📊 Aggregated: ${currentByCampaign.length} campaigns in current period, ${previousByCampaign.length} in previous period',
    );

    final comparisons = <CampaignComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      dateRanges['currentStart']!,
      dateRanges['currentEnd']!,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      dateRanges['previousStart']!,
      dateRanges['previousEnd']!,
    );

    // Only include campaigns with data in current period
    for (final campaignId in currentByCampaign.keys) {
      final currentMetrics = currentByCampaign[campaignId]!;
      final previousMetrics =
          previousByCampaign[campaignId] ?? _createZeroMetrics();

      final comparison = ComparisonResult.fromMetricsMap(
        entityId1: campaignId,
        entityName1: currentMetrics['campaignName'] as String? ?? 'Unknown',
        dateRange1: previousRange,
        metrics1: previousMetrics,
        entityId2: campaignId,
        entityName2: currentMetrics['campaignName'] as String? ?? 'Unknown',
        dateRange2: currentRange,
        metrics2: currentMetrics,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.CAMPAIGN,
      );

      comparisons.add(
        CampaignComparison(
          campaignId: campaignId,
          campaignName: currentMetrics['campaignName'] as String? ?? 'Unknown',
          comparison: comparison,
        ),
      );
    }

    // Sort by current spend descending
    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));

    return comparisons;
  }

  /// Get ad sets for a campaign with comparisons
  Future<List<AdSetComparison>> getCampaignAdSetsComparison(
    String campaignId,
    TimePeriod timePeriod,
  ) async {
    try {
      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAdSetsMonthComparison(campaignId);
      } else {
        return await _getAdSetsDateRangeComparison(campaignId, timePeriod);
      }
    } catch (e) {
      print('Error getting ad sets comparison: $e');
      rethrow;
    }
  }

  /// Get ad sets comparison using monthlyTotals
  Future<List<AdSetComparison>> _getAdSetsMonthComparison(
    String campaignId,
  ) async {
    final months = TimePeriodCalculator.getMonthStrings();
    final currentMonth = months['current']!;
    final previousMonth = months['previous']!;

    final currentAdSets = await _adSetService.getAdSetsWithMonthTotals(
      campaignId: campaignId,
      month: currentMonth,
    );
    final previousAdSets = await _adSetService.getAdSetsWithMonthTotals(
      campaignId: campaignId,
      month: previousMonth,
    );

    // FALLBACK: If no ad sets have monthlyTotals, use date range aggregation
    if (currentAdSets.isEmpty) {
      print(
        '⚠️ No ad sets with monthlyTotals found for campaign $campaignId, falling back to date range aggregation',
      );
      return await _getAdSetsThisMonthFallback(campaignId);
    }

    final previousMap = {for (var a in previousAdSets) a.adSetId: a};
    final comparisons = <AdSetComparison>[];

    for (final currentAdSet in currentAdSets) {
      final previousAdSet = previousMap[currentAdSet.adSetId];

      ComparisonResult comparison;
      if (previousAdSet != null) {
        comparison = ComparisonResult.fromAdSets(
          adSet1: previousAdSet,
          adSet2: currentAdSet,
          dateRange1: previousMonth,
          dateRange2: currentMonth,
          comparisonType: ComparisonType.TIME_PERIOD,
        );
      } else {
        comparison = ComparisonResult.fromMetricsMap(
          entityId1: currentAdSet.adSetId,
          entityName1: currentAdSet.adSetName,
          dateRange1: previousMonth,
          metrics1: _createZeroMetrics(),
          entityId2: currentAdSet.adSetId,
          entityName2: currentAdSet.adSetName,
          dateRange2: currentMonth,
          metrics2: {
            'totalSpend': currentAdSet.totalSpend,
            'totalImpressions': currentAdSet.totalImpressions,
            'totalClicks': currentAdSet.totalClicks,
            'totalLeads': currentAdSet.totalLeads,
            'totalBookings': currentAdSet.totalBookings,
            'totalDeposits': currentAdSet.totalDeposits,
            'totalCashAmount': currentAdSet.totalCashAmount,
            'totalProfit': currentAdSet.totalProfit,
            'cpl': currentAdSet.cpl,
            'cpb': currentAdSet.cpb,
          },
          comparisonType: ComparisonType.TIME_PERIOD,
          entityLevel: EntityLevel.AD_SET,
        );
      }

      comparisons.add(
        AdSetComparison(
          adSetId: currentAdSet.adSetId,
          adSetName: currentAdSet.adSetName,
          campaignId: campaignId,
          comparison: comparison,
        ),
      );
    }

    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));
    return comparisons;
  }

  /// Fallback method for ad sets THIS_MONTH when monthlyTotals is not available
  Future<List<AdSetComparison>> _getAdSetsThisMonthFallback(
    String campaignId,
  ) async {
    print('📊 Using date range fallback for ad sets THIS_MONTH');

    // Calculate this month vs last month date ranges
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthStart = DateTime(lastMonthDate.year, lastMonthDate.month, 1);
    final lastMonthDay = now.day;
    final daysInLastMonth = DateTime(
      lastMonthDate.year,
      lastMonthDate.month + 1,
      0,
    ).day;
    final adjustedDay = lastMonthDay > daysInLastMonth
        ? daysInLastMonth
        : lastMonthDay;
    final lastMonthEnd = DateTime(
      lastMonthDate.year,
      lastMonthDate.month,
      adjustedDay,
      23,
      59,
      59,
    );

    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: currentMonthStart,
          endDate: currentMonthEnd,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: lastMonthStart,
          endDate: lastMonthEnd,
        );

    // Filter by campaign and aggregate by ad set
    final currentByAdSet = await _aggregateByAdSet(currentData, campaignId);
    final previousByAdSet = await _aggregateByAdSet(previousData, campaignId);

    final comparisons = <AdSetComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      currentMonthStart,
      currentMonthEnd,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      lastMonthStart,
      lastMonthEnd,
    );

    for (final adSetId in currentByAdSet.keys) {
      final currentMetrics = currentByAdSet[adSetId]!;
      final previousMetrics = previousByAdSet[adSetId] ?? _createZeroMetrics();

      final comparison = ComparisonResult.fromMetricsMap(
        entityId1: adSetId,
        entityName1: currentMetrics['adSetName'] as String? ?? 'Unknown',
        dateRange1: previousRange,
        metrics1: previousMetrics,
        entityId2: adSetId,
        entityName2: currentMetrics['adSetName'] as String? ?? 'Unknown',
        dateRange2: currentRange,
        metrics2: currentMetrics,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.AD_SET,
      );

      comparisons.add(
        AdSetComparison(
          adSetId: adSetId,
          adSetName: currentMetrics['adSetName'] as String? ?? 'Unknown',
          campaignId: campaignId,
          comparison: comparison,
        ),
      );
    }

    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));
    return comparisons;
  }

  /// Get ad sets comparison using date ranges
  Future<List<AdSetComparison>> _getAdSetsDateRangeComparison(
    String campaignId,
    TimePeriod timePeriod,
  ) async {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(timePeriod);

    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: dateRanges['currentStart']!,
          endDate: dateRanges['currentEnd']!,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: dateRanges['previousStart']!,
          endDate: dateRanges['previousEnd']!,
        );

    // Filter by campaign and aggregate by ad set
    final currentByAdSet = await _aggregateByAdSet(currentData, campaignId);
    final previousByAdSet = await _aggregateByAdSet(previousData, campaignId);

    final comparisons = <AdSetComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      dateRanges['currentStart']!,
      dateRanges['currentEnd']!,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      dateRanges['previousStart']!,
      dateRanges['previousEnd']!,
    );

    for (final adSetId in currentByAdSet.keys) {
      final currentMetrics = currentByAdSet[adSetId]!;
      final previousMetrics = previousByAdSet[adSetId] ?? _createZeroMetrics();

      final comparison = ComparisonResult.fromMetricsMap(
        entityId1: adSetId,
        entityName1: currentMetrics['adSetName'] as String? ?? 'Unknown',
        dateRange1: previousRange,
        metrics1: previousMetrics,
        entityId2: adSetId,
        entityName2: currentMetrics['adSetName'] as String? ?? 'Unknown',
        dateRange2: currentRange,
        metrics2: currentMetrics,
        comparisonType: ComparisonType.TIME_PERIOD,
        entityLevel: EntityLevel.AD_SET,
      );

      comparisons.add(
        AdSetComparison(
          adSetId: adSetId,
          adSetName: currentMetrics['adSetName'] as String? ?? 'Unknown',
          campaignId: campaignId,
          comparison: comparison,
        ),
      );
    }

    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));
    return comparisons;
  }

  /// Helper: Aggregate weekly insights by campaign
  /// IMPORTANT: This requires fetching ad metadata, which is expensive
  /// For better performance, use getCampaignsWithMonthTotals when possible
  Future<Map<String, Map<String, dynamic>>> _aggregateByCampaign(
    Map<String, List<FacebookWeeklyInsight>> weeklyData,
  ) async {
    final result = <String, Map<String, dynamic>>{};

    // Fetch ad metadata for all ads in the weekly data
    final adIds = weeklyData.keys.toList();
    final adMetadata = <String, Map<String, dynamic>>{};

    print('🔄 Fetching metadata for ${adIds.length} ads in batches...');

    // Batch fetch ads in groups of 10 to avoid sequential reads
    const batchSize = 10;
    for (var i = 0; i < adIds.length; i += batchSize) {
      final batchEnd = (i + batchSize < adIds.length)
          ? i + batchSize
          : adIds.length;
      final batchIds = adIds.sublist(i, batchEnd);

      // Fetch all docs in this batch in parallel
      final futures = batchIds
          .map((adId) => _firestore.collection('ads').doc(adId).get())
          .toList();

      try {
        final snapshots = await Future.wait(futures);

        for (var j = 0; j < snapshots.length; j++) {
          final doc = snapshots[j];
          if (doc.exists) {
            final data = doc.data();
            adMetadata[batchIds[j]] = {
              'campaignId': data?['campaignId'] ?? '',
              'campaignName': data?['campaignName'] ?? 'Unknown Campaign',
              'adSetId': data?['adSetId'] ?? '',
              'adSetName': data?['adSetName'] ?? 'Unknown Ad Set',
            };
          }
        }
      } catch (e) {
        print('Error fetching ad metadata batch: $e');
      }
    }

    print('✅ Fetched metadata for ${adMetadata.length} ads');

    // Aggregate by campaign
    for (final entry in weeklyData.entries) {
      final adId = entry.key;
      final insights = entry.value;
      if (insights.isEmpty) continue;

      final metadata = adMetadata[adId];
      if (metadata == null) continue;

      final campaignId = metadata['campaignId'] as String;
      final campaignName = metadata['campaignName'] as String;

      if (campaignId.isEmpty) continue;

      if (!result.containsKey(campaignId)) {
        result[campaignId] = {
          'campaignName': campaignName,
          ..._createZeroMetrics(),
        };
      }

      for (final insight in insights) {
        result[campaignId]!['totalSpend'] =
            (result[campaignId]!['totalSpend'] as double) + insight.spend;
        result[campaignId]!['totalImpressions'] =
            (result[campaignId]!['totalImpressions'] as int) +
            insight.impressions;
        result[campaignId]!['totalClicks'] =
            (result[campaignId]!['totalClicks'] as int) + insight.clicks;
      }
    }

    return result;
  }

  /// Helper: Aggregate weekly insights by ad set
  /// IMPORTANT: This requires fetching ad metadata, which is expensive
  Future<Map<String, Map<String, dynamic>>> _aggregateByAdSet(
    Map<String, List<FacebookWeeklyInsight>> weeklyData,
    String campaignId,
  ) async {
    final result = <String, Map<String, dynamic>>{};

    // Fetch ad metadata for all ads in the weekly data
    final adIds = weeklyData.keys.toList();
    final adMetadata = <String, Map<String, dynamic>>{};

    print('🔄 Fetching ad set metadata for ${adIds.length} ads in batches...');

    // Batch fetch ads in groups of 10
    const batchSize = 10;
    for (var i = 0; i < adIds.length; i += batchSize) {
      final batchEnd = (i + batchSize < adIds.length)
          ? i + batchSize
          : adIds.length;
      final batchIds = adIds.sublist(i, batchEnd);

      // Fetch all docs in this batch in parallel
      final futures = batchIds
          .map((adId) => _firestore.collection('ads').doc(adId).get())
          .toList();

      try {
        final snapshots = await Future.wait(futures);

        for (var j = 0; j < snapshots.length; j++) {
          final doc = snapshots[j];
          if (doc.exists) {
            final data = doc.data();
            final adCampaignId = data?['campaignId'] ?? '';
            // Only include ads from the specified campaign
            if (adCampaignId == campaignId) {
              adMetadata[batchIds[j]] = {
                'adSetId': data?['adSetId'] ?? '',
                'adSetName': data?['adSetName'] ?? 'Unknown Ad Set',
              };
            }
          }
        }
      } catch (e) {
        print('Error fetching ad metadata batch: $e');
      }
    }

    print('✅ Fetched ad set metadata for ${adMetadata.length} ads');

    // Aggregate by ad set
    for (final entry in weeklyData.entries) {
      final adId = entry.key;
      final insights = entry.value;
      if (insights.isEmpty) continue;

      final metadata = adMetadata[adId];
      if (metadata == null) continue;

      final adSetId = metadata['adSetId'] as String;
      final adSetName = metadata['adSetName'] as String;

      if (adSetId.isEmpty) continue;

      if (!result.containsKey(adSetId)) {
        result[adSetId] = {'adSetName': adSetName, ..._createZeroMetrics()};
      }

      for (final insight in insights) {
        result[adSetId]!['totalSpend'] =
            (result[adSetId]!['totalSpend'] as double) + insight.spend;
        result[adSetId]!['totalImpressions'] =
            (result[adSetId]!['totalImpressions'] as int) + insight.impressions;
        result[adSetId]!['totalClicks'] =
            (result[adSetId]!['totalClicks'] as int) + insight.clicks;
      }
    }

    return result;
  }

  /// Helper: Create zero metrics map
  Map<String, dynamic> _createZeroMetrics() {
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
      'roi': 0.0,
    };
  }

  // ============================================================================
  // SINGLE ENTITY COMPARISON METHODS (for drill-down UI)
  // ============================================================================

  /// Get comparison for a single campaign
  /// Returns the campaign's performance comparison for the selected time period
  Future<CampaignComparison?> getCampaignComparison(
    String campaignId,
    TimePeriod timePeriod,
  ) async {
    try {
      print('📊 Fetching comparison for campaign: $campaignId');

      // Get all campaigns comparison and find the one we need
      final allComparisons = await getAllCampaignsComparison(timePeriod);

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
    TimePeriod timePeriod,
  ) async {
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
    TimePeriod timePeriod,
  ) async {
    try {
      print('📊 Fetching ads comparison for ad set: $adSetId');

      if (timePeriod == TimePeriod.THIS_MONTH) {
        return await _getAdsThisMonthComparison(adSetId);
      } else {
        return await _getAdsDateRangeComparison(adSetId, timePeriod);
      }
    } catch (e) {
      print('❌ Error getting ads comparison: $e');
      rethrow;
    }
  }

  /// Get comparison for a single ad
  /// Returns the ad's performance comparison for the selected time period
  Future<AdComparison?> getAdComparison(
    String adId,
    TimePeriod timePeriod,
  ) async {
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
      final allAds = await getAdSetAdsComparison(adSetId, timePeriod);

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

  /// Helper: Get ads comparison for THIS_MONTH time period
  Future<List<AdComparison>> _getAdsThisMonthComparison(String adSetId) async {
    print('📊 Using date range fallback for ads THIS_MONTH');

    // Calculate this month vs last month date ranges
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthStart = DateTime(lastMonthDate.year, lastMonthDate.month, 1);
    final lastMonthDay = now.day;
    final daysInLastMonth = DateTime(
      lastMonthDate.year,
      lastMonthDate.month + 1,
      0,
    ).day;
    final adjustedDay = lastMonthDay > daysInLastMonth
        ? daysInLastMonth
        : lastMonthDay;
    final lastMonthEnd = DateTime(
      lastMonthDate.year,
      lastMonthDate.month,
      adjustedDay,
      23,
      59,
      59,
    );

    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: currentMonthStart,
          endDate: currentMonthEnd,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: lastMonthStart,
          endDate: lastMonthEnd,
        );

    // Filter by ad set and aggregate by ad
    final currentByAd = await _aggregateByAd(currentData, adSetId);
    final previousByAd = await _aggregateByAd(previousData, adSetId);

    print(
      '📊 Aggregated: ${currentByAd.length} ads in current period, ${previousByAd.length} in previous period',
    );

    final comparisons = <AdComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      currentMonthStart,
      currentMonthEnd,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      lastMonthStart,
      lastMonthEnd,
    );

    for (final adId in currentByAd.keys) {
      final currentMetrics = currentByAd[adId]!;
      final previousMetrics = previousByAd[adId] ?? _createZeroMetrics();
      final adName = currentMetrics['adName'] as String? ?? 'Unknown';

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

      comparisons.add(
        AdComparison(
          adId: adId,
          adName: adName,
          adSetId: adSetId,
          comparison: comparison,
        ),
      );
    }

    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));
    return comparisons;
  }

  /// Helper: Get ads comparison for date range time periods (LAST_7_DAYS, LAST_30_DAYS)
  Future<List<AdComparison>> _getAdsDateRangeComparison(
    String adSetId,
    TimePeriod timePeriod,
  ) async {
    final ranges = TimePeriodCalculator.calculateDateRanges(timePeriod);
    final currentStart = ranges['currentStart']!;
    final currentEnd = ranges['currentEnd']!;
    final previousStart = ranges['previousStart']!;
    final previousEnd = ranges['previousEnd']!;

    print('📊 Fetching ads for date ranges:');
    print('   Current: $currentStart to $currentEnd');
    print('   Previous: $previousStart to $previousEnd');

    final currentData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: currentStart,
          endDate: currentEnd,
        );
    final previousData =
        await WeeklyInsightsService.fetchAllWeeklyInsightsForDateRange(
          startDate: previousStart,
          endDate: previousEnd,
        );

    // Filter by ad set and aggregate by ad
    final currentByAd = await _aggregateByAd(currentData, adSetId);
    final previousByAd = await _aggregateByAd(previousData, adSetId);

    final comparisons = <AdComparison>[];
    final currentRange = TimePeriodCalculator.formatDateRange(
      currentStart,
      currentEnd,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      previousStart,
      previousEnd,
    );

    for (final adId in currentByAd.keys) {
      final currentMetrics = currentByAd[adId]!;
      final previousMetrics = previousByAd[adId] ?? _createZeroMetrics();
      final adName = currentMetrics['adName'] as String? ?? 'Unknown';

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

      comparisons.add(
        AdComparison(
          adId: adId,
          adName: adName,
          adSetId: adSetId,
          comparison: comparison,
        ),
      );
    }

    comparisons.sort((a, b) => b.currentSpend.compareTo(a.currentSpend));
    return comparisons;
  }

  /// Helper: Aggregate weekly insights by individual ad
  /// Filters by adSetId and returns metrics per adId
  Future<Map<String, Map<String, dynamic>>> _aggregateByAd(
    Map<String, List<FacebookWeeklyInsight>> weeklyData,
    String adSetId,
  ) async {
    final result = <String, Map<String, dynamic>>{};

    // Fetch ad metadata for all ads in the weekly data
    final adIds = weeklyData.keys.toList();
    final adMetadata = <String, Map<String, dynamic>>{};

    print('🔍 DEBUG: Aggregating by ad for adSetId: $adSetId');
    print('🔍 DEBUG: Total ads with weekly data: ${adIds.length}');

    // Batch fetch ads in groups of 10
    const batchSize = 10;
    int matchingAds = 0;
    int nonMatchingAds = 0;

    for (var i = 0; i < adIds.length; i += batchSize) {
      final batchEnd = (i + batchSize < adIds.length)
          ? i + batchSize
          : adIds.length;
      final batchIds = adIds.sublist(i, batchEnd);

      // Fetch all docs in this batch in parallel
      final futures = batchIds
          .map((adId) => _firestore.collection('ads').doc(adId).get())
          .toList();

      try {
        final snapshots = await Future.wait(futures);

        for (var j = 0; j < snapshots.length; j++) {
          final doc = snapshots[j];
          if (doc.exists) {
            final data = doc.data();
            final adAdSetId = data?['adSetId'] ?? '';
            final adName = data?['adName'] ?? 'Unknown Ad';

            print(
              '🔍 DEBUG: Ad ${batchIds[j]} ($adName) belongs to adSetId: $adAdSetId',
            );

            // Only include ads from the specified ad set
            if (adAdSetId == adSetId) {
              adMetadata[batchIds[j]] = {
                'adSetId': adAdSetId,
                'adName': adName,
              };
              matchingAds++;
              print('   ✅ MATCH - Added to results');
            } else {
              nonMatchingAds++;
              print(
                '   ❌ NO MATCH - Filtered out (expected: $adSetId, got: $adAdSetId)',
              );
            }
          } else {
            print(
              '🔍 DEBUG: Ad ${batchIds[j]} document does not exist in ads collection',
            );
          }
        }
      } catch (e) {
        print('Error fetching ad metadata batch: $e');
      }
    }

    print('✅ Fetched metadata for ${adMetadata.length} ads in ad set');
    print('📊 Matching ads: $matchingAds, Non-matching ads: $nonMatchingAds');

    // Aggregate by ad
    print('🔍 DEBUG: Starting aggregation of weekly insights...');
    int skippedNoMetadata = 0;
    int aggregatedAds = 0;

    for (final entry in weeklyData.entries) {
      final adId = entry.key;
      final insights = entry.value;
      if (insights.isEmpty) continue;

      final metadata = adMetadata[adId];
      if (metadata == null) {
        skippedNoMetadata++;
        continue;
      }

      final adName = metadata['adName'] as String;

      if (!result.containsKey(adId)) {
        result[adId] = {'adName': adName, ..._createZeroMetrics()};
        aggregatedAds++;
        print(
          '🔍 DEBUG: Aggregating ad $adId ($adName) - ${insights.length} weeks of data',
        );
      }

      for (final insight in insights) {
        result[adId]!['totalSpend'] =
            (result[adId]!['totalSpend'] as double) + insight.spend;
        result[adId]!['totalImpressions'] =
            (result[adId]!['totalImpressions'] as int) + insight.impressions;
        result[adId]!['totalClicks'] =
            (result[adId]!['totalClicks'] as int) + insight.clicks;
      }
    }

    print('📊 Final aggregation results:');
    print('   - Ads successfully aggregated: $aggregatedAds');
    print('   - Ads skipped (no metadata match): $skippedNoMetadata');
    print('   - Total ads in result: ${result.length}');

    return result;
  }
}
