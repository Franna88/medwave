import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/gohighlevel/ghl_lead.dart';
import '../models/gohighlevel/ghl_pipeline.dart';
import '../models/gohighlevel/ghl_analytics.dart';
import '../services/gohighlevel/ghl_service.dart';

/// Provider for managing GoHighLevel CRM data and operations
/// Handles lead tracking, pipeline analytics, and advertisement performance monitoring
class GoHighLevelProvider extends ChangeNotifier {
  // Core data
  List<GHLPipeline> _pipelines = [];
  List<GHLLead> _allLeads = [];
  List<GHLLead> _erichPipelineLeads = [];
  GHLAnalytics? _erichAnalytics;
  List<GHLAnalytics> _allPipelineAnalytics = [];
  
  // Campaign analytics data (from new analytics endpoint)
  Map<String, dynamic>? _campaignAnalytics;
  
  // Pipeline performance analytics (Altus + Andries)
  Map<String, dynamic>? _pipelinePerformance;
  
  // State management
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _refreshTimer;
  
  // Configuration
  static const Duration _refreshInterval = Duration(minutes: 5);
  
  // Getters
  List<GHLPipeline> get pipelines => _pipelines;
  List<GHLLead> get allLeads => _allLeads;
  List<GHLLead> get erichPipelineLeads => _erichPipelineLeads;
  GHLAnalytics? get erichAnalytics => _erichAnalytics;
  List<GHLAnalytics> get allPipelineAnalytics => _allPipelineAnalytics;
  Map<String, dynamic>? get campaignAnalytics => _campaignAnalytics;
  Map<String, dynamic>? get pipelinePerformance => _pipelinePerformance;
  
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;
  
  // Campaign analytics getters
  List<dynamic> get campaigns => _campaignAnalytics?['campaigns'] ?? [];
  List<dynamic> get allAds => _campaignAnalytics?['allAds'] ?? [];
  Map<String, dynamic> get campaignSummary => _campaignAnalytics?['summary'] ?? {};
  int get totalCampaigns => campaignSummary['totalCampaigns'] ?? 0;
  int get totalAds => campaignSummary['totalAds'] ?? 0;
  int get totalCampaignLeads => campaignSummary['totalLeads'] ?? 0;
  int get totalCampaignHQL => campaignSummary['totalHQL'] ?? 0;
  int get totalCampaignAppointments => campaignSummary['totalAppointments'] ?? 0;
  int get totalCampaignSales => campaignSummary['totalSales'] ?? 0;
  double get totalCampaignRevenue => (campaignSummary['totalRevenue'] ?? 0).toDouble();
  
  // Pipeline performance getters (Altus + Andries)
  Map<String, dynamic> get pipelineOverview => _pipelinePerformance?['overview'] ?? {};
  Map<String, dynamic> get pipelineByPipeline => _pipelinePerformance?['byPipeline'] ?? {};
  List<dynamic> get pipelineSalesAgents => _pipelinePerformance?['salesAgentsList'] ?? [];
  List<dynamic> get pipelineCampaigns => _pipelinePerformance?['campaignsList'] ?? [];
  
  // Overview stats
  int get totalPipelineOpportunities => pipelineOverview['totalOpportunities'] ?? 0;
  int get bookedAppointments => pipelineOverview['bookedAppointments'] ?? 0;
  int get callCompleted => pipelineOverview['callCompleted'] ?? 0;
  int get noShowCancelledDisqualified => pipelineOverview['noShowCancelledDisqualified'] ?? 0;
  int get deposits => pipelineOverview['deposits'] ?? 0;
  int get cashCollected => pipelineOverview['cashCollected'] ?? 0;
  double get totalMonetaryValue => (pipelineOverview['totalMonetaryValue'] ?? 0).toDouble();
  
  // Altus pipeline stats
  Map<String, dynamic> get altusPipeline => pipelineByPipeline['altus'] ?? {};
  int get altusOpportunities => altusPipeline['totalOpportunities'] ?? 0;
  int get altusBookedAppointments => altusPipeline['bookedAppointments'] ?? 0;
  int get altusCallCompleted => altusPipeline['callCompleted'] ?? 0;
  int get altusNoShowCancelledDisqualified => altusPipeline['noShowCancelledDisqualified'] ?? 0;
  int get altusDeposits => altusPipeline['deposits'] ?? 0;
  int get altusCashCollected => altusPipeline['cashCollected'] ?? 0;
  
  // Andries pipeline stats
  Map<String, dynamic> get andriesPipeline => pipelineByPipeline['andries'] ?? {};
  int get andriesOpportunities => andriesPipeline['totalOpportunities'] ?? 0;
  int get andriesBookedAppointments => andriesPipeline['bookedAppointments'] ?? 0;
  int get andriesCallCompleted => andriesPipeline['callCompleted'] ?? 0;
  int get andriesNoShowCancelledDisqualified => andriesPipeline['noShowCancelledDisqualified'] ?? 0;
  int get andriesDeposits => andriesPipeline['deposits'] ?? 0;
  int get andriesCashCollected => andriesPipeline['cashCollected'] ?? 0;
  
