import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../config/api_keys.dart';
import '../../models/gohighlevel/ghl_lead.dart';
import '../../models/gohighlevel/ghl_pipeline.dart';
import '../../models/gohighlevel/ghl_analytics.dart';

/// GoHighLevel CRM API Service
/// Handles all API interactions with GoHighLevel CRM system via proxy server
class GoHighLevelService {
  // Use proxy server for web deployment to bypass CORS
  static const String _baseUrl = ApiKeys.goHighLevelProxyUrl;
  
  // API Endpoints (proxy server handles the GoHighLevel API key)
  static const String _contactsEndpoint = '/contacts';
  static const String _pipelinesEndpoint = '/pipelines';
  static const String _opportunitiesEndpoint = '/opportunities';
  static const String _campaignAnalyticsEndpoint = '/analytics/campaign-performance';
  
  /// HTTP client with default headers for proxy server
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };


  /// Get all pipelines
  static Future<List<GHLPipeline>> getPipelines() async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching pipelines...');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_pipelinesEndpoint'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List pipelinesJson = data['pipelines'] ?? [];
        
        final pipelines = pipelinesJson
            .map((json) => GHLPipeline.fromJson(json))
            .toList();

        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded ${pipelines.length} pipelines from API');
        }

        return pipelines;
      } else {
        throw GHLApiException(
          'Failed to fetch pipelines: ${response.statusCode}',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch pipelines: $e');
      }
      rethrow;
    }
  }

  /// Get the Erich Pipeline specifically
  static Future<GHLPipeline?> getErichPipeline() async {
    try {
      final pipelines = await getPipelines();
      
      // Find the Erich Pipeline
      final erichPipeline = pipelines.where((p) => p.isErichPipeline).firstOrNull;
      
      if (kDebugMode) {
        if (erichPipeline != null) {
          print('✅ GHL SERVICE: Found Erich Pipeline: ${erichPipeline.name}');
        } else {
          print('⚠️ GHL SERVICE: Erich Pipeline not found');
        }
      }
      
      return erichPipeline;
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to get Erich Pipeline: $e');
      }
      rethrow;
    }
  }

  /// Get contacts/leads from a specific pipeline
  static Future<List<GHLLead>> getLeadsByPipeline(String pipelineId, {
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching leads for pipeline: $pipelineId');
      }

      final queryParams = {
        'pipelineId': pipelineId,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_contactsEndpoint')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List contactsJson = data['contacts'] ?? [];
        
        final leads = contactsJson
            .map((json) => _mapContactToLead(json))
            .toList();

        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded ${leads.length} leads from pipeline');
        }

        return leads;
      } else {
        throw GHLApiException(
          'Failed to fetch leads: ${response.statusCode}',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch leads: $e');
      }
      rethrow;
    }
  }

  /// Get opportunities (sales pipeline data)
  static Future<List<Map<String, dynamic>>> getOpportunities(String pipelineId) async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching opportunities for pipeline: $pipelineId');
      }

      final queryParams = {
        'pipelineId': pipelineId,
      };

      final uri = Uri.parse('$_baseUrl$_opportunitiesEndpoint')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List opportunities = data['opportunities'] ?? [];

        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded ${opportunities.length} opportunities');
        }

        return opportunities.cast<Map<String, dynamic>>();
      } else {
        throw GHLApiException(
          'Failed to fetch opportunities: ${response.statusCode}',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch opportunities: $e');
      }
      rethrow;
    }
  }

  /// Get Erich Pipeline leads specifically
  static Future<List<GHLLead>> getErichPipelineLeads() async {
    try {
      final erichPipeline = await getErichPipeline();
      if (erichPipeline == null) {
        throw GHLApiException('Erich Pipeline not found', 404, '');
      }

      return await getLeadsByPipeline(erichPipeline.id);
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to get Erich Pipeline leads: $e');
      }
      rethrow;
    }
  }

  /// Calculate analytics for a specific pipeline
  static Future<GHLAnalytics> calculatePipelineAnalytics(String pipelineId, String pipelineName) async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Calculating analytics for pipeline: $pipelineName');
      }

      // Get leads and opportunities
      final leads = await getLeadsByPipeline(pipelineId);
      final opportunities = await getOpportunities(pipelineId);

      // Calculate metrics
      final leadMetrics = _calculateLeadMetrics(leads);
      final salesMetrics = _calculateSalesMetrics(leads, opportunities);
      final appointmentMetrics = _calculateAppointmentMetrics(leads);
      final financialMetrics = _calculateFinancialMetrics(leads);
      final salesAgentMetrics = _calculateSalesAgentMetrics(leads);

      final analytics = GHLAnalytics(
        pipelineId: pipelineId,
        pipelineName: pipelineName,
        calculatedAt: DateTime.now(),
        leadMetrics: leadMetrics,
        salesMetrics: salesMetrics,
        appointmentMetrics: appointmentMetrics,
        financialMetrics: financialMetrics,
        salesAgentMetrics: salesAgentMetrics,
      );

      if (kDebugMode) {
        print('✅ GHL SERVICE: Analytics calculated for $pipelineName');
        print('   - Total Leads: ${leadMetrics.totalLeads}');
        print('   - HQL Leads: ${leadMetrics.hqlLeads}');
        print('   - Sales: ${salesMetrics.totalSales}');
        print('   - Appointments: ${appointmentMetrics.totalAppointments}');
      }

      return analytics;
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to calculate analytics: $e');
      }
      rethrow;
    }
  }

  /// Map GoHighLevel contact to our GHLLead model
  static GHLLead _mapContactToLead(Map<String, dynamic> contactJson) {
    // Extract custom fields and tracking information
    final customFields = contactJson['customFields'] ?? {};
    final tags = List<String>.from(contactJson['tags'] ?? []);
    
    // Determine lead classification
    final leadType = _determineLeadType(tags, customFields);
    final pipeline = customFields['pipeline'] ?? 'Unknown';
    
    // Extract tracking information from custom fields and tags
    final tracking = GHLLeadTracking(
      hasAppointment: _extractBoolFromCustomFields(customFields, 'hasAppointment') ?? 
                      tags.contains('appointment_set'),
      appointmentDate: _extractDateFromCustomFields(customFields, 'appointmentDate'),
      isOptedIn: _extractBoolFromCustomFields(customFields, 'optedIn') ?? 
                 tags.contains('opted_in'),
      isNoShow: _extractBoolFromCustomFields(customFields, 'noShow') ?? 
                tags.contains('no_show'),
      hasSale: _extractBoolFromCustomFields(customFields, 'hasSale') ?? 
               tags.contains('sale'),
      hasDeposit: _extractBoolFromCustomFields(customFields, 'hasDeposit') ?? 
                  tags.contains('deposit'),
      depositAmount: _extractDoubleFromCustomFields(customFields, 'depositAmount'),
      isInstalled: _extractBoolFromCustomFields(customFields, 'installed') ?? 
                   tags.contains('installed'),
      installationDate: _extractDateFromCustomFields(customFields, 'installationDate'),
      cashCollected: _extractDoubleFromCustomFields(customFields, 'cashCollected'),
      saleDate: _extractDateFromCustomFields(customFields, 'saleDate'),
      saleStatus: customFields['saleStatus']?.toString(),
    );

    final classification = GHLLeadClassification(
      pipeline: pipeline,
      stage: contactJson['pipelineStage']?.toString(),
      leadType: leadType,
      leadScore: _extractDoubleFromCustomFields(customFields, 'leadScore'),
    );

    return GHLLead(
      id: contactJson['id']?.toString() ?? '',
      firstName: contactJson['firstName']?.toString(),
      lastName: contactJson['lastName']?.toString(),
      email: contactJson['email']?.toString(),
      phone: contactJson['phone']?.toString(),
      source: contactJson['source']?.toString(),
      status: contactJson['status']?.toString(),
      tags: tags,
      customFields: customFields,
      dateAdded: _extractDateFromCustomFields(contactJson, 'dateAdded') ?? 
                 DateTime.tryParse(contactJson['createdAt']?.toString() ?? ''),
      lastActivity: _extractDateFromCustomFields(contactJson, 'lastActivity') ?? 
                    DateTime.tryParse(contactJson['updatedAt']?.toString() ?? ''),
      assignedTo: contactJson['assignedTo']?.toString(),
      assignedToName: contactJson['assignedToName']?.toString(),
      classification: classification,
      tracking: tracking,
    );
  }

  /// Determine lead type from tags and custom fields
  static GHLLeadType _determineLeadType(List<String> tags, Map<String, dynamic> customFields) {
    // Check tags first
    if (tags.contains('hql') || tags.contains('high_quality_lead')) {
      return GHLLeadType.hql;
    }
    if (tags.contains('ave_lead') || tags.contains('average_lead')) {
      return GHLLeadType.aveLead;
    }
    
    // Check custom fields
    final leadTypeField = customFields['leadType']?.toString().toLowerCase();
    if (leadTypeField != null) {
      if (leadTypeField.contains('hql')) return GHLLeadType.hql;
      if (leadTypeField.contains('ave')) return GHLLeadType.aveLead;
    }
    
    return GHLLeadType.other;
  }

  /// Helper methods for extracting data from custom fields
  static bool? _extractBoolFromCustomFields(Map<String, dynamic> fields, String key) {
    final value = fields[key];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return null;
  }

  static double? _extractDoubleFromCustomFields(Map<String, dynamic> fields, String key) {
    final value = fields[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _extractDateFromCustomFields(Map<String, dynamic> fields, String key) {
    final value = fields[key];
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Calculate lead metrics
  static GHLLeadMetrics _calculateLeadMetrics(List<GHLLead> leads) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final hqlLeads = leads.where((l) => l.isHQL).length;
    final aveLeads = leads.where((l) => l.isAveLead).length;
    final otherLeads = leads.length - hqlLeads - aveLeads;

    final newToday = leads.where((l) => 
      l.dateAdded != null && 
      l.dateAdded!.isAfter(today)
    ).length;

    final newThisWeek = leads.where((l) => 
      l.dateAdded != null && 
      l.dateAdded!.isAfter(weekStart)
    ).length;

    final newThisMonth = leads.where((l) => 
      l.dateAdded != null && 
      l.dateAdded!.isAfter(monthStart)
    ).length;

    return GHLLeadMetrics(
      totalLeads: leads.length,
      hqlLeads: hqlLeads,
      aveLeads: aveLeads,
      otherLeads: otherLeads,
      hqlPercentage: leads.isNotEmpty ? (hqlLeads / leads.length) * 100 : 0,
      aveLeadPercentage: leads.isNotEmpty ? (aveLeads / leads.length) * 100 : 0,
      newLeadsToday: newToday,
      newLeadsThisWeek: newThisWeek,
      newLeadsThisMonth: newThisMonth,
    );
  }

  /// Calculate sales metrics
  static GHLSalesMetrics _calculateSalesMetrics(List<GHLLead> leads, List<Map<String, dynamic>> opportunities) {
    final salesLeads = leads.where((l) => l.tracking.hasSale).toList();
    final noSalesLeads = leads.where((l) => !l.tracking.hasSale).toList();

    final totalSaleValue = salesLeads.fold<double>(0, (sum, lead) {
      // Try to get sale value from opportunities or custom fields
      final saleValue = lead.customFields['saleValue'];
      if (saleValue is num) {
        return sum + saleValue.toDouble();
      }
      return sum;
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final salesToday = salesLeads.where((l) => 
      l.tracking.saleDate != null && 
      l.tracking.saleDate!.isAfter(today)
    ).length;

    final salesThisWeek = salesLeads.where((l) => 
      l.tracking.saleDate != null && 
      l.tracking.saleDate!.isAfter(weekStart)
    ).length;

    final salesThisMonth = salesLeads.where((l) => 
      l.tracking.saleDate != null && 
      l.tracking.saleDate!.isAfter(monthStart)
    ).length;

    return GHLSalesMetrics(
      totalSales: salesLeads.length,
      noSales: noSalesLeads.length,
      saleConversionRate: leads.isNotEmpty ? (salesLeads.length / leads.length) * 100 : 0,
      averageSaleValue: salesLeads.isNotEmpty ? totalSaleValue / salesLeads.length : 0,
      totalSaleValue: totalSaleValue,
      salesToday: salesToday,
      salesThisWeek: salesThisWeek,
      salesThisMonth: salesThisMonth,
    );
  }

  /// Calculate appointment metrics
  static GHLAppointmentMetrics _calculateAppointmentMetrics(List<GHLLead> leads) {
    final appointmentLeads = leads.where((l) => l.tracking.hasAppointment).toList();
    final noAppointmentLeads = leads.where((l) => !l.tracking.hasAppointment).toList();
    final optedInLeads = leads.where((l) => l.tracking.isOptedIn).toList();
    final noShowLeads = leads.where((l) => l.tracking.isNoShow).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final appointmentsToday = appointmentLeads.where((l) => 
      l.tracking.appointmentDate != null && 
      l.tracking.appointmentDate!.isAfter(today)
    ).length;

    final appointmentsThisWeek = appointmentLeads.where((l) => 
      l.tracking.appointmentDate != null && 
      l.tracking.appointmentDate!.isAfter(weekStart)
    ).length;

    final appointmentsThisMonth = appointmentLeads.where((l) => 
      l.tracking.appointmentDate != null && 
      l.tracking.appointmentDate!.isAfter(monthStart)
    ).length;

    return GHLAppointmentMetrics(
      totalAppointments: appointmentLeads.length,
      noAppointments: noAppointmentLeads.length,
      optedIn: optedInLeads.length,
      noShows: noShowLeads.length,
      appointmentRate: leads.isNotEmpty ? (appointmentLeads.length / leads.length) * 100 : 0,
      optInRate: appointmentLeads.isNotEmpty ? (optedInLeads.length / appointmentLeads.length) * 100 : 0,
      noShowRate: appointmentLeads.isNotEmpty ? (noShowLeads.length / appointmentLeads.length) * 100 : 0,
      appointmentsToday: appointmentsToday,
      appointmentsThisWeek: appointmentsThisWeek,
      appointmentsThisMonth: appointmentsThisMonth,
    );
  }

  /// Calculate financial metrics
  static GHLFinancialMetrics _calculateFinancialMetrics(List<GHLLead> leads) {
    final depositLeads = leads.where((l) => l.tracking.hasDeposit).toList();
    final installationLeads = leads.where((l) => l.tracking.isInstalled).toList();

    final totalDepositAmount = depositLeads.fold<double>(0, (sum, lead) => 
      sum + (lead.tracking.depositAmount ?? 0));

    final totalCashCollected = leads.fold<double>(0, (sum, lead) => 
      sum + (lead.tracking.cashCollected ?? 0));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final depositsToday = depositLeads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(today)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.depositAmount ?? 0));

    final depositsThisWeek = depositLeads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(weekStart)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.depositAmount ?? 0));

    final depositsThisMonth = depositLeads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(monthStart)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.depositAmount ?? 0));

    final cashCollectedToday = leads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(today)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.cashCollected ?? 0));

    final cashCollectedThisWeek = leads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(weekStart)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.cashCollected ?? 0));

    final cashCollectedThisMonth = leads.where((l) => 
      l.lastActivity != null && 
      l.lastActivity!.isAfter(monthStart)
    ).fold<double>(0, (sum, lead) => sum + (lead.tracking.cashCollected ?? 0));

    return GHLFinancialMetrics(
      totalDeposits: depositLeads.length,
      totalDepositAmount: totalDepositAmount,
      averageDepositAmount: depositLeads.isNotEmpty ? totalDepositAmount / depositLeads.length : 0,
      totalInstallations: installationLeads.length,
      installationRate: leads.isNotEmpty ? (installationLeads.length / leads.length) * 100 : 0,
      totalCashCollected: totalCashCollected,
      averageCashPerLead: leads.isNotEmpty ? totalCashCollected / leads.length : 0,
      depositsToday: depositsToday,
      depositsThisWeek: depositsThisWeek,
      depositsThisMonth: depositsThisMonth,
      cashCollectedToday: cashCollectedToday,
      cashCollectedThisWeek: cashCollectedThisWeek,
      cashCollectedThisMonth: cashCollectedThisMonth,
    );
  }

  /// Calculate sales agent metrics
  static List<GHLSalesAgentMetrics> _calculateSalesAgentMetrics(List<GHLLead> leads) {
    final agentGroups = <String, List<GHLLead>>{};
    
    // Group leads by sales agent
    for (final lead in leads) {
      if (lead.assignedTo != null) {
        agentGroups.putIfAbsent(lead.assignedTo!, () => []).add(lead);
      }
    }

    return agentGroups.entries.map((entry) {
      final agentId = entry.key;
      final agentLeads = entry.value;
      final agentName = agentLeads.first.assignedToName ?? 'Unknown Agent';

      final hqlLeads = agentLeads.where((l) => l.isHQL).length;
      final aveLeads = agentLeads.where((l) => l.isAveLead).length;
      final appointments = agentLeads.where((l) => l.tracking.hasAppointment).length;
      final sales = agentLeads.where((l) => l.tracking.hasSale).length;
      final installations = agentLeads.where((l) => l.tracking.isInstalled).length;

      final totalSaleValue = agentLeads.fold<double>(0, (sum, lead) {
        final saleValue = lead.customFields['saleValue'];
        if (saleValue is num) {
          return sum + saleValue.toDouble();
        }
        return sum;
      });

      final totalDeposits = agentLeads.fold<double>(0, (sum, lead) => 
        sum + (lead.tracking.depositAmount ?? 0));

      final totalCashCollected = agentLeads.fold<double>(0, (sum, lead) => 
        sum + (lead.tracking.cashCollected ?? 0));

      return GHLSalesAgentMetrics(
        agentId: agentId,
        agentName: agentName,
        totalLeads: agentLeads.length,
        hqlLeads: hqlLeads,
        aveLeads: aveLeads,
        appointments: appointments,
        sales: sales,
        saleConversionRate: agentLeads.isNotEmpty ? (sales / agentLeads.length) * 100 : 0,
        totalSaleValue: totalSaleValue,
        totalDeposits: totalDeposits,
        totalCashCollected: totalCashCollected,
        installations: installations,
      );
    }).toList();
  }

  /// Test API connection
  static Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Testing API connection...');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_pipelinesEndpoint'),
        headers: _headers,
      );

      final isConnected = response.statusCode == 200;
      
      if (kDebugMode) {
        if (isConnected) {
          print('✅ GHL SERVICE: API connection successful');
        } else {
          print('❌ GHL SERVICE: API connection failed - ${response.statusCode}');
        }
      }

      return isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Connection test failed: $e');
      }
      return false;
    }
  }

  /// Get campaign performance analytics for Erich Pipeline
  /// Returns aggregated metrics by campaign including HQL/Ave leads, appointments, sales, etc.
  static Future<Map<String, dynamic>> getCampaignAnalytics() async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching campaign analytics...');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$_campaignAnalyticsEndpoint'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded campaign analytics');
          print('   - Total Campaigns: ${data['summary']?['totalCampaigns']}');
          print('   - Total Leads: ${data['summary']?['totalLeads']}');
          print('   - Total HQL: ${data['summary']?['totalHQL']}');
        }

        return data;
      } else {
        throw GHLApiException(
          'Failed to fetch campaign analytics',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch campaign analytics: $e');
      }
      rethrow;
    }
  }

  /// Get pipeline performance analytics for Altus and Andries pipelines
  /// Returns aggregated metrics for the 5 key stages across both pipelines
  /// with breakdown by sales agent
  static Future<Map<String, dynamic>> getPipelinePerformanceAnalytics({
    String? altusPipelineId,
    String? andriesPipelineId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching pipeline performance analytics...');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (altusPipelineId != null) {
        queryParams['altusPipelineId'] = altusPipelineId;
      }
      if (andriesPipelineId != null) {
        queryParams['andriesPipelineId'] = andriesPipelineId;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_baseUrl/analytics/pipeline-performance')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded pipeline performance analytics');
          print('   - Total Opportunities: ${data['overview']?['totalOpportunities']}');
          print('   - Booked Appointments: ${data['overview']?['bookedAppointments']}');
          print('   - Call Completed: ${data['overview']?['callCompleted']}');
          print('   - Sales Agents: ${data['salesAgentsList']?.length ?? 0}');
        }

        return data;
      } else {
        throw GHLApiException(
          'Failed to fetch pipeline performance analytics',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch pipeline performance analytics: $e');
      }
      rethrow;
    }
  }

  /// Get CUMULATIVE pipeline performance analytics (parallel tracking system)
  /// Returns cumulative metrics where stage counts never decrease
  /// Filters by opportunities created within date range
  static Future<Map<String, dynamic>> getPipelinePerformanceCumulative({
    String? altusPipelineId,
    String? andriesPipelineId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Fetching CUMULATIVE pipeline performance analytics...');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (altusPipelineId != null) {
        queryParams['altusPipelineId'] = altusPipelineId;
      }
      if (andriesPipelineId != null) {
        queryParams['andriesPipelineId'] = andriesPipelineId;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$_baseUrl/analytics/pipeline-performance-cumulative')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ GHL SERVICE: Loaded CUMULATIVE pipeline performance analytics');
          print('   - View Mode: ${data['viewMode']}');
          print('   - Total Opportunities: ${data['overview']?['totalOpportunities']}');
          print('   - Booked Appointments: ${data['overview']?['bookedAppointments']}');
          print('   - Call Completed: ${data['overview']?['callCompleted']}');
        }

        return data;
      } else {
        throw GHLApiException(
          'Failed to fetch cumulative pipeline performance analytics',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to fetch cumulative analytics: $e');
      }
      rethrow;
    }
  }

  /// Sync opportunity history from GoHighLevel to Firestore
  /// This fetches all current opportunities and updates the history collection
  static Future<Map<String, dynamic>> syncOpportunityHistory() async {
    try {
      if (kDebugMode) {
        print('🔄 GHL SERVICE: Syncing opportunity history...');
      }

      final uri = Uri.parse('$_baseUrl/sync-opportunity-history');
      final response = await http.post(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('✅ GHL SERVICE: Opportunity history synced');
          print('   - Total: ${data['stats']?['total']}');
          print('   - Synced: ${data['stats']?['synced']}');
          print('   - Skipped: ${data['stats']?['skipped']}');
          print('   - Errors: ${data['stats']?['errors']}');
        }

        return data;
      } else {
        throw GHLApiException(
          'Failed to sync opportunity history',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL SERVICE ERROR: Failed to sync opportunity history: $e');
      }
      rethrow;
    }
  }
}

/// Custom exception for GoHighLevel API errors
class GHLApiException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  GHLApiException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() => 'GHLApiException: $message (Status: $statusCode)';
}
