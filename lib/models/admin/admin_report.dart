/// Report Model for MedWave Admin System
/// 
/// Represents marketing and analytics reports that can be generated
/// and customized by administrators.

enum ReportType { 
  providerPerformance, 
  patientProgress, 
  revenueAnalysis, 
  treatmentEfficacy 
}

class AdminReport {
  final String id;
  final String title;
  final String description;
  final ReportType type;
  final DateTime createdAt;
  final DateTime? lastModified;
  final String createdBy;
  final List<ReportMetric> metrics;
  final Map<String, dynamic> filters;
  final String template;
  final bool isPublished;

  AdminReport({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.lastModified,
    required this.createdBy,
    this.metrics = const [],
    this.filters = const {},
    this.template = 'default',
    this.isPublished = false,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    return AdminReport(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ReportType.values.firstWhere(
        (e) => e.toString() == 'ReportType.${json['type']}',
        orElse: () => ReportType.providerPerformance,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified']) 
          : null,
      createdBy: json['createdBy'],
      metrics: (json['metrics'] as List?)
          ?.map((metric) => ReportMetric.fromJson(metric))
          .toList() ?? [],
      filters: Map<String, dynamic>.from(json['filters'] ?? {}),
      template: json['template'] ?? 'default',
      isPublished: json['isPublished'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
      'createdBy': createdBy,
      'metrics': metrics.map((metric) => metric.toJson()).toList(),
      'filters': filters,
      'template': template,
      'isPublished': isPublished,
    };
  }

  AdminReport copyWith({
    String? id,
    String? title,
    String? description,
    ReportType? type,
    DateTime? createdAt,
    DateTime? lastModified,
    String? createdBy,
    List<ReportMetric>? metrics,
    Map<String, dynamic>? filters,
    String? template,
    bool? isPublished,
  }) {
    return AdminReport(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      createdBy: createdBy ?? this.createdBy,
      metrics: metrics ?? this.metrics,
      filters: filters ?? this.filters,
      template: template ?? this.template,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}

class ReportMetric {
  final String id;
  final String name;
  final String description;
  final String dataSource;
  final String aggregationType; // sum, average, count, etc.
  final String displayType; // chart, table, number, etc.
  final Map<String, dynamic> configuration;
  final int order;

  ReportMetric({
    required this.id,
    required this.name,
    required this.description,
    required this.dataSource,
    required this.aggregationType,
    required this.displayType,
    this.configuration = const {},
    this.order = 0,
  });

  factory ReportMetric.fromJson(Map<String, dynamic> json) {
    return ReportMetric(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      dataSource: json['dataSource'],
      aggregationType: json['aggregationType'],
      displayType: json['displayType'],
      configuration: Map<String, dynamic>.from(json['configuration'] ?? {}),
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'dataSource': dataSource,
      'aggregationType': aggregationType,
      'displayType': displayType,
      'configuration': configuration,
      'order': order,
    };
  }

  ReportMetric copyWith({
    String? id,
    String? name,
    String? description,
    String? dataSource,
    String? aggregationType,
    String? displayType,
    Map<String, dynamic>? configuration,
    int? order,
  }) {
    return ReportMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dataSource: dataSource ?? this.dataSource,
      aggregationType: aggregationType ?? this.aggregationType,
      displayType: displayType ?? this.displayType,
      configuration: configuration ?? this.configuration,
      order: order ?? this.order,
    );
  }
}

// Predefined metrics for the report builder
class PredefinedMetrics {
  static final List<ReportMetric> availableMetrics = [
    ReportMetric(
      id: 'total_providers',
      name: 'Total Providers',
      description: 'Total number of registered providers',
      dataSource: 'providers',
      aggregationType: 'count',
      displayType: 'number',
    ),
    ReportMetric(
      id: 'active_providers',
      name: 'Active Providers',
      description: 'Number of providers with active patients',
      dataSource: 'providers',
      aggregationType: 'count',
      displayType: 'number',
      configuration: {'filter': 'hasActivePatients'},
    ),
    ReportMetric(
      id: 'total_patients',
      name: 'Total Patients',
      description: 'Total number of patients across all providers',
      dataSource: 'patients',
      aggregationType: 'count',
      displayType: 'number',
    ),
    ReportMetric(
      id: 'average_patient_progress',
      name: 'Average Patient Progress',
      description: 'Average progress percentage across all patients',
      dataSource: 'patients',
      aggregationType: 'average',
      displayType: 'number',
      configuration: {'field': 'overallProgress'},
    ),
    ReportMetric(
      id: 'treatment_success_rate',
      name: 'Treatment Success Rate',
      description: 'Percentage of patients with >50% progress',
      dataSource: 'patients',
      aggregationType: 'percentage',
      displayType: 'number',
      configuration: {'threshold': 50.0},
    ),
    ReportMetric(
      id: 'revenue_by_provider',
      name: 'Revenue by Provider',
      description: 'Monthly revenue breakdown by provider',
      dataSource: 'providers',
      aggregationType: 'sum',
      displayType: 'chart',
      configuration: {'chartType': 'bar', 'field': 'monthlyRevenue'},
    ),
    ReportMetric(
      id: 'patient_progress_timeline',
      name: 'Patient Progress Timeline',
      description: 'Patient progress over time',
      dataSource: 'patients',
      aggregationType: 'timeSeries',
      displayType: 'chart',
      configuration: {'chartType': 'line', 'field': 'overallProgress'},
    ),
  ];
}
