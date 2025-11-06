import 'ad_performance_data.dart';

/// Aggregated ad set-level metrics
class AdSetAggregate {
  final String adSetId;
  final String adSetName;
  final String campaignId;
  final String campaignName;
  final int totalAds;
  
  // Facebook metrics (aggregated)
  final double totalFbSpend;
  final int totalImpressions;
  final int totalReach;
  final int totalClicks;
  
  // GHL metrics (aggregated)
  final int totalLeads;
  final int totalBookings;
  final int totalDeposits;
  final int totalCashCollected;
  final double totalCashAmount;
  
  // Admin config (aggregated)
  final double totalBudget;
  
  // Metadata
  final DateTime lastUpdated;
  final List<AdPerformanceWithProduct> ads;
  
  AdSetAggregate({
    required this.adSetId,
    required this.adSetName,
    required this.campaignId,
    required this.campaignName,
    required this.totalAds,
    required this.totalFbSpend,
    required this.totalImpressions,
    required this.totalReach,
    required this.totalClicks,
    required this.totalLeads,
    required this.totalBookings,
    required this.totalDeposits,
    required this.totalCashCollected,
    required this.totalCashAmount,
    required this.totalBudget,
    required this.lastUpdated,
    required this.ads,
  });
  
  // Computed metrics
  
  /// Average Cost Per Mille (CPM)
  double get avgCPM {
    return totalImpressions > 0 
        ? (totalFbSpend / totalImpressions) * 1000 
        : 0;
  }
  
  /// Average Cost Per Click (CPC)
  double get avgCPC {
    return totalClicks > 0 ? totalFbSpend / totalClicks : 0;
  }
  
  /// Average Click-Through Rate (CTR)
  double get avgCTR {
    return totalImpressions > 0 
        ? (totalClicks / totalImpressions) * 100 
        : 0;
  }
  
  /// Cost Per Lead (CPL)
  double get cpl {
    return totalLeads > 0 ? totalFbSpend / totalLeads : 0;
  }
  
  /// Cost Per Booking (CPB)
  double get cpb {
    return totalBookings > 0 ? totalFbSpend / totalBookings : 0;
  }
  
  /// Cost Per Acquisition/Deposit (CPA)
  double get cpa {
    return totalDeposits > 0 ? totalFbSpend / totalDeposits : 0;
  }
  
  /// Total profit (cash - FB spend)
  double get totalProfit {
    // Use real monetary values - totalCashAmount already has actual opportunity values
    return totalCashAmount - totalFbSpend;
  }
  
  /// Total cost (FB spend only)
  double get totalCost {
    return totalFbSpend;
  }
  
  /// Return on Investment (ROI) percentage
  double get roi {
    return totalCost > 0 
        ? ((totalCashAmount - totalCost) / totalCost) * 100 
        : 0;
  }
  
  /// Lead to booking conversion rate
  double get leadToBookingRate {
    return totalLeads > 0 ? (totalBookings / totalLeads) * 100 : 0;
  }
  
  /// Booking to deposit conversion rate
  double get bookingToDepositRate {
    return totalBookings > 0 ? (totalDeposits / totalBookings) * 100 : 0;
  }
  
  /// Deposit to cash conversion rate
  double get depositToCashRate {
    return totalDeposits > 0 ? (totalCashCollected / totalDeposits) * 100 : 0;
  }
  
  /// Overall conversion rate (leads to cash)
  double get overallConversionRate {
    return totalLeads > 0 ? (totalCashCollected / totalLeads) * 100 : 0;
  }
  
  /// Is ad set profitable
  bool get isProfitable => totalProfit > 0;
  
  /// Has spend
  bool get hasSpend => totalFbSpend > 0;
  
  /// Ad set status (based on last updated date)
  String get status {
    final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
    if (daysSinceUpdate <= 1) return 'Active';
    if (daysSinceUpdate <= 7) return 'Recent';
    return 'Paused';
  }
}

