class ProgressMetrics {
  final String patientId;
  final DateTime calculatedAt;
  final double painReductionPercentage;
  final double weightChangePercentage;
  final double woundHealingPercentage;
  final int totalSessions;
  final List<ProgressDataPoint> painHistory;
  final List<ProgressDataPoint> weightHistory;
  final List<ProgressDataPoint> woundSizeHistory;
  final bool hasSignificantImprovement;
  final String improvementSummary;

  const ProgressMetrics({
    required this.patientId,
    required this.calculatedAt,
    required this.painReductionPercentage,
    required this.weightChangePercentage,
    required this.woundHealingPercentage,
    required this.totalSessions,
    required this.painHistory,
    required this.weightHistory,
    required this.woundSizeHistory,
    required this.hasSignificantImprovement,
    required this.improvementSummary,
  });

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'calculatedAt': calculatedAt.toIso8601String(),
      'painReductionPercentage': painReductionPercentage,
      'weightChangePercentage': weightChangePercentage,
      'woundHealingPercentage': woundHealingPercentage,
      'totalSessions': totalSessions,
      'painHistory': painHistory.map((p) => p.toJson()).toList(),
      'weightHistory': weightHistory.map((p) => p.toJson()).toList(),
      'woundSizeHistory': woundSizeHistory.map((p) => p.toJson()).toList(),
      'hasSignificantImprovement': hasSignificantImprovement,
      'improvementSummary': improvementSummary,
    };
  }

  factory ProgressMetrics.fromJson(Map<String, dynamic> json) {
    return ProgressMetrics(
      patientId: json['patientId'],
      calculatedAt: DateTime.parse(json['calculatedAt']),
      painReductionPercentage: json['painReductionPercentage'],
      weightChangePercentage: json['weightChangePercentage'],
      woundHealingPercentage: json['woundHealingPercentage'],
      totalSessions: json['totalSessions'],
      painHistory: (json['painHistory'] as List).map((p) => ProgressDataPoint.fromJson(p)).toList(),
      weightHistory: (json['weightHistory'] as List).map((p) => ProgressDataPoint.fromJson(p)).toList(),
      woundSizeHistory: (json['woundSizeHistory'] as List).map((p) => ProgressDataPoint.fromJson(p)).toList(),
      hasSignificantImprovement: json['hasSignificantImprovement'],
      improvementSummary: json['improvementSummary'],
    );
  }
}

class ProgressDataPoint {
  final DateTime date;
  final double value;
  final int sessionNumber;
  final String? notes;

  const ProgressDataPoint({
    required this.date,
    required this.value,
    required this.sessionNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'value': value,
      'sessionNumber': sessionNumber,
      'notes': notes,
    };
  }

  factory ProgressDataPoint.fromJson(Map<String, dynamic> json) {
    return ProgressDataPoint(
      date: DateTime.parse(json['date']),
      value: json['value'],
      sessionNumber: json['sessionNumber'],
      notes: json['notes'],
    );
  }
}

class ReportData {
  final String patientId;
  final String patientName;
  final DateTime generatedAt;
  final DateTime treatmentStartDate;
  final DateTime treatmentEndDate;
  final ProgressMetrics metrics;
  final List<String> keyFindings;
  final List<String> recommendations;
  final String reportType;

  const ReportData({
    required this.patientId,
    required this.patientName,
    required this.generatedAt,
    required this.treatmentStartDate,
    required this.treatmentEndDate,
    required this.metrics,
    required this.keyFindings,
    required this.recommendations,
    required this.reportType,
  });

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'generatedAt': generatedAt.toIso8601String(),
      'treatmentStartDate': treatmentStartDate.toIso8601String(),
      'treatmentEndDate': treatmentEndDate.toIso8601String(),
      'metrics': metrics.toJson(),
      'keyFindings': keyFindings,
      'recommendations': recommendations,
      'reportType': reportType,
    };
  }

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      patientId: json['patientId'],
      patientName: json['patientName'],
      generatedAt: DateTime.parse(json['generatedAt']),
      treatmentStartDate: DateTime.parse(json['treatmentStartDate']),
      treatmentEndDate: DateTime.parse(json['treatmentEndDate']),
      metrics: ProgressMetrics.fromJson(json['metrics']),
      keyFindings: List<String>.from(json['keyFindings']),
      recommendations: List<String>.from(json['recommendations']),
      reportType: json['reportType'],
    );
  }
}
