import 'package:flutter/material.dart';
import '../../../models/comparison/comparison_models.dart';
import '../../../models/comparison/comparison_list_models.dart';
import '../../../models/performance/campaign.dart';
import '../../../services/comparison_service.dart';
import '../../../services/firebase/campaign_service.dart';
import '../../../theme/app_theme.dart';

/// Campaign Comparison Screen - Drill-down analysis
/// Select a campaign, view comparison, then drill into ad sets and ads
class AdminAdvertsComparisonScreen extends StatefulWidget {
  const AdminAdvertsComparisonScreen({Key? key}) : super(key: key);

  @override
  State<AdminAdvertsComparisonScreen> createState() =>
      _AdminAdvertsComparisonScreenState();
}

class _AdminAdvertsComparisonScreenState
    extends State<AdminAdvertsComparisonScreen> {
  final ComparisonService _comparisonService = ComparisonService();
  final CampaignService _campaignService = CampaignService();

  // State
  String _selectedMonth = 'thismonth';
  TimePeriod _selectedTimePeriod = TimePeriod.LAST_7_DAYS;
  bool _isLoading = false;
  String? _error;

  // Available months for filter
  List<String> _availableMonths = [];

  // Campaigns data
  List<Campaign> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAvailableMonths();
    await _loadCampaignsForMonth();
  }

  Future<void> _loadAvailableMonths() async {
    // Generate last 12 months for the filter
    final now = DateTime.now();
    final months = <String>[];

    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      months.add(monthStr);
    }

    setState(() {
      _availableMonths = months;
    });
  }

  Future<void> _loadCampaignsForMonth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Campaign> campaigns;
      final dateRange = _calculateDateRangeForMonth(_selectedMonth);

      print('🔄 Loading campaigns with date range from split collections...');
      print('   - Month filter: $_selectedMonth');
      print('   - Start date: ${dateRange['start']?.toIso8601String()}');
      print('   - End date: ${dateRange['end']?.toIso8601String()}');
      print('   - Order by: totalProfit (desc)');

      if (_selectedMonth == 'thismonth') {
        // Try monthlyTotals first for current month
        final now = DateTime.now();
        final currentMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';

        campaigns = await _campaignService.getCampaignsWithMonthTotals(
          month: currentMonth,
          limit: 100,
          orderBy: 'lastUpdated',
          descending: true,
        );

        // If no campaigns with monthlyTotals, fall back to date range query
        if (campaigns.isEmpty) {
          campaigns = await _campaignService.getCampaignsByDateRange(
            startDate: dateRange['start'],
            endDate: dateRange['end'],
            limit: 100,
            orderBy: 'lastUpdated',
            descending: true,
          );
        }
      } else if (_availableMonths.contains(_selectedMonth)) {
        // Try monthlyTotals first for specific month
        campaigns = await _campaignService.getCampaignsWithMonthTotals(
          month: _selectedMonth,
          limit: 100,
          orderBy: 'lastUpdated',
          descending: true,
        );

        // If no campaigns with monthlyTotals, fall back to date range query
        if (campaigns.isEmpty) {
          campaigns = await _campaignService.getCampaignsByDateRange(
            startDate: dateRange['start'],
            endDate: dateRange['end'],
            limit: 100,
            orderBy: 'lastUpdated',
            descending: true,
          );
        }
      } else {
        // For 'allmonths' or unknown filters, use date range
        campaigns = await _campaignService.getCampaignsByDateRange(
          startDate: dateRange['start'],
          endDate: dateRange['end'],
          limit: 100,
          orderBy: 'lastUpdated',
          descending: true,
        );
      }

      print('✅ Loaded ${campaigns.length} campaigns from split collections');

      if (!mounted) return;

      setState(() {
        _campaigns = campaigns;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading campaigns: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calculate date range based on month filter
  Map<String, DateTime?> _calculateDateRangeForMonth(String monthFilter) {
    final now = DateTime.now();
    DateTime? baseStart;
    DateTime? baseEnd;

    if (monthFilter == 'thismonth') {
      baseStart = DateTime(now.year, now.month, 1);
      baseEnd = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
    } else if (_availableMonths.contains(monthFilter)) {
      // Parse specific month (format: "2025-11")
      final parts = monthFilter.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          baseStart = DateTime(year, month, 1);
          baseEnd = DateTime(
            year,
            month + 1,
            1,
          ).subtract(const Duration(seconds: 1));
        }
      }
    }

    // Default to current month if parsing failed
    if (baseStart == null || baseEnd == null) {
      baseStart = DateTime(now.year, now.month, 1);
      baseEnd = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
    }

    return {'start': baseStart, 'end': baseEnd};
  }

  void _onMonthChanged(String? newMonth) {
    if (newMonth != null && newMonth != _selectedMonth) {
      setState(() {
        _selectedMonth = newMonth;
      });
      _loadCampaignsForMonth();
    }
  }

  void _onTimePeriodChanged(TimePeriod? newPeriod) {
    if (newPeriod != null && newPeriod != _selectedTimePeriod) {
      setState(() {
        _selectedTimePeriod = newPeriod;
      });
    }
  }

  void _openCampaignModal(Campaign campaign) {
    showDialog(
      context: context,
      builder: (context) => _DrillDownModal(
        campaignId: campaign.campaignId,
        campaignName: campaign.campaignName,
        timePeriod: _selectedTimePeriod,
        comparisonService: _comparisonService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.desktopBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Campaign Comparison',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCampaignsForMonth,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorState()
                : _campaigns.isEmpty
                ? _buildNoDataState()
                : _buildCampaignGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected month indicator
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Viewing: ${_getSelectedMonthDisplay()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_campaigns.length} campaigns',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Month filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Select Month',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'thismonth',
                      child: Row(
                        children: [
                          Icon(
                            Icons.today,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text('This Month (${_getCurrentMonthName()})'),
                        ],
                      ),
                    ),
                    ..._availableMonths.map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(_formatMonthLabel(month)),
                      );
                    }),
                  ],
                  onChanged: _onMonthChanged,
                ),
              ),
              const SizedBox(width: 16),
              // Period toggle
              Expanded(
                flex: 2,
                child: SegmentedButton<TimePeriod>(
                  segments: const [
                    ButtonSegment(
                      value: TimePeriod.LAST_7_DAYS,
                      label: Text('Last 7 Days'),
                      icon: Icon(Icons.calendar_view_week),
                    ),
                    ButtonSegment(
                      value: TimePeriod.LAST_30_DAYS,
                      label: Text('Last 30 Days'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_selectedTimePeriod},
                  onSelectionChanged: (Set<TimePeriod> newSelection) {
                    _onTimePeriodChanged(newSelection.first);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCurrentMonthName() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[now.month - 1];
  }

  String _getSelectedMonthDisplay() {
    if (_selectedMonth == 'thismonth') {
      final now = DateTime.now();
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[now.month - 1]} ${now.year}';
    } else {
      try {
        final parts = _selectedMonth.split('-');
        if (parts.length == 2) {
          final year = parts[0];
          final monthNum = int.parse(parts[1]);
          const months = [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
          return '${months[monthNum - 1]} $year';
        }
      } catch (e) {
        // Fall back
      }
    }
    return _selectedMonth;
  }

  String _formatMonthLabel(String month) {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final monthNum = int.parse(parts[1]);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[monthNum - 1]} $year';
      }
    } catch (e) {
      // Fall back to original
    }
    return month;
  }

  Widget _buildCampaignGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        return _buildCampaignCard(campaign);
      },
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openCampaignModal(campaign),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campaign name
              Text(
                campaign.campaignName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(campaign.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  campaign.status,
                  style: TextStyle(
                    color: _getStatusColor(campaign.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              // Metrics preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricPreview(
                    'Spend',
                    '\$${campaign.totalSpend.toStringAsFixed(2)}',
                    Icons.payments,
                  ),
                  _buildMetricPreview(
                    'Leads',
                    campaign.totalLeads.toString(),
                    Icons.people,
                  ),
                  _buildMetricPreview(
                    'ROI',
                    '${campaign.roi.toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Compare button
              Center(
                child: Text(
                  'Click to compare',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPreview(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading campaigns',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCampaignsForMonth,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No campaigns found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try selecting a different month or check your data.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DRILL-DOWN MODAL WIDGET
// ============================================================================

class _DrillDownModal extends StatefulWidget {
  final String campaignId;
  final String campaignName;
  final TimePeriod timePeriod;
  final ComparisonService comparisonService;

  const _DrillDownModal({
    required this.campaignId,
    required this.campaignName,
    required this.timePeriod,
    required this.comparisonService,
  });

  @override
  State<_DrillDownModal> createState() => _DrillDownModalState();
}

class _DrillDownModalState extends State<_DrillDownModal> {
  // Navigation state
  int _currentLevel = 1; // 1 = Campaign, 2 = Ad Set, 3 = Ad
  TimePeriod _timePeriod;

  // Data for each level
  CampaignComparison? _campaignComparison;
  List<AdSetComparison>? _adSetComparisons;

  // Selected entities for drill-down
  String? _selectedAdSetId;
  String? _selectedAdSetName;
  AdSetComparison? _selectedAdSetComparison;
  List<AdComparison>? _adComparisons;

  String? _selectedAdId;
  AdComparison? _selectedAdComparison;

  bool _isLoading = false;
  String? _error;

  _DrillDownModalState() : _timePeriod = TimePeriod.LAST_7_DAYS;

  @override
  void initState() {
    super.initState();
    _timePeriod = widget.timePeriod;
    _loadCampaignData();
  }

  Future<void> _loadCampaignData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final campaignComp = await widget.comparisonService.getCampaignComparison(
        widget.campaignId,
        _timePeriod,
      );
      final adSets = await widget.comparisonService.getCampaignAdSetsComparison(
        widget.campaignId,
        _timePeriod,
      );

      if (!mounted) return;

      setState(() {
        _campaignComparison = campaignComp;
        _adSetComparisons = adSets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading campaign data: $e');
      if (!mounted) return;

      // Check if it's a "not found" error (campaign has no data in this period)
      final errorMessage = e.toString();
      if (errorMessage.contains('not found')) {
        setState(() {
          _campaignComparison = null;
          _adSetComparisons = null;
          _error = 'This Campaign does not have stats for the last 7 days. Please compare last 30 days.'; 
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _drillDownToAdSet(AdSetComparison adSetComp) async {
    print('🔍 UI DEBUG: Drilling down to ad set: ${adSetComp.adSetName}');
    print('🔍 UI DEBUG: Ad Set ID: ${adSetComp.adSetId}');
    print('🔍 UI DEBUG: Time Period: $_timePeriod');

    setState(() {
      _isLoading = true;
      _error = null;
      _selectedAdSetId = adSetComp.adSetId;
      _selectedAdSetName = adSetComp.adSetName;
      _selectedAdSetComparison = adSetComp;
    });

    try {
      final ads = await widget.comparisonService.getAdSetAdsComparison(
        adSetComp.adSetId,
        _timePeriod,
      );

      print('🔍 UI DEBUG: Received ${ads.length} ads from service');

      if (!mounted) return;

      setState(() {
        _adComparisons = ads;
        _currentLevel = 2;
        _isLoading = false;
      });

      print('🔍 UI DEBUG: Updated UI with ${ads.length} ads');
    } catch (e) {
      print('Error loading ads: $e');
      if (!mounted) return;

      final errorMessage = e.toString();
      if (errorMessage.contains('not found')) {
        setState(() {
          _adComparisons = [];
          _currentLevel = 2;
          _error = 'no_data_in_period';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _drillDownToAd(AdComparison adComp) async {
    setState(() {
      _selectedAdId = adComp.adId;
      _selectedAdComparison = adComp;
      _currentLevel = 3;
    });
  }

  void _navigateBack() {
    if (_currentLevel == 3) {
      setState(() {
        _currentLevel = 2;
        _selectedAdId = null;
        _selectedAdComparison = null;
      });
    } else if (_currentLevel == 2) {
      setState(() {
        _currentLevel = 1;
        _selectedAdSetId = null;
        _selectedAdSetName = null;
        _selectedAdSetComparison = null;
        _adComparisons = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onTimePeriodChanged(TimePeriod newPeriod) async {
    if (newPeriod == _timePeriod) return;

    setState(() {
      _timePeriod = newPeriod;
    });

    // Reload data based on current level
    if (_currentLevel == 1) {
      await _loadCampaignData();
    } else if (_currentLevel == 2 && _selectedAdSetId != null) {
      // Reload ad set and ads
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final adSetComp = await widget.comparisonService.getAdSetComparison(
          _selectedAdSetId!,
          _timePeriod,
        );
        final ads = await widget.comparisonService.getAdSetAdsComparison(
          _selectedAdSetId!,
          _timePeriod,
        );

        if (!mounted) return;

        setState(() {
          _selectedAdSetComparison = adSetComp;
          _adComparisons = ads;
          _isLoading = false;
        });
      } catch (e) {
        print('Error reloading ad set data: $e');
        if (!mounted) return;

        final errorMessage = e.toString();
        if (errorMessage.contains('not found')) {
          setState(() {
            _selectedAdSetComparison = null;
            _adComparisons = null;
            _error = 'no_data_in_period';
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = errorMessage;
            _isLoading = false;
          });
        }
      }
    } else if (_currentLevel == 3 && _selectedAdId != null) {
      // Reload ad data
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final adComp = await widget.comparisonService.getAdComparison(
          _selectedAdId!,
          _timePeriod,
        );

        if (!mounted) return;

        setState(() {
          _selectedAdComparison = adComp;
          _isLoading = false;
        });
      } catch (e) {
        print('Error reloading ad data: $e');
        if (!mounted) return;

        final errorMessage = e.toString();
        if (errorMessage.contains('not found')) {
          setState(() {
            _selectedAdComparison = null;
            _error = 'no_data_in_period';
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = errorMessage;
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 800 ? screenWidth * 0.8 : screenWidth;

    return Dialog(
      child: Container(
        width: dialogWidth,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            _buildModalHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorView()
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentLevel > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _navigateBack,
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  _buildBreadcrumb(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Period toggle
          SegmentedButton<TimePeriod>(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.white.withOpacity(0.2);
              }),
              foregroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppTheme.primaryColor;
                }
                return Colors.white;
              }),
            ),
            segments: const [
              ButtonSegment(
                value: TimePeriod.LAST_7_DAYS,
                label: Text('Last 7 Days'),
              ),
              ButtonSegment(
                value: TimePeriod.LAST_30_DAYS,
                label: Text('Last 30 Days'),
              ),
            ],
            selected: {_timePeriod},
            onSelectionChanged: (Set<TimePeriod> newSelection) {
              _onTimePeriodChanged(newSelection.first);
            },
          ),
        ],
      ),
    );
  }

  String _buildBreadcrumb() {
    if (_currentLevel == 1) {
      return widget.campaignName;
    } else if (_currentLevel == 2) {
      return '${widget.campaignName} > ${_selectedAdSetName ?? "Ad Set"}';
    } else {
      return '${widget.campaignName} > ${_selectedAdSetName ?? "Ad Set"} > Ad';
    }
  }

  Widget _buildContent() {
    // Check for graceful "no data" error
    if (_error == 'no_data_in_period') {
      return _buildNoDataInPeriodView();
    }

    if (_currentLevel == 1) {
      return _buildCampaignView();
    } else if (_currentLevel == 2) {
      return _buildAdSetView();
    } else {
      return _buildAdView();
    }
  }

  Widget _buildCampaignView() {
    if (_campaignComparison == null) {
      return const Center(child: Text('No data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildComparisonCard(
          title: 'Campaign Performance',
          comparison: _campaignComparison!.comparison,
        ),
        const SizedBox(height: 24),
        Text(
          'Ad Sets',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_adSetComparisons == null || _adSetComparisons!.isEmpty)
          const Center(child: Text('No ad sets found'))
        else
          ..._adSetComparisons!.map(
            (adSet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAdSetCard(adSet),
            ),
          ),
      ],
    );
  }

  Widget _buildAdSetView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Collapsed campaign card
        _buildCollapsedCard(
          title: widget.campaignName,
          subtitle: 'Campaign',
          icon: Icons.campaign,
        ),
        const SizedBox(height: 16),
        // Ad set comparison
        if (_selectedAdSetComparison != null)
          _buildComparisonCard(
            title: 'Ad Set Performance',
            comparison: _selectedAdSetComparison!.comparison,
          ),
        const SizedBox(height: 24),
        Text(
          'Ads',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_adComparisons == null || _adComparisons!.isEmpty)
          const Center(child: Text('No ads found'))
        else
          ..._adComparisons!.map(
            (ad) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAdCard(ad),
            ),
          ),
      ],
    );
  }

  Widget _buildAdView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Collapsed campaign card
        _buildCollapsedCard(
          title: widget.campaignName,
          subtitle: 'Campaign',
          icon: Icons.campaign,
        ),
        const SizedBox(height: 12),
        // Collapsed ad set card
        _buildCollapsedCard(
          title: _selectedAdSetName ?? 'Ad Set',
          subtitle: 'Ad Set',
          icon: Icons.dashboard,
        ),
        const SizedBox(height: 16),
        // Ad comparison
        if (_selectedAdComparison != null)
          _buildComparisonCard(
            title: 'Ad Performance',
            comparison: _selectedAdComparison!.comparison,
          ),
      ],
    );
  }

  Widget _buildCollapsedCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        dense: true,
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required ComparisonResult comparison,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDatasetSummary(
                    comparison.dataset1,
                    'Previous',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDatasetSummary(
                    comparison.dataset2,
                    'Current',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildMetricsGrid(comparison.metricComparisons),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetSummary(
    ComparisonDataset dataset,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dataset.dateRange,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${dataset.getMetric('totalSpend').toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Total Spend',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(List<MetricComparison> metrics) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics.map((metric) => _buildMetricChip(metric)).toList(),
    );
  }

  Widget _buildMetricChip(MetricComparison metric) {
    final changePercent = metric.changePercent;
    final isPositive = changePercent >= 0;
    final isGoodChange =
        (isPositive && metric.isGoodWhenUp) ||
        (!isPositive && !metric.isGoodWhenUp);

    final color = isGoodChange ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '${changePercent.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${metric.previousValue.toStringAsFixed(1)} → ${metric.currentValue.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSetCard(AdSetComparison adSet) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _drillDownToAdSet(adSet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.dashboard, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adSet.adSetName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spend: \$${adSet.currentSpend.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdCard(AdComparison ad) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _drillDownToAd(ad),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.ad_units, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.adName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spend: \$${ad.currentSpend.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataInPeriodView() {
    final periodLabel = _timePeriod == TimePeriod.LAST_7_DAYS
        ? 'Last 7 Days'
        : 'Last 30 Days';
    final alternativePeriod = _timePeriod == TimePeriod.LAST_7_DAYS
        ? 'Last 30 Days'
        : 'Last 7 Days';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.orange[700]),
                const SizedBox(height: 16),
                Text(
                  'No Data in $periodLabel',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This campaign "${widget.campaignName}" doesn\'t have any performance data in the selected $periodLabel period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Suggestions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Try switching to "$alternativePeriod" using the toggle above\n'
                        '• This campaign may have been active earlier in the month\n'
                        '• Check if the campaign is still running or has been paused',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final newPeriod = _timePeriod == TimePeriod.LAST_7_DAYS
                        ? TimePeriod.LAST_30_DAYS
                        : TimePeriod.LAST_7_DAYS;
                    _onTimePeriodChanged(newPeriod);
                  },
                  icon: const Icon(Icons.sync),
                  label: Text('Switch to $alternativePeriod'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
