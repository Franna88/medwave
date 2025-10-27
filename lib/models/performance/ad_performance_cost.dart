import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

/// Model representing ad performance cost tracking with budget and metrics
class AdPerformanceCost {
  final String id;
  final String campaignName;
  final String campaignKey; // Also stores Facebook Campaign ID for matching
  final String adId;
  final String adName;
  final double budget; // Legacy field - kept for backward compatibility
  final String? linkedProductId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  
  // Facebook Ads API fields
  final String? facebookCampaignId; // Facebook Campaign ID for direct matching
  final double? facebookSpend;
  final int? impressions;
  final int? reach;
  final int? clicks;
  final double? cpm;
  final double? cpc;
  final double? ctr;
  final DateTime? lastFacebookSync;

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
    this.facebookCampaignId,
    this.facebookSpend,
    this.impressions,
    this.reach,
    this.clicks,
    this.cpm,
    this.cpc,
    this.ctr,
    this.lastFacebookSync,
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
      facebookCampaignId: data['facebookCampaignId'],
      facebookSpend: data['facebookSpend'] != null ? (data['facebookSpend'] as num).toDouble() : null,
      impressions: data['impressions'] != null ? (data['impressions'] as num).toInt() : null,
      reach: data['reach'] != null ? (data['reach'] as num).toInt() : null,
      clicks: data['clicks'] != null ? (data['clicks'] as num).toInt() : null,
      cpm: data['cpm'] != null ? (data['cpm'] as num).toDouble() : null,
      cpc: data['cpc'] != null ? (data['cpc'] as num).toDouble() : null,
      ctr: data['ctr'] != null ? (data['ctr'] as num).toDouble() : null,
      lastFacebookSync: data['lastFacebookSync'] != null 
          ? (data['lastFacebookSync'] as Timestamp).toDate() 
          : null,
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
      facebookCampaignId: json['facebookCampaignId'],
      facebookSpend: json['facebookSpend'] != null ? (json['facebookSpend'] as num).toDouble() : null,
      impressions: json['impressions'] != null ? (json['impressions'] as num).toInt() : null,
      reach: json['reach'] != null ? (json['reach'] as num).toInt() : null,
      clicks: json['clicks'] != null ? (json['clicks'] as num).toInt() : null,
      cpm: json['cpm'] != null ? (json['cpm'] as num).toDouble() : null,
      cpc: json['cpc'] != null ? (json['cpc'] as num).toDouble() : null,
      ctr: json['ctr'] != null ? (json['ctr'] as num).toDouble() : null,
      lastFacebookSync: json['lastFacebookSync'] != null
          ? (json['lastFacebookSync'] is Timestamp
              ? (json['lastFacebookSync'] as Timestamp).toDate()
              : DateTime.parse(json['lastFacebookSync']))
          : null,
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
      if (facebookCampaignId != null) 'facebookCampaignId': facebookCampaignId,
      if (facebookSpend != null) 'facebookSpend': facebookSpend,
      if (impressions != null) 'impressions': impressions,
      if (reach != null) 'reach': reach,
      if (clicks != null) 'clicks': clicks,
      if (cpm != null) 'cpm': cpm,
      if (cpc != null) 'cpc': cpc,
      if (ctr != null) 'ctr': ctr,
      if (lastFacebookSync != null) 'lastFacebookSync': Timestamp.fromDate(lastFacebookSync!),
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
      if (facebookCampaignId != null) 'facebookCampaignId': facebookCampaignId,
      if (facebookSpend != null) 'facebookSpend': facebookSpend,
      if (impressions != null) 'impressions': impressions,
      if (reach != null) 'reach': reach,
      if (clicks != null) 'clicks': clicks,
      if (cpm != null) 'cpm': cpm,
      if (cpc != null) 'cpc': cpc,
      if (ctr != null) 'ctr': ctr,
      if (lastFacebookSync != null) 'lastFacebookSync': lastFacebookSync!.toIso8601String(),
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
    String? facebookCampaignId,
    double? facebookSpend,
    int? impressions,
    int? reach,
    int? clicks,
    double? cpm,
    double? cpc,
    double? ctr,
    DateTime? lastFacebookSync,
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
      facebookCampaignId: facebookCampaignId ?? this.facebookCampaignId,
      facebookSpend: facebookSpend ?? this.facebookSpend,
      impressions: impressions ?? this.impressions,
      reach: reach ?? this.reach,
      clicks: clicks ?? this.clicks,
      cpm: cpm ?? this.cpm,
      cpc: cpc ?? this.cpc,
      ctr: ctr ?? this.ctr,
      lastFacebookSync: lastFacebookSync ?? this.lastFacebookSync,
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

  // Computed metrics - use Facebook spend if available, fallback to budget
  double get effectiveSpend => cost.facebookSpend ?? cost.budget;
  double get cpl => leads > 0 ? effectiveSpend / leads : 0;
  double get cpb => bookings > 0 ? effectiveSpend / bookings : 0;
  double get cpa => deposits > 0 ? effectiveSpend / deposits : 0;
  
  double get productExpenseCost => linkedProduct?.expenseCost ?? 0;
  double get productDepositAmount => linkedProduct?.depositAmount ?? 0;
  
  double get actualProfit {
    final depositRevenue = deposits * productDepositAmount;
    return (cashDepositAmount + depositRevenue) - (effectiveSpend + productExpenseCost);
  }

  // Percentage calculations
  
  /// Calculate spend percentage relative to total spend
  double budgetPercentage(double totalBudget) {
    return totalBudget > 0 ? (effectiveSpend / totalBudget) * 100 : 0;
  }
  
  /// Booking rate: bookings as percentage of leads
  double get bookingRate => leads > 0 ? (bookings / leads) * 100 : 0;
  
  /// Deposit rate: deposits as percentage of bookings
  double get depositRate => bookings > 0 ? (deposits / bookings) * 100 : 0;
  
  /// Overall conversion rate: deposits as percentage of leads
  double get overallConversionRate => leads > 0 ? (deposits / leads) * 100 : 0;
  
  /// Profit margin percentage: profit as percentage of total investment
  double get profitMargin {
    final totalInvestment = effectiveSpend + productExpenseCost;
    return totalInvestment > 0 ? (actualProfit / totalInvestment) * 100 : 0;
  }
  
  /// CPL as percentage of spend
  double get cplPercentage => effectiveSpend > 0 ? (cpl / effectiveSpend) * 100 : 0;
  
  /// CPB as percentage of spend
  double get cpbPercentage => effectiveSpend > 0 ? (cpb / effectiveSpend) * 100 : 0;
  
  /// CPA as percentage of spend
  double get cpaPercentage => effectiveSpend > 0 ? (cpa / effectiveSpend) * 100 : 0;

  /// Get ad name for display
  String get adName => cost.adName.isNotEmpty ? cost.adName : cost.adId;

  /// Get campaign name for display
  String get campaignName => cost.campaignName;

  /// Get budget (or effective spend)
  double get budget => effectiveSpend;

  @override
  String toString() {
    return 'AdPerformanceWithMetrics(ad: $adName, leads: $leads, bookings: $bookings, deposits: $deposits, profit: R$actualProfit)';
  }
}

