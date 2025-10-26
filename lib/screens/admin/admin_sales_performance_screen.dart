import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gohighlevel_provider.dart';
import '../../theme/app_theme.dart';

class AdminSalesPerformanceScreen extends StatefulWidget {
  const AdminSalesPerformanceScreen({super.key});

  @override
  State<AdminSalesPerformanceScreen> createState() => _AdminSalesPerformanceScreenState();
}

class _AdminSalesPerformanceScreenState extends State<AdminSalesPerformanceScreen> {
  // Appointments tile filters
  String _appointmentsPipeline = 'andries'; // 'andries' or 'davide'
  String _appointmentsTimeframe = 'Last 7 Days';
  
  // Sales tile filters
  String _salesPipeline = 'andries'; // 'andries' or 'davide'
  String _salesTimeframe = 'Last 7 Days';

  @override
  void initState() {
    super.initState();
    // Ensure cumulative view mode is set when this screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ghlProvider = context.read<GoHighLevelProvider>();
      ghlProvider.initialize().then((_) {
        if (ghlProvider.viewMode != 'cumulative') {
          ghlProvider.setViewMode('cumulative');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<GoHighLevelProvider>(
        builder: (context, ghlProvider, child) {
          if (ghlProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error if GoHighLevel connection failed
          if (ghlProvider.error != null) {
            return _buildErrorState(ghlProvider.error!, ghlProvider);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(ghlProvider),
                const SizedBox(height: 24),
                // Performance Summary Tiles
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAppointmentsTile(ghlProvider)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSalesTile(ghlProvider)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GoHighLevelProvider ghlProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Performance',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track appointments and sales metrics with customizable filters',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Refresh button and status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (ghlProvider.isDataStale)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Data Stale',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: ghlProvider.refreshData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Data',
                    ),
                  ],
                ),
                Text(
                  'Last updated: ${ghlProvider.getTimeSinceLastRefresh()}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, GoHighLevelProvider ghlProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: ghlProvider.refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Appointments Performance Tile (Altus Pipeline - Erich)
  Widget _buildAppointmentsTile(GoHighLevelProvider ghlProvider) {
    // Get filtered data based on selections
    final filteredData = _getFilteredAppointmentsData(ghlProvider);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and filters
          Row(
            children: [
              Text(
                'Appointments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              // Pipeline selector dropdown
              _buildFilterDropdown(
                value: _appointmentsPipeline,
                items: ['andries', 'davide'],
                displayNames: {'andries': 'Andries', 'davide': 'Davide'},
                color: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _appointmentsPipeline = value!;
                  });
                },
              ),
              const SizedBox(width: 8),
              // Days filter dropdown
              _buildFilterDropdown(
                value: _appointmentsTimeframe,
                items: ['Last 7 Days', 'Last 14 Days', 'Last 30 Days'],
                displayNames: null,
                color: Colors.grey,
                onChanged: (value) {
                  setState(() {
                    _appointmentsTimeframe = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Metrics Grid (2x2)
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY Booked',
                  filteredData['booked'].toString(),
                  '(From System)',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'QTY Showed',
                  filteredData['showed'].toString(),
                  '(From System)',
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY No Show',
                  filteredData['noShow'].toString(),
                  '(From System)',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  'QTY Leads',
                  filteredData['leads'].toString(),
                  '(From System)',
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Sales Performance Tile (Andries Pipeline)
  Widget _buildSalesTile(GoHighLevelProvider ghlProvider) {
    // Get filtered data based on selections
    final filteredData = _getFilteredSalesData(ghlProvider);
    
    final bookedAppointments = filteredData['booked'] ?? 0;
    final callCompleted = filteredData['showed'] ?? 0;
    final noShow = filteredData['noShow'] ?? 0;
    final deposits = filteredData['deposits'] ?? 0;
    final cashCollected = filteredData['cashCollected'] ?? 0;

    final bookingsPercent = callCompleted > 0 
        ? (bookedAppointments / callCompleted * 100).toStringAsFixed(1)
        : '0.0';
    final noShowPercent = bookedAppointments > 0
        ? (noShow / bookedAppointments * 100).toStringAsFixed(1)
        : '0.0';
    final depositPercent = callCompleted > 0
        ? (deposits / callCompleted * 100).toStringAsFixed(1)
        : '0.0';
    final cashPercent = callCompleted > 0
        ? (cashCollected / callCompleted * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and filters
          Row(
            children: [
              Text(
                'Sales',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              const Spacer(),
              // Pipeline selector dropdown
              _buildFilterDropdown(
                value: _salesPipeline,
                items: ['andries', 'davide'],
                displayNames: {'andries': 'Andries', 'davide': 'Davide'},
                color: Colors.teal,
                onChanged: (value) {
                  setState(() {
                    _salesPipeline = value!;
                  });
                },
              ),
              const SizedBox(width: 8),
              // Days filter dropdown
              _buildFilterDropdown(
                value: _salesTimeframe,
                items: ['Last 7 Days', 'Last 14 Days', 'Last 30 Days'],
                displayNames: null,
                color: Colors.grey,
                onChanged: (value) {
                  setState(() {
                    _salesTimeframe = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bookings Section
          _buildSectionHeader('Bookings', context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY Bookings',
                  bookedAppointments.toString(),
                  '(From System)',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  '%',
                  '$bookingsPercent%',
                  '(of what was shown)',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // No Show Section
          _buildSectionHeader('No Show', context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY No Show',
                  noShow.toString(),
                  '(From System)',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  '%',
                  '$noShowPercent%',
                  '(of no show based on total bookings)',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Deposit Section
          _buildSectionHeader('Deposit', context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY Deposit',
                  deposits.toString(),
                  '(From System)',
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  '%',
                  '$depositPercent%',
                  '(based on Total that was Show)',
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Cash Collected Section
          _buildSectionHeader('Cash Collected', context),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'QTY Cash collected',
                  cashCollected.toString(),
                  '(From System)',
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricBox(
                  '%',
                  '$cashPercent%',
                  '(based on total show)',
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get filtered data for Appointments tile
  Map<String, int> _getFilteredAppointmentsData(GoHighLevelProvider ghlProvider) {
    // Ensure we have pipeline performance data
    if (ghlProvider.pipelinePerformance == null) {
      print('⚠️ APPOINTMENTS: No pipeline performance data available');
      return {
        'booked': 0,
        'showed': 0,
        'noShow': 0,
        'leads': 0,
      };
    }

    print('📊 APPOINTMENTS: Pipeline = $_appointmentsPipeline, Mode = ${ghlProvider.viewMode}');

    // Use pipeline-specific data based on selection (works in both cumulative and snapshot mode)
    if (_appointmentsPipeline == 'andries') {
      print('📊 APPOINTMENTS: Andries - Booked: ${ghlProvider.andriesBookedAppointments}, Showed: ${ghlProvider.andriesCallCompleted}, Opportunities: ${ghlProvider.andriesOpportunities}');
      
      return {
        'booked': ghlProvider.andriesBookedAppointments,
        'showed': ghlProvider.andriesCallCompleted,
        'noShow': ghlProvider.andriesNoShowCancelledDisqualified,
        'leads': ghlProvider.andriesOpportunities,
      };
    } else if (_appointmentsPipeline == 'davide') {
      print('📊 APPOINTMENTS: Davide - Booked: ${ghlProvider.davideBookedAppointments}, Showed: ${ghlProvider.davideCallCompleted}, Opportunities: ${ghlProvider.davideOpportunities}');
      
      return {
        'booked': ghlProvider.davideBookedAppointments,
        'showed': ghlProvider.davideCallCompleted,
        'noShow': ghlProvider.davideNoShowCancelledDisqualified,
        'leads': ghlProvider.davideOpportunities,
      };
    }
    
    // Default fallback
    return {
      'booked': 0,
      'showed': 0,
      'noShow': 0,
      'leads': 0,
    };
  }

  /// Get filtered data for Sales tile
  Map<String, int> _getFilteredSalesData(GoHighLevelProvider ghlProvider) {
    // Ensure we have pipeline performance data
    if (ghlProvider.pipelinePerformance == null) {
      print('⚠️ SALES: No pipeline performance data available');
      return {
        'booked': 0,
        'showed': 0,
        'noShow': 0,
        'deposits': 0,
        'cashCollected': 0,
      };
    }

    print('📊 SALES: Pipeline = $_salesPipeline, Mode = ${ghlProvider.viewMode}');

    // Use pipeline-specific data based on selection (works in both cumulative and snapshot mode)
    if (_salesPipeline == 'andries') {
      print('📊 SALES: Andries - Booked: ${ghlProvider.andriesBookedAppointments}, Showed: ${ghlProvider.andriesCallCompleted}, Deposits: ${ghlProvider.andriesDeposits}, Cash: ${ghlProvider.andriesCashCollected}');
      
      return {
        'booked': ghlProvider.andriesBookedAppointments,
        'showed': ghlProvider.andriesCallCompleted,
        'noShow': ghlProvider.andriesNoShowCancelledDisqualified,
        'deposits': ghlProvider.andriesDeposits,
        'cashCollected': ghlProvider.andriesCashCollected,
      };
    } else if (_salesPipeline == 'davide') {
      print('📊 SALES: Davide - Booked: ${ghlProvider.davideBookedAppointments}, Showed: ${ghlProvider.davideCallCompleted}, Deposits: ${ghlProvider.davideDeposits}, Cash: ${ghlProvider.davideCashCollected}');
      
      return {
        'booked': ghlProvider.davideBookedAppointments,
        'showed': ghlProvider.davideCallCompleted,
        'noShow': ghlProvider.davideNoShowCancelledDisqualified,
        'deposits': ghlProvider.davideDeposits,
        'cashCollected': ghlProvider.davideCashCollected,
      };
    }
    
    // Default fallback
    return {
      'booked': 0,
      'showed': 0,
      'noShow': 0,
      'deposits': 0,
      'cashCollected': 0,
    };
  }

  /// Build filter dropdown widget
  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    Map<String, String>? displayNames,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          icon: Icon(Icons.arrow_drop_down, color: color, size: 16),
          items: items.map((item) {
            final displayText = displayNames?[item] ?? item;
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Build section header for Sales tile
  Widget _buildSectionHeader(String title, BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  /// Build metric box for tiles
  Widget _buildMetricBox(String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

