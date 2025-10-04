import 'package:cloud_firestore/cloud_firestore.dart';

/// Country Analytics Model - Represents aggregated analytics in country_analytics collection
/// This matches the COUNTRY_ANALYTICS collection structure from DATABASE_README.md
class CountryAnalytics {
  final String id; // Country code (e.g., 'USA', 'RSA')
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
  final String calculatedBy; // Admin user ID

  CountryAnalytics({
    required this.id,
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

  /// Create from Firestore document
  factory CountryAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse provinces data
    final provincesData = data['provinces'] as Map<String, dynamic>? ?? {};
    final provinces = <String, ProvinceStats>{};
    
    provincesData.forEach((provinceName, provinceData) {
      if (provinceData is Map<String, dynamic>) {
        provinces[provinceName] = ProvinceStats.fromMap(provinceData);
      }
    });
    
    return CountryAnalytics(
      id: doc.id,
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
      averageSessionsPerPractitioner: (data['averageSessionsPerPractitioner'] ?? 0).toDouble(),
      averagePatientsPerPractitioner: (data['averagePatientsPerPractitioner'] ?? 0).toDouble(),
      averageWoundHealingRate: (data['averageWoundHealingRate'] ?? 0).toDouble(),
      provinces: provinces,
      lastCalculated: (data['lastCalculated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      calculatedBy: data['calculatedBy'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final provincesData = <String, dynamic>{};
    provinces.forEach((provinceName, provinceStats) {
      provincesData[provinceName] = provinceStats.toMap();
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
      'provinces': provincesData,
      'lastCalculated': Timestamp.fromDate(lastCalculated),
      'calculatedBy': calculatedBy,
    };
  }

  /// Copy with new values
  CountryAnalytics copyWith({
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
      id: id,
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

  // Getters
  double get practitionerGrowthRate {
    if (totalPractitioners == 0) return 0.0;
    return (approvedThisMonth / totalPractitioners) * 100;
  }

  double get patientGrowthRate {
    if (totalPatients == 0) return 0.0;
    return (newPatientsThisMonth / totalPatients) * 100;
  }

  double get sessionGrowthRate {
    if (totalSessions == 0) return 0.0;
    return (sessionsThisMonth / totalSessions) * 100;
  }

  double get approvalRate {
    final totalProcessed = approvedThisMonth + rejectedThisMonth;
    if (totalProcessed == 0) return 0.0;
    return (approvedThisMonth / totalProcessed) * 100;
  }

  /// Get country flag emoji
  String get flagEmoji {
    switch (id) {
      case 'USA':
        return '🇺🇸';
      case 'RSA':
        return '🇿🇦';
      default:
        return '🌍';
    }
  }

  /// Check if data is stale (older than 24 hours)
  bool get isStale {
    final now = DateTime.now();
    return now.difference(lastCalculated).inHours > 24;
  }
}

/// Province Statistics for geographic distribution
class ProvinceStats {
  final int totalPractitioners;
  final int totalPatients;
  final int totalSessions;

  ProvinceStats({
    required this.totalPractitioners,
    required this.totalPatients,
    required this.totalSessions,
  });

  factory ProvinceStats.fromMap(Map<String, dynamic> data) {
    return ProvinceStats(
      totalPractitioners: data['totalPractitioners'] ?? 0,
      totalPatients: data['totalPatients'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPractitioners': totalPractitioners,
      'totalPatients': totalPatients,
      'totalSessions': totalSessions,
    };
  }

  // Getters
  double get averagePatientsPerPractitioner {
    if (totalPractitioners == 0) return 0.0;
    return totalPatients / totalPractitioners;
  }

  double get averageSessionsPerPractitioner {
    if (totalPractitioners == 0) return 0.0;
    return totalSessions / totalPractitioners;
  }

  double get averageSessionsPerPatient {
    if (totalPatients == 0) return 0.0;
    return totalSessions / totalPatients;
  }
}

/// Extension for analytics calculations
extension CountryAnalyticsCalculations on CountryAnalytics {
  /// Calculate total province practitioners
  int get totalProvincePractitioners {
    return provinces.values.fold(0, (sum, province) => sum + province.totalPractitioners);
  }

  /// Calculate total province patients
  int get totalProvincePatients {
    return provinces.values.fold(0, (sum, province) => sum + province.totalPatients);
  }

  /// Calculate total province sessions
  int get totalProvinceSessions {
    return provinces.values.fold(0, (sum, province) => sum + province.totalSessions);
  }

  /// Get top performing provinces by practitioners
  List<MapEntry<String, ProvinceStats>> getTopProvincesByPractitioners({int limit = 3}) {
    final sortedProvinces = provinces.entries.toList()
      ..sort((a, b) => b.value.totalPractitioners.compareTo(a.value.totalPractitioners));
    return sortedProvinces.take(limit).toList();
  }

  /// Get top performing provinces by patients
  List<MapEntry<String, ProvinceStats>> getTopProvincesByPatients({int limit = 3}) {
    final sortedProvinces = provinces.entries.toList()
      ..sort((a, b) => b.value.totalPatients.compareTo(a.value.totalPatients));
    return sortedProvinces.take(limit).toList();
  }

  /// Get top performing provinces by sessions
  List<MapEntry<String, ProvinceStats>> getTopProvincesBySessions({int limit = 3}) {
    final sortedProvinces = provinces.entries.toList()
      ..sort((a, b) => b.value.totalSessions.compareTo(a.value.totalSessions));
    return sortedProvinces.take(limit).toList();
  }

  /// Calculate efficiency metrics
  Map<String, double> get efficiencyMetrics {
    return {
      'practitioners_per_1000_patients': totalPractitioners / (totalPatients / 1000),
      'sessions_per_practitioner_per_month': sessionsThisMonth / (activePractitioners > 0 ? activePractitioners : 1),
      'patient_engagement_rate': (sessionsThisMonth / (totalPatients > 0 ? totalPatients : 1)) * 100,
      'practitioner_utilization_rate': (activePractitioners / (totalPractitioners > 0 ? totalPractitioners : 1)) * 100,
    };
  }
}
