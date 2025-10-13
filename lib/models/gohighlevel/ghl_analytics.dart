/// GoHighLevel Analytics model for tracking advertisement performance
class GHLAnalytics {
  final String pipelineId;
  final String pipelineName;
  final DateTime calculatedAt;
  final GHLLeadMetrics leadMetrics;
  final GHLSalesMetrics salesMetrics;
  final GHLAppointmentMetrics appointmentMetrics;
  final GHLFinancialMetrics financialMetrics;
  final List<GHLSalesAgentMetrics> salesAgentMetrics;

  GHLAnalytics({
    required this.pipelineId,
    required this.pipelineName,
    required this.calculatedAt,
    required this.leadMetrics,
    required this.salesMetrics,
    required this.appointmentMetrics,
    required this.financialMetrics,
    this.salesAgentMetrics = const [],
  });

  factory GHLAnalytics.fromJson(Map<String, dynamic> json) {
    return GHLAnalytics(
      pipelineId: json['pipelineId']?.toString() ?? '',
      pipelineName: json['pipelineName']?.toString() ?? '',
      calculatedAt: json['calculatedAt'] != null 
          ? DateTime.tryParse(json['calculatedAt']) ?? DateTime.now()
          : DateTime.now(),
      leadMetrics: GHLLeadMetrics.fromJson(json['leadMetrics'] ?? {}),
      salesMetrics: GHLSalesMetrics.fromJson(json['salesMetrics'] ?? {}),
      appointmentMetrics: GHLAppointmentMetrics.fromJson(json['appointmentMetrics'] ?? {}),
      financialMetrics: GHLFinancialMetrics.fromJson(json['financialMetrics'] ?? {}),
      salesAgentMetrics: (json['salesAgentMetrics'] as List?)
          ?.map((agent) => GHLSalesAgentMetrics.fromJson(agent))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pipelineId': pipelineId,
      'pipelineName': pipelineName,
      'calculatedAt': calculatedAt.toIso8601String(),
      'leadMetrics': leadMetrics.toJson(),
      'salesMetrics': salesMetrics.toJson(),
      'appointmentMetrics': appointmentMetrics.toJson(),
      'financialMetrics': financialMetrics.toJson(),
      'salesAgentMetrics': salesAgentMetrics.map((agent) => agent.toJson()).toList(),
    };
  }
}

/// Lead-specific metrics
class GHLLeadMetrics {
  final int totalLeads;
  final int hqlLeads;
  final int aveLeads;
  final int otherLeads;
  final double hqlPercentage;
  final double aveLeadPercentage;
  final int newLeadsToday;
  final int newLeadsThisWeek;
  final int newLeadsThisMonth;

  GHLLeadMetrics({
    required this.totalLeads,
    required this.hqlLeads,
    required this.aveLeads,
    required this.otherLeads,
    required this.hqlPercentage,
    required this.aveLeadPercentage,
    required this.newLeadsToday,
    required this.newLeadsThisWeek,
    required this.newLeadsThisMonth,
  });

  factory GHLLeadMetrics.fromJson(Map<String, dynamic> json) {
    return GHLLeadMetrics(
      totalLeads: json['totalLeads']?.toInt() ?? 0,
      hqlLeads: json['hqlLeads']?.toInt() ?? 0,
      aveLeads: json['aveLeads']?.toInt() ?? 0,
      otherLeads: json['otherLeads']?.toInt() ?? 0,
      hqlPercentage: json['hqlPercentage']?.toDouble() ?? 0.0,
      aveLeadPercentage: json['aveLeadPercentage']?.toDouble() ?? 0.0,
      newLeadsToday: json['newLeadsToday']?.toInt() ?? 0,
      newLeadsThisWeek: json['newLeadsThisWeek']?.toInt() ?? 0,
      newLeadsThisMonth: json['newLeadsThisMonth']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalLeads': totalLeads,
      'hqlLeads': hqlLeads,
      'aveLeads': aveLeads,
      'otherLeads': otherLeads,
      'hqlPercentage': hqlPercentage,
      'aveLeadPercentage': aveLeadPercentage,
      'newLeadsToday': newLeadsToday,
      'newLeadsThisWeek': newLeadsThisWeek,
      'newLeadsThisMonth': newLeadsThisMonth,
    };
  }
}