  // Erich Pipeline specific getters
  GHLPipeline? get erichPipeline => 
      _pipelines.where((p) => p.isErichPipeline).firstOrNull;
  
  bool get hasErichPipeline => erichPipeline != null;
  
  // Quick stats getters for Erich Pipeline
  int get erichTotalLeads => _erichPipelineLeads.length;
  int get erichHQLLeads => _erichPipelineLeads.where((l) => l.isHQL).length;
  int get erichAveLeads => _erichPipelineLeads.where((l) => l.isAveLead).length;
  int get erichAppointments => _erichPipelineLeads.where((l) => l.tracking.hasAppointment).length;
  int get erichSales => _erichPipelineLeads.where((l) => l.tracking.hasSale).length;
  int get erichDeposits => _erichPipelineLeads.where((l) => l.tracking.hasDeposit).length;
  int get erichInstallations => _erichPipelineLeads.where((l) => l.tracking.isInstalled).length;
  
  double get erichTotalCashCollected => _erichPipelineLeads.fold<double>(0, 
      (sum, lead) => sum + (lead.tracking.cashCollected ?? 0));
  
  double get erichTotalDeposits => _erichPipelineLeads.fold<double>(0, 
      (sum, lead) => sum + (lead.tracking.depositAmount ?? 0));
  
  // Conversion rates for Erich Pipeline
  double get erichAppointmentRate => erichTotalLeads > 0 
      ? (erichAppointments / erichTotalLeads) * 100 : 0;
  
  double get erichSaleConversionRate => erichTotalLeads > 0 
      ? (erichSales / erichTotalLeads) * 100 : 0;
  
  double get erichInstallationRate => erichTotalLeads > 0 
      ? (erichInstallations / erichTotalLeads) * 100 : 0;

  /// Initialize the provider and start data loading
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      print('🔄 GHL PROVIDER: Initializing...');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Test API connection first
      final isConnected = await GoHighLevelService.testConnection();
      if (!isConnected) {
        throw Exception('Unable to connect to GoHighLevel API. This is likely due to CORS restrictions when running in a web browser. The GoHighLevel integration will work properly when deployed to a server or when running as a mobile app.');
      }
      
      // Load initial data
      await _loadAllData();
      
      // Start automatic refresh timer
      _startRefreshTimer();
      
      _isInitialized = true;
      _isLoading = false;
      _lastRefresh = DateTime.now();
      
