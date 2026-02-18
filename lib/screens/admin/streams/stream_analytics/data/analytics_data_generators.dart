import 'package:intl/intl.dart';
import '../../../../../theme/app_theme.dart';
import '../utils/analytics_helpers.dart';

/// Consolidated file containing all data generators for Stream Analytics

class AnalyticsDataGenerators {
  // Generate Deposits Data
  static Map<String, dynamic> generateDepositsData(String dateFilter) {
    final dateRange = AnalyticsHelpers.getDateRange(dateFilter);
    final daysDiff = dateRange['start'] == null 
        ? 365 
        : DateTime.now().difference(dateRange['start']!).inDays;
    final monthsToShow = (daysDiff / 30).ceil().clamp(1, 12);
    
    const baseCount = 342;
    const baseValue = 245680.00;
    final filteredCount = dateRange['start'] == null 
        ? baseCount 
        : (baseCount * (daysDiff / 365)).round();
    final filteredValue = dateRange['start'] == null 
        ? baseValue 
        : (baseValue * (daysDiff / 365));
    
    return {
      'count': filteredCount,
      'totalValue': filteredValue,
      'average': filteredCount > 0 ? filteredValue / filteredCount : 0,
      'chartData': List.generate(monthsToShow, (i) {
        final date = DateTime.now().subtract(Duration(days: (monthsToShow - 1 - i) * 30));
        return {
          'label': DateFormat('MMM').format(date),
          'value': 15000 + (i * 2000) + (i % 3) * 1000,
        };
      }),
      'breakdown': {
        'Full Payment': filteredValue * 0.51,
        'Deposit Only': filteredValue * 0.49,
      },
    };
  }

  // Generate Closed Sales Data
  static Map<String, dynamic> generateClosedSalesData(String dateFilter) {
    final dateRange = AnalyticsHelpers.getDateRange(dateFilter);
    final daysDiff = dateRange['start'] == null 
        ? 365 
        : DateTime.now().difference(dateRange['start']!).inDays;
    final monthsToShow = (daysDiff / 30).ceil().clamp(1, 12);
    
    const baseCount = 189;
    const baseValue = 567890.00;
    final filteredCount = dateRange['start'] == null 
        ? baseCount 
        : (baseCount * (daysDiff / 365)).round();
    final filteredValue = dateRange['start'] == null 
        ? baseValue 
        : (baseValue * (daysDiff / 365));
    
    return {
      'count': filteredCount,
      'totalValue': filteredValue,
      'average': filteredCount > 0 ? filteredValue / filteredCount : 0,
      'chartData': List.generate(monthsToShow, (i) {
        final date = DateTime.now().subtract(Duration(days: (monthsToShow - 1 - i) * 30));
        return {
          'label': DateFormat('MMM').format(date),
          'count': 12 + (i % 5),
        };
      }),
      'topSales': List.generate(10, (i) {
        final date = DateTime.now().subtract(Duration(days: i * 2));
        if (!AnalyticsHelpers.isInDateRange(date, dateFilter)) return null;
        return {
          'customer': 'Customer ${i + 1}',
          'date': DateFormat('MMM d, y').format(date),
          'amount': 2500.00 + (i * 500),
        };
      }).whereType<Map<String, dynamic>>().toList(),
    };
  }

  // Generate Late Payments Data
  static Map<String, dynamic> generateLatePaymentsData(String dateFilter) {
    final dateRange = AnalyticsHelpers.getDateRange(dateFilter);
    final daysDiff = dateRange['start'] == null 
        ? 365 
        : DateTime.now().difference(dateRange['start']!).inDays;
    final monthsToShow = (daysDiff / 30).ceil().clamp(1, 12);
    
    const baseCount = 23;
    const baseOutstanding = 45678.00;
    final filteredCount = dateRange['start'] == null 
        ? baseCount 
        : (baseCount * (daysDiff / 365)).round();
    final filteredOutstanding = dateRange['start'] == null 
        ? baseOutstanding 
        : (baseOutstanding * (daysDiff / 365));
    
    return {
      'count': filteredCount,
      'totalOutstanding': filteredOutstanding,
      'avgDaysLate': 15,
      'chartData': List.generate(monthsToShow, (i) {
        final date = DateTime.now().subtract(Duration(days: (monthsToShow - 1 - i) * 30));
        return {
          'label': DateFormat('MMM').format(date),
          'value': 15 + (i % 5),
        };
      }),
      'pending': List.generate(10, (i) {
        final date = DateTime.now().subtract(Duration(days: 5 + (i * 2)));
        if (!AnalyticsHelpers.isInDateRange(date, dateFilter)) return null;
        return {
          'customer': 'Customer ${i + 1}',
          'daysLate': 5 + (i * 2),
          'amount': 2000.00 + (i * 500),
          'date': DateFormat('MMM d').format(date),
        };
      }).whereType<Map<String, dynamic>>().toList(),
    };
  }