/// Sales-specific metrics
class GHLSalesMetrics {
  final int totalSales;
  final int noSales;
  final double saleConversionRate;
  final double averageSaleValue;
  final double totalSaleValue;
  final int salesToday;
  final int salesThisWeek;
  final int salesThisMonth;

  GHLSalesMetrics({
    required this.totalSales,
    required this.noSales,
    required this.saleConversionRate,
    required this.averageSaleValue,
    required this.totalSaleValue,
    required this.salesToday,
    required this.salesThisWeek,
    required this.salesThisMonth,
  });

  factory GHLSalesMetrics.fromJson(Map<String, dynamic> json) {
    return GHLSalesMetrics(
      totalSales: json['totalSales']?.toInt() ?? 0,
      noSales: json['noSales']?.toInt() ?? 0,
      saleConversionRate: json['saleConversionRate']?.toDouble() ?? 0.0,
      averageSaleValue: json['averageSaleValue']?.toDouble() ?? 0.0,
      totalSaleValue: json['totalSaleValue']?.toDouble() ?? 0.0,
      salesToday: json['salesToday']?.toInt() ?? 0,
      salesThisWeek: json['salesThisWeek']?.toInt() ?? 0,
      salesThisMonth: json['salesThisMonth']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSales': totalSales,
      'noSales': noSales,
      'saleConversionRate': saleConversionRate,
      'averageSaleValue': averageSaleValue,
      'totalSaleValue': totalSaleValue,
      'salesToday': salesToday,
      'salesThisWeek': salesThisWeek,
      'salesThisMonth': salesThisMonth,
    };
  }
}

/// Appointment-specific metrics
class GHLAppointmentMetrics {
  final int totalAppointments;
  final int noAppointments;
  final int optedIn;
  final int noShows;
  final double appointmentRate;
  final double optInRate;
  final double noShowRate;
  final int appointmentsToday;
  final int appointmentsThisWeek;
  final int appointmentsThisMonth;

  GHLAppointmentMetrics({
    required this.totalAppointments,
    required this.noAppointments,
    required this.optedIn,
    required this.noShows,
    required this.appointmentRate,
    required this.optInRate,
    required this.noShowRate,
    required this.appointmentsToday,
    required this.appointmentsThisWeek,
    required this.appointmentsThisMonth,
  });

  factory GHLAppointmentMetrics.fromJson(Map<String, dynamic> json) {
    return GHLAppointmentMetrics(
      totalAppointments: json['totalAppointments']?.toInt() ?? 0,
      noAppointments: json['noAppointments']?.toInt() ?? 0,
      optedIn: json['optedIn']?.toInt() ?? 0,
      noShows: json['noShows']?.toInt() ?? 0,
      appointmentRate: json['appointmentRate']?.toDouble() ?? 0.0,
      optInRate: json['optInRate']?.toDouble() ?? 0.0,
      noShowRate: json['noShowRate']?.toDouble() ?? 0.0,
      appointmentsToday: json['appointmentsToday']?.toInt() ?? 0,
      appointmentsThisWeek: json['appointmentsThisWeek']?.toInt() ?? 0,
      appointmentsThisMonth: json['appointmentsThisMonth']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalAppointments': totalAppointments,
      'noAppointments': noAppointments,
      'optedIn': optedIn,
      'noShows': noShows,
      'appointmentRate': appointmentRate,
      'optInRate': optInRate,
      'noShowRate': noShowRate,
      'appointmentsToday': appointmentsToday,
      'appointmentsThisWeek': appointmentsThisWeek,
      'appointmentsThisMonth': appointmentsThisMonth,
    };
  }
}

/// Financial metrics
class GHLFinancialMetrics {
  final int totalDeposits;
  final double totalDepositAmount;
  final double averageDepositAmount;
  final int totalInstallations;
  final double installationRate;
  final double totalCashCollected;
  final double averageCashPerLead;
  final double depositsToday;
  final double depositsThisWeek;
  final double depositsThisMonth;
  final double cashCollectedToday;
  final double cashCollectedThisWeek;
  final double cashCollectedThisMonth;