      if (kDebugMode) {
        print('✅ GHL PROVIDER: Initialized successfully');
        print('   - Pipelines: ${_pipelines.length}');
        print('   - Total Leads: ${_allLeads.length}');
        print('   - Erich Pipeline Leads: ${_erichPipelineLeads.length}');
      }
      
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      
      if (kDebugMode) {
        print('❌ GHL PROVIDER ERROR: Initialization failed: $e');
      }
    }
    
    notifyListeners();
  }

  /// Load all data from GoHighLevel API
  Future<void> _loadAllData() async {
    try {
      // Load pipelines (lightweight, just for reference)
      _pipelines = await GoHighLevelService.getPipelines();
      if (kDebugMode) {
        print('✅ GHL PROVIDER: Loaded ${_pipelines.length} pipelines');
      }
      
      // Load campaign analytics (for Advert Performance screen)
      // This endpoint provides all the aggregated data we need
      try {
        _campaignAnalytics = await GoHighLevelService.getCampaignAnalytics();
        if (kDebugMode) {
          print('✅ GHL PROVIDER: Loaded campaign analytics - ${totalCampaigns} campaigns, ${totalCampaignLeads} leads');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ GHL PROVIDER: Failed to load campaign analytics: $e');
        }
        // Don't rethrow - campaign analytics is optional
      }
      
      // Load pipeline performance analytics (Altus + Andries pipelines)
      try {
        _pipelinePerformance = await GoHighLevelService.getPipelinePerformanceAnalytics();
        if (kDebugMode) {
          print('✅ GHL PROVIDER: Loaded pipeline performance - ${totalPipelineOpportunities} opportunities');
          print('   - Booked Appointments: $bookedAppointments');
          print('   - Call Completed: $callCompleted');
          print('   - No Show/Cancelled: $noShowCancelledDisqualified');
          print('   - Deposits: $deposits');
          print('   - Cash Collected: $cashCollected');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ GHL PROVIDER: Failed to load pipeline performance: $e');
        }
        // Don't rethrow - pipeline performance is optional
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ GHL PROVIDER ERROR: Failed to load data: $e');
      }
      rethrow;
    }
  }

  /// Refresh data manually
  Future<void> refreshData() async {
    if (_isLoading) return;
    
    if (kDebugMode) {
      print('🔄 GHL PROVIDER: Manual refresh requested');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _loadAllData();
      _lastRefresh = DateTime.now();
      _isLoading = false;
      
      if (kDebugMode) {
        print('✅ GHL PROVIDER: Manual refresh completed');
      }
      
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      
      if (kDebugMode) {
        print('❌ GHL PROVIDER ERROR: Manual refresh failed: $e');
      }
    }
    
    notifyListeners();
  }

  /// Start automatic refresh timer
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (!_isLoading) {
        _automaticRefresh();
      }
    });
    
    if (kDebugMode) {
      print('⏰ GHL PROVIDER: Auto-refresh timer started (${_refreshInterval.inMinutes} minutes)');
    }
  }

  /// Automatic refresh (silent, no loading indicator for better UX)
  Future<void> _automaticRefresh() async {
    try {
      if (kDebugMode) {
        print('🔄 GHL PROVIDER: Automatic refresh starting...');
      }
      
      await _loadAllData();
      _lastRefresh = DateTime.now();
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ GHL PROVIDER: Automatic refresh completed');
      }
      
    } catch (e) {
      // For automatic refresh, we don't show errors prominently
      // Just log them and continue with existing data
      if (kDebugMode) {
        print('⚠️ GHL PROVIDER: Automatic refresh failed (continuing with existing data): $e');
      }
    }
  }

  /// Get leads by sales agent
  List<GHLLead> getLeadsBySalesAgent(String agentId) {
    return _erichPipelineLeads.where((lead) => lead.assignedTo == agentId).toList();
  }

  /// Get leads by lead type
  List<GHLLead> getLeadsByType(GHLLeadType type) {
    return _erichPipelineLeads.where((lead) => lead.classification.leadType == type).toList();
  }

  /// Get leads with appointments
  List<GHLLead> getLeadsWithAppointments() {
    return _erichPipelineLeads.where((lead) => lead.tracking.hasAppointment).toList();
  }

  /// Get leads with sales
  List<GHLLead> getLeadsWithSales() {
    return _erichPipelineLeads.where((lead) => lead.tracking.hasSale).toList();
  }

  /// Get leads with deposits
  List<GHLLead> getLeadsWithDeposits() {
    return _erichPipelineLeads.where((lead) => lead.tracking.hasDeposit).toList();
  }

  /// Get leads with installations
  List<GHLLead> getLeadsWithInstallations() {
    return _erichPipelineLeads.where((lead) => lead.tracking.isInstalled).toList();
  }

  /// Get unique sales agents from Erich Pipeline
  List<String> getUniqueSalesAgents() {
    final agents = <String>{};
    for (final lead in _erichPipelineLeads) {
      if (lead.assignedToName != null && lead.assignedToName!.isNotEmpty) {
        agents.add(lead.assignedToName!);
      }
    }
    return agents.toList()..sort();
  }

  /// Get unique sales agents from pipeline performance (Altus + Andries)
  List<String> getPipelineSalesAgents() {
    final agents = <String>{};
    for (final agent in pipelineSalesAgents) {
      final agentName = agent['agentName'] as String?;
      if (agentName != null && agentName.isNotEmpty && agentName != 'Unassigned') {
        agents.add(agentName);
      }
    }
    return agents.toList()..sort();
  }

  /// Get pipeline stats for a specific sales agent
  Map<String, dynamic>? getPipelineStatsForAgent(String agentName) {
    for (final agent in pipelineSalesAgents) {
      if (agent['agentName'] == agentName) {
        return agent as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Get sales agent metrics
  List<GHLSalesAgentMetrics> getSalesAgentMetrics() {
    return _erichAnalytics?.salesAgentMetrics ?? [];
  }

  /// Get analytics for a specific time period
  Map<String, dynamic> getAnalyticsForPeriod(DateTime startDate, DateTime endDate) {
    final periodLeads = _erichPipelineLeads.where((lead) {
      final leadDate = lead.dateAdded;
      return leadDate != null && 
             leadDate.isAfter(startDate) && 
             leadDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    return {
      'totalLeads': periodLeads.length,
      'hqlLeads': periodLeads.where((l) => l.isHQL).length,
      'aveLeads': periodLeads.where((l) => l.isAveLead).length,
      'appointments': periodLeads.where((l) => l.tracking.hasAppointment).length,
      'sales': periodLeads.where((l) => l.tracking.hasSale).length,
      'deposits': periodLeads.where((l) => l.tracking.hasDeposit).length,
      'installations': periodLeads.where((l) => l.tracking.isInstalled).length,
      'totalCashCollected': periodLeads.fold<double>(0, 
          (sum, lead) => sum + (lead.tracking.cashCollected ?? 0)),
    };
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get time since last refresh
  String getTimeSinceLastRefresh() {
    if (_lastRefresh == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(_lastRefresh!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Check if data is stale (older than refresh interval)
  bool get isDataStale {
    if (_lastRefresh == null) return true;
    final now = DateTime.now();
    return now.difference(_lastRefresh!).inMinutes > _refreshInterval.inMinutes;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
    
    if (kDebugMode) {
      print('🧹 GHL PROVIDER: Disposed');
    }
  }
}
