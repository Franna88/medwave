import '../performance/campaign.dart';
import '../performance/ad_set.dart';

/// Type of comparison being performed
enum ComparisonType {
  TIME_PERIOD, // Comparing same entity across different time periods
  ENTITY_VS_ENTITY, // Comparing different entities in same time period
}

/// Level of entity being compared
enum EntityLevel {
  CAMPAIGN,
  AD_SET,
  ADVERT,
}

/// Type of time period for comparison
enum PeriodType {
  WEEK,
  MONTH,
  QUARTER,
  CUSTOM,
}

/// Represents a single dataset in a comparison
class ComparisonDataset {
  final String entityId;
  final String entityName;
  final String dateRange;
  final Map<String, dynamic> metrics;

  ComparisonDataset({
    required this.entityId,
    required this.entityName,
    required this.dateRange,
    required this.metrics,
  });

  /// Get a specific metric value
  double getMetric(String key) {
    final value = metrics[key];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }

  /// Get an integer metric value
  int getIntMetric(String key) {
    final value = metrics[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }
}

/// Result of a comparison between two datasets
class ComparisonResult {
  final ComparisonType comparisonType;
  final EntityLevel entityLevel;
  final ComparisonDataset dataset1;
  final ComparisonDataset dataset2;
  final List<MetricComparison> metricComparisons;

  ComparisonResult({
    required this.comparisonType,
    required this.entityLevel,
    required this.dataset1,
    required this.dataset2,
    required this.metricComparisons,
  });

  /// Create comparison result from two campaigns
  factory ComparisonResult.fromCampaigns({
    required Campaign campaign1,
    required Campaign campaign2,
    required String dateRange1,
    required String dateRange2,
    required ComparisonType comparisonType,
  }) {
    final dataset1 = ComparisonDataset(
      entityId: campaign1.campaignId,
      entityName: campaign1.campaignName,
      dateRange: dateRange1,
      metrics: {
        'totalSpend': campaign1.totalSpend,
        'totalImpressions': campaign1.totalImpressions,
        'totalClicks': campaign1.totalClicks,
        'totalReach': campaign1.totalReach,
        'totalLeads': campaign1.totalLeads,
        'totalBookings': campaign1.totalBookings,
        'totalDeposits': campaign1.totalDeposits,
        'totalCashAmount': campaign1.totalCashAmount,
        'totalProfit': campaign1.totalProfit,
        'cpl': campaign1.cpl,
        'cpb': campaign1.cpb,
        'cpa': campaign1.cpa,
        'roi': campaign1.roi,
        'avgCPM': campaign1.avgCPM,
        'avgCPC': campaign1.avgCPC,
        'avgCTR': campaign1.avgCTR,
      },
    );

    final dataset2 = ComparisonDataset(
      entityId: campaign2.campaignId,
      entityName: campaign2.campaignName,
      dateRange: dateRange2,
      metrics: {
        'totalSpend': campaign2.totalSpend,
        'totalImpressions': campaign2.totalImpressions,
        'totalClicks': campaign2.totalClicks,
        'totalReach': campaign2.totalReach,
        'totalLeads': campaign2.totalLeads,
        'totalBookings': campaign2.totalBookings,
        'totalDeposits': campaign2.totalDeposits,
        'totalCashAmount': campaign2.totalCashAmount,
        'totalProfit': campaign2.totalProfit,
        'cpl': campaign2.cpl,
        'cpb': campaign2.cpb,
        'cpa': campaign2.cpa,
        'roi': campaign2.roi,
        'avgCPM': campaign2.avgCPM,
        'avgCPC': campaign2.avgCPC,
        'avgCTR': campaign2.avgCTR,
      },
    );

    final metricComparisons = _createMetricComparisons(dataset1, dataset2);

    return ComparisonResult(
      comparisonType: comparisonType,
      entityLevel: EntityLevel.CAMPAIGN,
      dataset1: dataset1,
      dataset2: dataset2,
      metricComparisons: metricComparisons,
    );
  }

