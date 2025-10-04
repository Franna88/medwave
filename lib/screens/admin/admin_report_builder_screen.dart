import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';

class AdminReportBuilderScreen extends StatefulWidget {
  const AdminReportBuilderScreen({super.key});

  @override
  State<AdminReportBuilderScreen> createState() => _AdminReportBuilderScreenState();
}

class _AdminReportBuilderScreenState extends State<AdminReportBuilderScreen> {
  String _reportType = 'Provider Performance';
  String _timeframe = 'Last 30 Days';
  String _country = 'All';
  final List<String> _selectedMetrics = [];
  final TextEditingController _reportNameController = TextEditingController();

  @override
  void dispose() {
    _reportNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Builder Panel
                Expanded(
                  flex: 2,
                  child: _buildReportBuilderPanel(),
                ),
                const SizedBox(width: 24),
                // Preview Panel
                Expanded(
                  flex: 3,
                  child: _buildPreviewPanel(adminProvider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportBuilderPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Report Builder',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportNameField(),
                const SizedBox(height: 24),
                _buildReportTypeSection(),
                const SizedBox(height: 24),
                _buildTimeframeSection(),
                const SizedBox(height: 24),
                _buildCountrySection(),
                const SizedBox(height: 24),
                _buildMetricsSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reportNameController,
          decoration: InputDecoration(
            hintText: 'Enter report name...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.description),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...['Provider Performance', 'Patient Progress', 'Financial Summary', 'Usage Analytics'].map((type) {
          return RadioListTile<String>(
            title: Text(type),
            value: type,
            groupValue: _reportType,
            onChanged: (value) => setState(() => _reportType = value!),
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTimeframeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeframe',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _timeframe,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.calendar_today),
          ),
          items: [
            'Last 7 Days',
            'Last 30 Days',
            'Last 3 Months',
            'Last 6 Months',
            'Last Year',
            'Custom Range'
          ].map((timeframe) {
            return DropdownMenuItem(value: timeframe, child: Text(timeframe));
          }).toList(),
          onChanged: (value) => setState(() => _timeframe = value!),
        ),
      ],
    );
  }

  Widget _buildCountrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country Filter',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _country,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.public),
          ),
          items: ['All', 'USA', 'RSA'].map((country) {
            return DropdownMenuItem(
              value: country,
              child: Row(
                children: [
                  Text(_getCountryFlag(country)),
                  const SizedBox(width: 8),
                  Text(country == 'All' ? 'All Countries' : country),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _country = value!),
        ),
      ],
    );
  }

  Widget _buildMetricsSection() {
    final availableMetrics = _getAvailableMetrics(_reportType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Metrics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...availableMetrics.map((metric) {
          return CheckboxListTile(
            title: Text(metric),
            value: _selectedMetrics.contains(metric),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedMetrics.add(metric);
                } else {
                  _selectedMetrics.remove(metric);
                }
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generateReport,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Generate Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saveReportTemplate,
            icon: const Icon(Icons.save),
            label: const Text('Save Template'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel(AdminProvider adminProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Report Preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.download),
                  tooltip: 'Export Report',
                ),
                IconButton(
                  onPressed: _shareReport,
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Report',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_reportNameController.text.isNotEmpty) ...[
                  Text(
                    _reportNameController.text,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Report Type: $_reportType',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Timeframe: $_timeframe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Country: $_country',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                if (_selectedMetrics.isNotEmpty) ...[
                  Text(
                    'Selected Metrics:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._selectedMetrics.map((metric) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getMetricIcon(metric),
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  _getMockMetricValue(metric),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select metrics to preview report',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableMetrics(String reportType) {
    switch (reportType) {
      case 'Provider Performance':
        return [
          'Total Providers',
          'Active Providers',
          'Average Patients per Provider',
          'Provider Approval Rate',
          'Provider Satisfaction Score',
        ];
      case 'Patient Progress':
        return [
          'Total Patients',
          'Active Treatments',
          'Recovery Rate',
          'Average Treatment Duration',
          'Patient Satisfaction Score',
        ];
      case 'Financial Summary':
        return [
          'Total Revenue',
          'Monthly Recurring Revenue',
          'Average Revenue per Provider',
          'Payment Success Rate',
          'Outstanding Payments',
        ];
      case 'Usage Analytics':
        return [
          'Total Sessions',
          'Average Session Duration',
          'Feature Usage Statistics',
          'User Engagement Rate',
          'Platform Uptime',
        ];
      default:
        return [];
    }
  }

  IconData _getMetricIcon(String metric) {
    if (metric.contains('Provider')) return Icons.business;
    if (metric.contains('Patient')) return Icons.people;
    if (metric.contains('Revenue') || metric.contains('Payment')) return Icons.attach_money;
    if (metric.contains('Session') || metric.contains('Usage')) return Icons.analytics;
    if (metric.contains('Rate') || metric.contains('Score')) return Icons.trending_up;
    return Icons.assessment;
  }

  String _getMockMetricValue(String metric) {
    // Mock values for preview
    switch (metric) {
      case 'Total Providers':
        return '245';
      case 'Active Providers':
        return '198';
      case 'Average Patients per Provider':
        return '8.3';
      case 'Provider Approval Rate':
        return '94.2%';
      case 'Provider Satisfaction Score':
        return '4.7/5';
      case 'Total Patients':
        return '2,034';
      case 'Active Treatments':
        return '1,642';
      case 'Recovery Rate':
        return '78.5%';
      case 'Average Treatment Duration':
        return '42 days';
      case 'Patient Satisfaction Score':
        return '4.6/5';
      case 'Total Revenue':
        return '\$124,500';
      case 'Monthly Recurring Revenue':
        return '\$18,750';
      case 'Average Revenue per Provider':
        return '\$508';
      case 'Payment Success Rate':
        return '97.3%';
      case 'Outstanding Payments':
        return '\$3,250';
      case 'Total Sessions':
        return '12,456';
      case 'Average Session Duration':
        return '24 min';
      case 'Feature Usage Statistics':
        return '85%';
      case 'User Engagement Rate':
        return '72%';
      case 'Platform Uptime':
        return '99.8%';
      default:
        return 'N/A';
    }
  }

  String _getCountryFlag(String country) {
    switch (country) {
      case 'USA':
        return '🇺🇸';
      case 'RSA':
        return '🇿🇦';
      case 'All':
        return '🌍';
      default:
        return '🌍';
    }
  }

  void _generateReport() {
    if (_selectedMetrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one metric')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating ${_reportNameController.text.isEmpty ? _reportType : _reportNameController.text} report...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveReportTemplate() {
    if (_reportNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a report name')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report template "${_reportNameController.text}" saved successfully')),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting report to PDF...')),
    );
  }

  void _shareReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing report...')),
    );
  }
}
