import 'comparison_models.dart';

/// Time period options for automatic comparison
enum TimePeriod {
  LAST_7_DAYS,
  LAST_30_DAYS,
  THIS_MONTH,
}

extension TimePeriodExtension on TimePeriod {
  String get displayName {
    switch (this) {
      case TimePeriod.LAST_7_DAYS:
        return 'Last 7 Days vs Previous 7';
      case TimePeriod.LAST_30_DAYS:
        return 'Last 30 Days vs Previous 30';
      case TimePeriod.THIS_MONTH:
        return 'This Month vs Last Month';
    }
  }
}

/// Campaign with comparison data for list display
class CampaignComparison {
  final String campaignId;
  final String campaignName;
  final ComparisonResult comparison;
  bool isExpanded;
  List<AdSetComparison>? adSets;
  bool isLoadingAdSets;

  CampaignComparison({
    required this.campaignId,
    required this.campaignName,
    required this.comparison,
    this.isExpanded = false,
    this.adSets,
    this.isLoadingAdSets = false,
  });

  /// Get the primary metric change (profit %) for quick display
  double get profitChange {
    final profitComparison = comparison.metricComparisons.firstWhere(
      (m) => m.label == 'Profit',
      orElse: () => comparison.metricComparisons.first,
    );
    return profitComparison.changePercent;
  }

  /// Get current period spend
  double get currentSpend => comparison.dataset2.getMetric('totalSpend');

  /// Get previous period spend
  double get previousSpend => comparison.dataset1.getMetric('totalSpend');
}

/// Ad Set with comparison data for list display
class AdSetComparison {
  final String adSetId;
  final String adSetName;
  final String campaignId;
  final ComparisonResult comparison;
  bool isExpanded;
  List<AdComparison>? ads;
  bool isLoadingAds;

  AdSetComparison({
    required this.adSetId,
    required this.adSetName,
    required this.campaignId,
    required this.comparison,
    this.isExpanded = false,
    this.ads,
    this.isLoadingAds = false,
  });

  /// Get the primary metric change (profit %) for quick display
  double get profitChange {
    final profitComparison = comparison.metricComparisons.firstWhere(
      (m) => m.label == 'Profit',
      orElse: () => comparison.metricComparisons.first,
    );
    return profitComparison.changePercent;
  }

  /// Get current period spend
  double get currentSpend => comparison.dataset2.getMetric('totalSpend');

  /// Get previous period spend
  double get previousSpend => comparison.dataset1.getMetric('totalSpend');
}

/// Ad with comparison data for list display
class AdComparison {
  final String adId;
  final String adName;
  final String adSetId;
  final ComparisonResult comparison;

  AdComparison({
    required this.adId,
    required this.adName,
    required this.adSetId,
    required this.comparison,
  });

  /// Get the primary metric change (profit %) for quick display
  double get profitChange {
    final profitComparison = comparison.metricComparisons.firstWhere(
      (m) => m.label == 'Profit',
      orElse: () => comparison.metricComparisons.first,
    );
    return profitComparison.changePercent;
  }

  /// Get current period spend
  double get currentSpend => comparison.dataset2.getMetric('totalSpend');

  /// Get previous period spend
  double get previousSpend => comparison.dataset1.getMetric('totalSpend');
}

/// Helper class to calculate date ranges for time periods
class TimePeriodCalculator {
  /// Calculate date ranges for a time period
  static Map<String, DateTime> calculateDateRanges(TimePeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (period) {
      case TimePeriod.LAST_7_DAYS:
        // Last 7 days: today - 6 to today
        final current7Start = today.subtract(const Duration(days: 6));
        final current7End = today;
        // Previous 7 days: today - 13 to today - 7
        final previous7Start = today.subtract(const Duration(days: 13));
        final previous7End = today.subtract(const Duration(days: 7));
        
        return {
          'currentStart': DateTime(current7Start.year, current7Start.month, current7Start.day),
          'currentEnd': current7End,
          'previousStart': DateTime(previous7Start.year, previous7Start.month, previous7Start.day),
          'previousEnd': previous7End,
        };

      case TimePeriod.LAST_30_DAYS:
        // Last 30 days: today - 29 to today
        final current30Start = today.subtract(const Duration(days: 29));
        final current30End = today;
        // Previous 30 days: today - 59 to today - 30
        final previous30Start = today.subtract(const Duration(days: 59));
        final previous30End = today.subtract(const Duration(days: 30));
        
        return {
          'currentStart': DateTime(current30Start.year, current30Start.month, current30Start.day),
          'currentEnd': current30End,
          'previousStart': DateTime(previous30Start.year, previous30Start.month, previous30Start.day),
          'previousEnd': previous30End,
        };

      case TimePeriod.THIS_MONTH:
        // This month: first day of current month to today
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final thisMonthEnd = today;
        
        // Last month: same day range in previous month
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        final lastMonthStart = DateTime(lastMonthDate.year, lastMonthDate.month, 1);
        final lastMonthDay = now.day;
        // Handle case where current day doesn't exist in previous month (e.g., Jan 31 vs Feb)
        final daysInLastMonth = DateTime(lastMonthDate.year, lastMonthDate.month + 1, 0).day;
        final adjustedDay = lastMonthDay > daysInLastMonth ? daysInLastMonth : lastMonthDay;
        final lastMonthEnd = DateTime(lastMonthDate.year, lastMonthDate.month, adjustedDay, 23, 59, 59);
        
        return {
          'currentStart': thisMonthStart,
          'currentEnd': thisMonthEnd,
          'previousStart': lastMonthStart,
          'previousEnd': lastMonthEnd,
        };
    }
  }

  /// Get month strings for THIS_MONTH period (for fast monthlyTotals lookup)
  static Map<String, String> getMonthStrings() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonth = '${lastMonthDate.year}-${lastMonthDate.month.toString().padLeft(2, '0')}';
    
    return {
      'current': currentMonth,
      'previous': lastMonth,
    };
  }

  /// Format date range as string for display
  static String formatDateRange(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.day}-${end.day}, ${start.year}';
    } else {
      return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';
    }
  }
}