  GHLFinancialMetrics({
    required this.totalDeposits,
    required this.totalDepositAmount,
    required this.averageDepositAmount,
    required this.totalInstallations,
    required this.installationRate,
    required this.totalCashCollected,
    required this.averageCashPerLead,
    required this.depositsToday,
    required this.depositsThisWeek,
    required this.depositsThisMonth,
    required this.cashCollectedToday,
    required this.cashCollectedThisWeek,
    required this.cashCollectedThisMonth,
  });

  factory GHLFinancialMetrics.fromJson(Map<String, dynamic> json) {
    return GHLFinancialMetrics(
      totalDeposits: json['totalDeposits']?.toInt() ?? 0,
      totalDepositAmount: json['totalDepositAmount']?.toDouble() ?? 0.0,
      averageDepositAmount: json['averageDepositAmount']?.toDouble() ?? 0.0,
      totalInstallations: json['totalInstallations']?.toInt() ?? 0,
      installationRate: json['installationRate']?.toDouble() ?? 0.0,
      totalCashCollected: json['totalCashCollected']?.toDouble() ?? 0.0,
      averageCashPerLead: json['averageCashPerLead']?.toDouble() ?? 0.0,
      depositsToday: json['depositsToday']?.toDouble() ?? 0.0,
      depositsThisWeek: json['depositsThisWeek']?.toDouble() ?? 0.0,
      depositsThisMonth: json['depositsThisMonth']?.toDouble() ?? 0.0,
      cashCollectedToday: json['cashCollectedToday']?.toDouble() ?? 0.0,
      cashCollectedThisWeek: json['cashCollectedThisWeek']?.toDouble() ?? 0.0,
      cashCollectedThisMonth: json['cashCollectedThisMonth']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDeposits': totalDeposits,
      'totalDepositAmount': totalDepositAmount,
      'averageDepositAmount': averageDepositAmount,
      'totalInstallations': totalInstallations,
      'installationRate': installationRate,
      'totalCashCollected': totalCashCollected,
      'averageCashPerLead': averageCashPerLead,
      'depositsToday': depositsToday,
      'depositsThisWeek': depositsThisWeek,
      'depositsThisMonth': depositsThisMonth,
      'cashCollectedToday': cashCollectedToday,
      'cashCollectedThisWeek': cashCollectedThisWeek,
      'cashCollectedThisMonth': cashCollectedThisMonth,
    };
  }
}

/// Sales agent performance metrics
class GHLSalesAgentMetrics {
  final String agentId;
  final String agentName;
  final int totalLeads;
  final int hqlLeads;
  final int aveLeads;
  final int appointments;
  final int sales;
  final double saleConversionRate;
  final double totalSaleValue;
  final double totalDeposits;
  final double totalCashCollected;
  final int installations;

  GHLSalesAgentMetrics({
    required this.agentId,
    required this.agentName,
    required this.totalLeads,
    required this.hqlLeads,
    required this.aveLeads,
    required this.appointments,
    required this.sales,
    required this.saleConversionRate,
    required this.totalSaleValue,
    required this.totalDeposits,
    required this.totalCashCollected,
    required this.installations,
  });

  factory GHLSalesAgentMetrics.fromJson(Map<String, dynamic> json) {
    return GHLSalesAgentMetrics(
      agentId: json['agentId']?.toString() ?? '',
      agentName: json['agentName']?.toString() ?? '',
      totalLeads: json['totalLeads']?.toInt() ?? 0,
      hqlLeads: json['hqlLeads']?.toInt() ?? 0,
      aveLeads: json['aveLeads']?.toInt() ?? 0,
      appointments: json['appointments']?.toInt() ?? 0,
      sales: json['sales']?.toInt() ?? 0,
      saleConversionRate: json['saleConversionRate']?.toDouble() ?? 0.0,
      totalSaleValue: json['totalSaleValue']?.toDouble() ?? 0.0,
      totalDeposits: json['totalDeposits']?.toDouble() ?? 0.0,
      totalCashCollected: json['totalCashCollected']?.toDouble() ?? 0.0,
      installations: json['installations']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'agentName': agentName,
      'totalLeads': totalLeads,
      'hqlLeads': hqlLeads,
      'aveLeads': aveLeads,
      'appointments': appointments,
      'sales': sales,
      'saleConversionRate': saleConversionRate,
      'totalSaleValue': totalSaleValue,
      'totalDeposits': totalDeposits,
      'totalCashCollected': totalCashCollected,
      'installations': installations,
    };
  }
}
