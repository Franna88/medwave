import 'package:flutter/material.dart';
import '../../../models/comparison/comparison_models.dart';
import '../../../models/comparison/comparison_list_models.dart';
import '../../../services/comparison_service.dart';
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

  // State
  TimePeriod _selectedTimePeriod = TimePeriod.THIS_MONTH;
  bool _isLoading = false;
  String? _error;

  // Comparison data
  List<CampaignComparison> _campaignComparisons = [];

  @override
  void initState() {
    super.initState();
    // Always load THIS_MONTH on initial page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComparisons();
    });
  }

  Future<void> _loadComparisons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔄 Loading campaign comparisons for $_selectedTimePeriod...');

      final comparisons = await _comparisonService.getAllCampaignsComparison(
        _selectedTimePeriod,
      );

      print('✅ Loaded ${comparisons.length} campaign comparisons');

      if (!mounted) return;

      setState(() {
        _campaignComparisons = comparisons;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comparisons: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onTimePeriodChanged(TimePeriod? newPeriod) {
    if (newPeriod != null && newPeriod != _selectedTimePeriod) {
      setState(() {
        _selectedTimePeriod = newPeriod;
      });
      _loadComparisons();
    }
  }

  void _openCampaignModal(CampaignComparison campaignComparison) {
    showDialog(
      context: context,
      builder: (context) => _DrillDownModal(
        campaignId: campaignComparison.campaignId,
        campaignName: campaignComparison.campaignName,
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
            onPressed: _loadComparisons,
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
                : _campaignComparisons.isEmpty
                ? _buildNoDataState()
                : _buildCampaignGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final dateRanges = TimePeriodCalculator.calculateDateRanges(
      _selectedTimePeriod,
    );
    final currentRange = TimePeriodCalculator.formatDateRange(
      dateRanges['currentStart']!,
      dateRanges['currentEnd']!,
    );
    final previousRange = TimePeriodCalculator.formatDateRange(
      dateRanges['previousStart']!,
      dateRanges['previousEnd']!,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time period indicator
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedTimePeriod.displayName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_campaignComparisons.length} campaigns',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Date ranges display
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Previous: $previousRange',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Current: $currentRange',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Period toggle
          SegmentedButton<TimePeriod>(
            segments: const [
              ButtonSegment(
                value: TimePeriod.THIS_WEEK,
                label: Text('This Week vs Last Week'),
                icon: Icon(Icons.calendar_view_week),
              ),
              ButtonSegment(
                value: TimePeriod.THIS_MONTH,
                label: Text('This Month vs Last Month'),
                icon: Icon(Icons.calendar_month),
              ),
            ],
            selected: {_selectedTimePeriod},
            onSelectionChanged: (Set<TimePeriod> newSelection) {
              _onTimePeriodChanged(newSelection.first);
            },
          ),
        ],
      ),
    );
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
      itemCount: _campaignComparisons.length,
      itemBuilder: (context, index) {
        final campaignComparison = _campaignComparisons[index];
        return _buildCampaignCard(campaignComparison);
      },
    );
  }

  Widget _buildCampaignCard(CampaignComparison campaignComparison) {
    final comparison = campaignComparison.comparison;
    final profitChange = campaignComparison.profitChange;
    final isPositive = profitChange >= 0;
    final profitColor = isPositive ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openCampaignModal(campaignComparison),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campaign name
              Text(
                campaignComparison.campaignName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15, // Reduced from 16 (titleMedium default)
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Comparison preview
              Row(
                children: [
                  Expanded(
                    child: _buildMetricPreview(
                      'Previous Spend',
                      '\$${comparison.dataset1.getMetric('totalSpend').toStringAsFixed(0)}',
                      Icons.arrow_back,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricPreview(
                      'Current Spend',
                      '\$${comparison.dataset2.getMetric('totalSpend').toStringAsFixed(0)}',
                      Icons.arrow_forward,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Profit change indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: profitColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: profitColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Profit: ${profitChange.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: profitColor,
                        fontSize: 11, // Reduced from 12
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Compare button
              Center(
                child: Text(
                  'Click to view details',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11, // Reduced from 12
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

  Widget _buildMetricPreview(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, // Reduced from 14
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ), // Reduced from 10
          textAlign: TextAlign.center,
        ),
      ],
    );
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
            onPressed: _loadComparisons,
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

  _DrillDownModalState() : _timePeriod = TimePeriod.THIS_WEEK;

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
          _error =
              'This Campaign does not have stats for the selected time period. Please try a different period.';
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
                value: TimePeriod.THIS_WEEK,
                label: Text('This Week vs Last Week'),
              ),
              ButtonSegment(
                value: TimePeriod.THIS_MONTH,
                label: Text('This Month vs Last Month'),
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
    final absChangePercent = changePercent.abs();

    // Check if change is effectively 0% (within 0.1% threshold)
    final isZeroChange = absChangePercent < 0.1;

    Color color;
    Widget changeIndicator;

    if (isZeroChange) {
      color = Colors.grey;
      changeIndicator = Text(
        '0.0%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      );
    } else {
      // Non-zero change: determine if good or bad
      final isPositive = changePercent >= 0;
      final isGoodChange =
          (isPositive && metric.isGoodWhenUp) ||
          (!isPositive && !metric.isGoodWhenUp);

      color = isGoodChange ? Colors.green : Colors.red;

      changeIndicator = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${absChangePercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      );
    }

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
          changeIndicator,
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
    final periodLabel = _timePeriod == TimePeriod.THIS_WEEK
        ? 'This Week vs Last Week'
        : 'This Month vs Last Month';
    final alternativePeriod = _timePeriod == TimePeriod.THIS_WEEK
        ? 'This Month vs Last Month'
        : 'This Week vs Last Week';

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
                    final newPeriod = _timePeriod == TimePeriod.THIS_WEEK
                        ? TimePeriod.THIS_MONTH
                        : TimePeriod.THIS_WEEK;
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