  /// Create comparison result from two ad sets
  factory ComparisonResult.fromAdSets({
    required AdSet adSet1,
    required AdSet adSet2,
    required String dateRange1,
    required String dateRange2,
    required ComparisonType comparisonType,
  }) {
    final dataset1 = ComparisonDataset(
      entityId: adSet1.adSetId,
      entityName: adSet1.adSetName,
      dateRange: dateRange1,
      metrics: {
        'totalSpend': adSet1.totalSpend,
        'totalImpressions': adSet1.totalImpressions,
        'totalClicks': adSet1.totalClicks,
        'totalReach': adSet1.totalReach,
        'totalLeads': adSet1.totalLeads,
        'totalBookings': adSet1.totalBookings,
        'totalDeposits': adSet1.totalDeposits,
        'totalCashAmount': adSet1.totalCashAmount,
        'totalProfit': adSet1.totalProfit,
        'cpl': adSet1.cpl,
        'cpb': adSet1.cpb,
        'cpa': adSet1.cpa,
        'avgCPM': adSet1.avgCPM,
        'avgCPC': adSet1.avgCPC,
        'avgCTR': adSet1.avgCTR,
      },
    );

    final dataset2 = ComparisonDataset(
      entityId: adSet2.adSetId,
      entityName: adSet2.adSetName,
      dateRange: dateRange2,
      metrics: {
        'totalSpend': adSet2.totalSpend,
        'totalImpressions': adSet2.totalImpressions,
        'totalClicks': adSet2.totalClicks,
        'totalReach': adSet2.totalReach,
        'totalLeads': adSet2.totalLeads,
        'totalBookings': adSet2.totalBookings,
        'totalDeposits': adSet2.totalDeposits,
        'totalCashAmount': adSet2.totalCashAmount,
        'totalProfit': adSet2.totalProfit,
        'cpl': adSet2.cpl,
        'cpb': adSet2.cpb,
        'cpa': adSet2.cpa,
        'avgCPM': adSet2.avgCPM,
        'avgCPC': adSet2.avgCPC,
        'avgCTR': adSet2.avgCTR,
      },
    );

    final metricComparisons = _createMetricComparisons(dataset1, dataset2);

    return ComparisonResult(
      comparisonType: comparisonType,
      entityLevel: EntityLevel.AD_SET,
      dataset1: dataset1,
      dataset2: dataset2,
      metricComparisons: metricComparisons,
    );
  }

  /// Create comparison result from raw metrics maps (used for ads and custom calculations)
  factory ComparisonResult.fromMetricsMap({
    required String entityId1,
    required String entityName1,
    required String dateRange1,
    required Map<String, dynamic> metrics1,
    required String entityId2,
    required String entityName2,
    required String dateRange2,
    required Map<String, dynamic> metrics2,
    required ComparisonType comparisonType,
    required EntityLevel entityLevel,
  }) {
    final dataset1 = ComparisonDataset(
      entityId: entityId1,
      entityName: entityName1,
      dateRange: dateRange1,
      metrics: metrics1,
    );

    final dataset2 = ComparisonDataset(
      entityId: entityId2,
      entityName: entityName2,
      dateRange: dateRange2,
      metrics: metrics2,
    );

    final metricComparisons = _createMetricComparisons(dataset1, dataset2);

    return ComparisonResult(
      comparisonType: comparisonType,
      entityLevel: entityLevel,
      dataset1: dataset1,
      dataset2: dataset2,
      metricComparisons: metricComparisons,
    );
  }

  /// Create metric comparisons from two datasets
  static List<MetricComparison> _createMetricComparisons(
    ComparisonDataset dataset1,
    ComparisonDataset dataset2,
  ) {
    return [
      MetricComparison(
        label: 'Spend',
        previousValue: dataset1.getMetric('totalSpend'),
        currentValue: dataset2.getMetric('totalSpend'),
        isGoodWhenUp: false,
      ),
      MetricComparison(
        label: 'Impressions',
        previousValue: dataset1.getMetric('totalImpressions'),
        currentValue: dataset2.getMetric('totalImpressions'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Clicks',
        previousValue: dataset1.getMetric('totalClicks'),
        currentValue: dataset2.getMetric('totalClicks'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Leads',
        previousValue: dataset1.getMetric('totalLeads'),
        currentValue: dataset2.getMetric('totalLeads'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Bookings',
        previousValue: dataset1.getMetric('totalBookings'),
        currentValue: dataset2.getMetric('totalBookings'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Deposits',
        previousValue: dataset1.getMetric('totalDeposits'),
        currentValue: dataset2.getMetric('totalDeposits'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Cash',
        previousValue: dataset1.getMetric('totalCashAmount'),
        currentValue: dataset2.getMetric('totalCashAmount'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'Profit',
        previousValue: dataset1.getMetric('totalProfit'),
        currentValue: dataset2.getMetric('totalProfit'),
        isGoodWhenUp: true,
      ),
      MetricComparison(
        label: 'CPL',
        previousValue: dataset1.getMetric('cpl'),
        currentValue: dataset2.getMetric('cpl'),
        isGoodWhenUp: false,
      ),
      MetricComparison(
        label: 'CPB',
        previousValue: dataset1.getMetric('cpb'),
        currentValue: dataset2.getMetric('cpb'),
        isGoodWhenUp: false,
      ),
      MetricComparison(
        label: 'ROI',
        previousValue: dataset1.getMetric('roi'),
        currentValue: dataset2.getMetric('roi'),
        isGoodWhenUp: true,
      ),
    ];
  }
}

/// Metric comparison model (reused from timeline screen)
class MetricComparison {
  final String label;
  final double previousValue;
  final double currentValue;
  final bool isGoodWhenUp;

  MetricComparison({
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.isGoodWhenUp,
  });

  /// Calculate percentage change
  double get changePercent {
    if (previousValue == 0) {
      return currentValue > 0 ? 100.0 : 0.0;
    }
    return ((currentValue - previousValue) / previousValue) * 100;
  }

  /// Whether the value increased
  bool get isIncrease => currentValue > previousValue;

  /// Whether this change is good based on the metric type
  bool get isGoodChange {
    if (isIncrease) {
      return isGoodWhenUp;
    } else {
      return !isGoodWhenUp;
    }
  }

  /// Absolute change in value
  double get absoluteChange => currentValue - previousValue;
}

