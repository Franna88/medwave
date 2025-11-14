import 'comparison_models.dart';

/// Time period options for automatic comparison
enum TimePeriod { THIS_WEEK, THIS_MONTH }

extension TimePeriodExtension on TimePeriod {
  String get displayName {
    switch (this) {
      case TimePeriod.THIS_WEEK:
        return 'This Week vs Last Week';
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
      case TimePeriod.THIS_WEEK:
        // Current week: Monday of current week to today
        final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
        final daysFromMonday = currentWeekday - 1;
        final currentWeekStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysFromMonday));
        final currentWeekEnd = today;

        // Previous week: Monday to Sunday of last week
        final previousWeekStart = currentWeekStart.subtract(
          const Duration(days: 7),
        );
        final previousWeekEnd = DateTime(
          previousWeekStart.year,
          previousWeekStart.month,
          previousWeekStart.day + 6,
          23,
          59,
          59,
        );

        return {
          'currentStart': currentWeekStart,
          'currentEnd': currentWeekEnd,
          'previousStart': previousWeekStart,
          'previousEnd': previousWeekEnd,
        };

      case TimePeriod.THIS_MONTH:
        // This month: first day of current month to today
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final thisMonthEnd = today;

        // Last month: same day range in previous month
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        final lastMonthStart = DateTime(
          lastMonthDate.year,
          lastMonthDate.month,
          1,
        );
        final lastMonthDay = now.day;
        // Handle case where current day doesn't exist in previous month (e.g., Jan 31 vs Feb)
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
    final lastMonth =
        '${lastMonthDate.year}-${lastMonthDate.month.toString().padLeft(2, '0')}';

    return {'current': currentMonth, 'previous': lastMonth};
  }

  /// Format date range as string for display
  static String formatDateRange(DateTime start, DateTime end) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.day}-${end.day}, ${start.year}';
    } else {
      return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';
    }
  }
}
