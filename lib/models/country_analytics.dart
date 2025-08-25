import 'package:cloud_firestore/cloud_firestore.dart';

class ProvinceStats {
  final int totalPractitioners;
  final int totalPatients;
  final int totalSessions;

  ProvinceStats({
    required this.totalPractitioners,
    required this.totalPatients,
    required this.totalSessions,
  });

  factory ProvinceStats.fromMap(Map<String, dynamic> map) {
    return ProvinceStats(
      totalPractitioners: map['totalPractitioners'] ?? 0,
      totalPatients: map['totalPatients'] ?? 0,
      totalSessions: map['totalSessions'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPractitioners': totalPractitioners,
      'totalPatients': totalPatients,
      'totalSessions': totalSessions,
    };
  }

  ProvinceStats copyWith({
    int? totalPractitioners,
    int? totalPatients,
    int? totalSessions,
  }) {
    return ProvinceStats(
      totalPractitioners: totalPractitioners ?? this.totalPractitioners,
      totalPatients: totalPatients ?? this.totalPatients,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }
}

class CountryAnalytics {
  final String countryCode;
  final String countryName;
  
  // Practitioner Statistics
  final int totalPractitioners;
  final int activePractitioners; // Last 30 days
  final int pendingApplications;
  final int approvedThisMonth;
  final int rejectedThisMonth;
  
  // Patient Statistics
  final int totalPatients;
  final int newPatientsThisMonth;
  final int totalSessions;
  final int sessionsThisMonth;
  
  // Performance Metrics
  final double averageSessionsPerPractitioner;
  final double averagePatientsPerPractitioner;
  final double averageWoundHealingRate;
  
  // Geographic Distribution
  final Map<String, ProvinceStats> provinces;
  
  // Last Updated
  final DateTime lastCalculated;
  final String calculatedBy;

  CountryAnalytics({
    required this.countryCode,
    required this.countryName,
    required this.totalPractitioners,
    required this.activePractitioners,
    required this.pendingApplications,
    required this.approvedThisMonth,
    required this.rejectedThisMonth,
    required this.totalPatients,
    required this.newPatientsThisMonth,
    required this.totalSessions,
    required this.sessionsThisMonth,
    required this.averageSessionsPerPractitioner,
    required this.averagePatientsPerPractitioner,
    required this.averageWoundHealingRate,
    required this.provinces,
    required this.lastCalculated,
    required this.calculatedBy,
  });

  // Calculated properties
  double get practitionerApprovalRate {
    final totalApplications = approvedThisMonth + rejectedThisMonth;
    if (totalApplications == 0) return 0.0;
    return (approvedThisMonth / totalApplications) * 100;
  }

  double get practitionerActivityRate {
    if (totalPractitioners == 0) return 0.0;
    return (activePractitioners / totalPractitioners) * 100;
  }

  double get monthlyGrowthRate {
    if (totalPractitioners == 0) return 0.0;
    return (approvedThisMonth / totalPractitioners) * 100;
  }

  List<String> get topProvinces {
    final sortedProvinces = provinces.entries.toList()
      ..sort((a, b) => b.value.totalPractitioners.compareTo(a.value.totalPractitioners));
    return sortedProvinces.take(5).map((e) => e.key).toList();
  }

  factory CountryAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse provinces map
    final provincesMap = data['provinces'] as Map<String, dynamic>? ?? {};
    final provinces = <String, ProvinceStats>{};
    
    provincesMap.forEach((key, value) {
      provinces[key] = ProvinceStats.fromMap(value as Map<String, dynamic>);
    });
    
    return CountryAnalytics(
      countryCode: doc.id,
      countryName: data['countryName'] ?? '',
      totalPractitioners: data['totalPractitioners'] ?? 0,
      activePractitioners: data['activePractitioners'] ?? 0,
      pendingApplications: data['pendingApplications'] ?? 0,
      approvedThisMonth: data['approvedThisMonth'] ?? 0,
      rejectedThisMonth: data['rejectedThisMonth'] ?? 0,
      totalPatients: data['totalPatients'] ?? 0,
      newPatientsThisMonth: data['newPatientsThisMonth'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      sessionsThisMonth: data['sessionsThisMonth'] ?? 0,
      averageSessionsPerPractitioner: data['averageSessionsPerPractitioner']?.toDouble() ?? 0.0,
      averagePatientsPerPractitioner: data['averagePatientsPerPractitioner']?.toDouble() ?? 0.0,
      averageWoundHealingRate: data['averageWoundHealingRate']?.toDouble() ?? 0.0,
      provinces: provinces,
      lastCalculated: data['lastCalculated']?.toDate() ?? DateTime.now(),
      calculatedBy: data['calculatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    final provincesMap = <String, dynamic>{};
    provinces.forEach((key, value) {
      provincesMap[key] = value.toMap();
    });

    return {
      'countryName': countryName,
      'totalPractitioners': totalPractitioners,
      'activePractitioners': activePractitioners,
      'pendingApplications': pendingApplications,
      'approvedThisMonth': approvedThisMonth,
      'rejectedThisMonth': rejectedThisMonth,
      'totalPatients': totalPatients,
      'newPatientsThisMonth': newPatientsThisMonth,
      'totalSessions': totalSessions,
      'sessionsThisMonth': sessionsThisMonth,
      'averageSessionsPerPractitioner': averageSessionsPerPractitioner,
      'averagePatientsPerPractitioner': averagePatientsPerPractitioner,
      'averageWoundHealingRate': averageWoundHealingRate,
      'provinces': provincesMap,
      'lastCalculated': Timestamp.fromDate(lastCalculated),
      'calculatedBy': calculatedBy,
    };
  }

  CountryAnalytics copyWith({
    String? countryCode,
    String? countryName,
    int? totalPractitioners,
    int? activePractitioners,
    int? pendingApplications,
    int? approvedThisMonth,
    int? rejectedThisMonth,
    int? totalPatients,
    int? newPatientsThisMonth,
    int? totalSessions,
    int? sessionsThisMonth,
    double? averageSessionsPerPractitioner,
    double? averagePatientsPerPractitioner,
    double? averageWoundHealingRate,
    Map<String, ProvinceStats>? provinces,
    DateTime? lastCalculated,
    String? calculatedBy,
  }) {
    return CountryAnalytics(
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      totalPractitioners: totalPractitioners ?? this.totalPractitioners,
      activePractitioners: activePractitioners ?? this.activePractitioners,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      approvedThisMonth: approvedThisMonth ?? this.approvedThisMonth,
      rejectedThisMonth: rejectedThisMonth ?? this.rejectedThisMonth,
      totalPatients: totalPatients ?? this.totalPatients,
      newPatientsThisMonth: newPatientsThisMonth ?? this.newPatientsThisMonth,
      totalSessions: totalSessions ?? this.totalSessions,
      sessionsThisMonth: sessionsThisMonth ?? this.sessionsThisMonth,
      averageSessionsPerPractitioner: averageSessionsPerPractitioner ?? this.averageSessionsPerPractitioner,
      averagePatientsPerPractitioner: averagePatientsPerPractitioner ?? this.averagePatientsPerPractitioner,
      averageWoundHealingRate: averageWoundHealingRate ?? this.averageWoundHealingRate,
      provinces: provinces ?? this.provinces,
      lastCalculated: lastCalculated ?? this.lastCalculated,
      calculatedBy: calculatedBy ?? this.calculatedBy,
    );
  }
}
