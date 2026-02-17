import 'package:intl/intl.dart';
import '../../../../../theme/app_theme.dart';

class AnalyticsHelpers {
  // Helper method to get date range based on filter
  static Map<String, DateTime?> getDateRange(String dateFilter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (dateFilter) {
      case 'today':
        return {'start': today, 'end': now};
      case 'yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return {'start': yesterday, 'end': today.subtract(const Duration(milliseconds: 1))};
      case 'last7days':
        return {'start': today.subtract(const Duration(days: 7)), 'end': now};
      case 'last30days':
        return {'start': today.subtract(const Duration(days: 30)), 'end': now};
      case 'last90days':
        return {'start': today.subtract(const Duration(days: 90)), 'end': now};
      default:
        return {'start': null, 'end': null}; // All time
    }
  }

  // Helper method to filter data by date range
  static bool isInDateRange(DateTime date, String dateFilter) {
    final range = getDateRange(dateFilter);
    if (range['start'] == null) return true; // All time
    
    return date.isAfter(range['start']!) && date.isBefore(range['end']!.add(const Duration(days: 1)));
  }

  static String formatCurrency(double amount) {
    return 'R${amount.toStringAsFixed(2)}';
  }
}
