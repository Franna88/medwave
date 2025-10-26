import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

/// Model representing ad performance cost tracking with budget and metrics
class AdPerformanceCost {
  final String id;
  final String campaignName;
  final String campaignKey;
  final String adId;
  final String adName;
  final double budget;
  final String? linkedProductId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  AdPerformanceCost({
    required this.id,
    required this.campaignName,
    required this.campaignKey,
    required this.adId,
    required this.adName,
    required this.budget,
    this.linkedProductId,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Create from Firestore document
  factory AdPerformanceCost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdPerformanceCost(
      id: doc.id,
      campaignName: data['campaignName'] ?? '',
      campaignKey: data['campaignKey'] ?? '',
      adId: data['adId'] ?? '',
      adName: data['adName'] ?? '',
      budget: (data['budget'] ?? 0).toDouble(),
      linkedProductId: data['linkedProductId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  /// Create from JSON
  factory AdPerformanceCost.fromJson(Map<String, dynamic> json) {
    return AdPerformanceCost(
      id: json['id'] ?? '',
      campaignName: json['campaignName'] ?? '',
      campaignKey: json['campaignKey'] ?? '',
      adId: json['adId'] ?? '',
      adName: json['adName'] ?? '',
      budget: (json['budget'] ?? 0).toDouble(),
      linkedProductId: json['linkedProductId'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      createdBy: json['createdBy'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'campaignName': campaignName,
      'campaignKey': campaignKey,
      'adId': adId,
      'adName': adName,
      'budget': budget,
      if (linkedProductId != null) 'linkedProductId': linkedProductId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignName': campaignName,
      'campaignKey': campaignKey,
      'adId': adId,
      'adName': adName,
      'budget': budget,
      if (linkedProductId != null) 'linkedProductId': linkedProductId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Create a copy with updated fields
  AdPerformanceCost copyWith({
    String? id,
    String? campaignName,
    String? campaignKey,
    String? adId,
    String? adName,
    double? budget,
    String? linkedProductId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AdPerformanceCost(
      id: id ?? this.id,
      campaignName: campaignName ?? this.campaignName,
      campaignKey: campaignKey ?? this.campaignKey,
      adId: adId ?? this.adId,
      adName: adName ?? this.adName,
      budget: budget ?? this.budget,
      linkedProductId: linkedProductId ?? this.linkedProductId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'AdPerformanceCost(id: $id, campaign: $campaignName, ad: $adName, budget: R$budget)';
  }
}

/// Extended model with calculated metrics from cumulative data
class AdPerformanceCostWithMetrics {
  final AdPerformanceCost cost;
  final int leads;
  final int bookings;
  final int deposits;
  final double cashDepositAmount;
  final Product? linkedProduct;

  AdPerformanceCostWithMetrics({
    required this.cost,
    required this.leads,
    required this.bookings,
    required this.deposits,
    required this.cashDepositAmount,
    this.linkedProduct,
  });

  // Computed metrics
  double get cpl => leads > 0 ? cost.budget / leads : 0;
  double get cpb => bookings > 0 ? cost.budget / bookings : 0;
  double get cpa => deposits > 0 ? cost.budget / deposits : 0;
  
  double get productExpenseCost => linkedProduct?.expenseCost ?? 0;
  double get productDepositAmount => linkedProduct?.depositAmount ?? 0;
  
  double get actualProfit {
    final depositRevenue = deposits * productDepositAmount;
    return (cashDepositAmount + depositRevenue) - (cost.budget + productExpenseCost);
  }

  // Percentage calculations
  
  /// Calculate budget percentage relative to total budget
  double budgetPercentage(double totalBudget) {
    return totalBudget > 0 ? (cost.budget / totalBudget) * 100 : 0;
  }
  
  /// Booking rate: bookings as percentage of leads
  double get bookingRate => leads > 0 ? (bookings / leads) * 100 : 0;
  
  /// Deposit rate: deposits as percentage of bookings
  double get depositRate => bookings > 0 ? (deposits / bookings) * 100 : 0;
  
  /// Overall conversion rate: deposits as percentage of leads
  double get overallConversionRate => leads > 0 ? (deposits / leads) * 100 : 0;
  
  /// Profit margin percentage: profit as percentage of total investment
  double get profitMargin {
    final totalInvestment = cost.budget + productExpenseCost;
    return totalInvestment > 0 ? (actualProfit / totalInvestment) * 100 : 0;
  }
  
  /// CPL as percentage of budget
  double get cplPercentage => cost.budget > 0 ? (cpl / cost.budget) * 100 : 0;
  
  /// CPB as percentage of budget
  double get cpbPercentage => cost.budget > 0 ? (cpb / cost.budget) * 100 : 0;
  
  /// CPA as percentage of budget
  double get cpaPercentage => cost.budget > 0 ? (cpa / cost.budget) * 100 : 0;

  /// Get ad name for display
  String get adName => cost.adName.isNotEmpty ? cost.adName : cost.adId;

  /// Get campaign name for display
  String get campaignName => cost.campaignName;

  /// Get budget
  double get budget => cost.budget;

  @override
  String toString() {
    return 'AdPerformanceWithMetrics(ad: $adName, leads: $leads, bookings: $bookings, deposits: $deposits, profit: R$actualProfit)';
  }
}