  // Generate Revenue Data
  static Map<String, dynamic> generateRevenueData(String dateFilter) {
    final dateRange = AnalyticsHelpers.getDateRange(dateFilter);
    final daysDiff = dateRange['start'] == null 
        ? 365 
        : DateTime.now().difference(dateRange['start']!).inDays;
    final monthsToShow = (daysDiff / 30).ceil().clamp(1, 12);
    
    const baseTotal = 1234567.00;
    const baseThisMonth = 98765.00;
    final filteredTotal = dateRange['start'] == null 
        ? baseTotal 
        : (baseTotal * (daysDiff / 365));
    final filteredThisMonth = dateRange['start'] == null || daysDiff > 30
        ? baseThisMonth
        : (baseThisMonth * (daysDiff / 30));
    
    return {
      'total': filteredTotal,
      'thisMonth': filteredThisMonth,
      'growth': 12.5,
      'chartData': List.generate(monthsToShow, (i) {
        final date = DateTime.now().subtract(Duration(days: (monthsToShow - 1 - i) * 30));
        return {
          'label': DateFormat('MMM').format(date),
          'value': 80000 + (i * 5000) + (i % 3) * 2000,
        };
      }),
      'bySource': {
        'Sales': filteredTotal * 0.65,
        'Deposits': filteredTotal * 0.24,
        'Installations': filteredTotal * 0.11,
      },
    };
  }

  // Generate Gross Margin Data
  static Map<String, dynamic> generateGrossMarginData(String dateFilter) {
    final dateRange = AnalyticsHelpers.getDateRange(dateFilter);
    final daysDiff = dateRange['start'] == null 
        ? 365 
        : DateTime.now().difference(dateRange['start']!).inDays;
    final monthsToShow = (daysDiff / 30).ceil().clamp(1, 12);
    
    const baseRevenue = 1234567.00;
    const baseCOGS = 789111.00;
    const baseProfit = 438456.00;
    const margin = 35.5;
    
    final filteredRevenue = dateRange['start'] == null 
        ? baseRevenue 
        : (baseRevenue * (daysDiff / 365));
    final filteredCOGS = dateRange['start'] == null 
        ? baseCOGS 
        : (baseCOGS * (daysDiff / 365));
    final filteredProfit = dateRange['start'] == null 
        ? baseProfit 
        : (baseProfit * (daysDiff / 365));
    
    return {
      'margin': margin,
      'profit': filteredProfit,
      'cogs': filteredCOGS,
      'chartData': List.generate(monthsToShow, (i) {
        final date = DateTime.now().subtract(Duration(days: (monthsToShow - 1 - i) * 30));
        return {
          'label': DateFormat('MMM').format(date),
          'value': 30.0 + (i * 0.5) + (i % 3) * 0.2,
        };
      }),
      'breakdown': {
        'Revenue': filteredRevenue,
        'COGS': filteredCOGS,
        'Gross Profit': filteredProfit,
        'Margin %': margin,
      },
    };
  }

  // Generate Stock Levels Data
  static Map<String, dynamic> generateStockLevelsData() {
    // Generate comprehensive mock data for all stock items
    final allItems = <Map<String, dynamic>>[];
    
    // Generate in-stock items
    for (int i = 1; i <= 145; i++) {
      final current = 50 + (i % 100);
      const min = 20;
      allItems.add({
        'name': 'Product ${i.toString().padLeft(3, '0')}',
        'current': current,
        'min': min,
        'percent': ((current / min) * 100).round(),
        'status': 'in_stock',
        'location': 'Warehouse ${(i % 5) + 1} - Shelf ${(i % 10) + 1}',
      });
    }
    
    // Generate low-stock items
    for (int i = 1; i <= 23; i++) {
      final current = 5 + (i % 15);
      const min = 20;
      allItems.add({
        'name': 'Low Stock Product ${i.toString().padLeft(2, '0')}',
        'current': current,
        'min': min,
        'percent': ((current / min) * 100).round(),
        'status': 'low_stock',
        'location': 'Warehouse ${(i % 3) + 1} - Shelf ${(i % 8) + 1}',
      });
    }
    
    // Generate out-of-stock items
    for (int i = 1; i <= 5; i++) {
      allItems.add({
        'name': 'Out of Stock Product ${i.toString().padLeft(2, '0')}',
        'current': 0,
        'min': 20,
        'percent': 0,
        'status': 'out_of_stock',
        'location': 'Warehouse ${(i % 2) + 1} - Shelf ${(i % 5) + 1}',
      });
    }
    
    return {
      'inStock': 145,
      'lowStock': 23,
      'outOfStock': 5,
      'chartData': [
        {'label': 'In Stock', 'value': 145, 'color': AppTheme.successColor},
        {'label': 'Low Stock', 'value': 23, 'color': AppTheme.warningColor},
        {'label': 'Out of Stock', 'value': 5, 'color': AppTheme.errorColor},
      ],
      'allItems': allItems,
      'lowStockItems': allItems.where((item) => item['status'] == 'low_stock').toList(),
    };
  }

  // Generate Forecasting Data
  static Map<String, dynamic> generateForecastingData() {
    return {
      'predictedDemand': 1250,
      'reorderPoints': 18,
      'forecastData': List.generate(6, (i) {
        return {
          'label': DateFormat('MMM').format(DateTime.now().add(Duration(days: i * 30))),
          'current': 150 + (i * 10),
          'forecast': 180 + (i * 15),
        };
      }),
      'reorders': List.generate(10, (i) {
        return {
          'name': 'Product ${i + 1}',
          'quantity': 50 + (i * 10),
          'date': DateFormat('MMM d').format(DateTime.now().add(Duration(days: i * 7))),
        };
      }),
    };
  }
}
