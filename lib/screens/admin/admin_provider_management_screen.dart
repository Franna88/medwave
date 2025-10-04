import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/healthcare_provider.dart';
import '../../models/practitioner_application.dart';
import '../../theme/app_theme.dart';

class AdminProviderManagementScreen extends StatefulWidget {
  const AdminProviderManagementScreen({super.key});

  @override
  State<AdminProviderManagementScreen> createState() => _AdminProviderManagementScreenState();
}

class _AdminProviderManagementScreenState extends State<AdminProviderManagementScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _countryFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use real Firebase data instead of mock data
          final realPractitioners = adminProvider.realPractitioners;
          final filteredProviders = _getFilteredRealProviders(realPractitioners);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatisticsCards(adminProvider),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildProvidersTable(filteredProviders),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Filter real practitioner applications based on search and filter criteria
  List<PractitionerApplication> _getFilteredRealProviders(List<PractitionerApplication> practitioners) {
    var filtered = practitioners;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((practitioner) {
        final searchLower = _searchQuery.toLowerCase();
        return practitioner.firstName.toLowerCase().contains(searchLower) ||
               practitioner.lastName.toLowerCase().contains(searchLower) ||
               practitioner.email.toLowerCase().contains(searchLower) ||
               practitioner.practiceLocation.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      final statusToFilter = _statusFilter.toLowerCase();
      filtered = filtered.where((practitioner) => 
          practitioner.status.name.toLowerCase() == statusToFilter).toList();
    }

    // Filter by country
    if (_countryFilter != 'All') {
      filtered = filtered.where((practitioner) => 
          practitioner.country == _countryFilter).toList();
    }

    return filtered;
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Provider Management',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage all healthcare providers across regions',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(AdminProvider adminProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Providers',
            adminProvider.totalProviders.toString(),
            Icons.business,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved',
            adminProvider.totalApprovedProviders.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending',
            adminProvider.totalPendingApprovals.toString(),
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approval Rate',
            '${adminProvider.approvalRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search providers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'Approved', 'Pending'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) => setState(() => _statusFilter = value!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _countryFilter,
              decoration: InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'USA', 'RSA'].map((country) {
                return DropdownMenuItem(value: country, child: Text(country));
              }).toList(),
              onChanged: (value) => setState(() => _countryFilter = value!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersTable(List<PractitionerApplication> practitioners) {
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'All Providers (${practitioners.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 600,
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 20,
              minWidth: 1000,
              columns: const [
                DataColumn2(
                  label: Text('Provider'),
                  size: ColumnSize.L,
                ),
                DataColumn2(
                  label: Text('Company'),
                  size: ColumnSize.L,
                ),
                DataColumn2(
                  label: Text('Country'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Package'),
                  size: ColumnSize.M,
                ),
                DataColumn2(
                  label: Text('Status'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Registration'),
                  size: ColumnSize.M,
                ),
                DataColumn2(
                  label: Text('Actions'),
                  size: ColumnSize.M,
                ),
              ],
              rows: practitioners.map((practitioner) {
                return DataRow2(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${practitioner.firstName} ${practitioner.lastName}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            practitioner.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(practitioner.practiceLocation)),
                    DataCell(
                      Row(
                        children: [
                          Text(_getCountryFlag(practitioner.country)),
                          const SizedBox(width: 4),
                          Text(practitioner.country),
                        ],
                      ),
                    ),
                    DataCell(Text(practitioner.specialization)),
                    DataCell(_buildStatusChipForPractitioner(practitioner)),
                    DataCell(
                      Text(
                        _formatDate(practitioner.submittedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _viewPractitioner(practitioner),
                            tooltip: 'View Details',
                          ),
                          if (practitioner.status != 'approved') ...[
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _approvePractitioner(practitioner),
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _rejectPractitioner(practitioner),
                              tooltip: 'Reject',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(HealthcareProvider provider) {
    final isApproved = provider.isApproved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isApproved ? 'Approved' : 'Pending',
        style: TextStyle(
          color: isApproved ? Colors.green : Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<HealthcareProvider> _getFilteredProviders(AdminProvider adminProvider) {
    var providers = adminProvider.providers;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      providers = providers.where((provider) {
        return provider.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               provider.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               provider.fullCompanyName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      providers = providers.where((provider) {
        return _statusFilter == 'Approved' ? provider.isApproved : !provider.isApproved;
      }).toList();
    }

    // Filter by country
    if (_countryFilter != 'All') {
      providers = providers.where((provider) {
        return provider.country == _countryFilter;
      }).toList();
    }

    return providers;
  }

  String _getCountryFlag(String country) {
    switch (country) {
      case 'USA':
        return '🇺🇸';
      case 'RSA':
        return '🇿🇦';
      default:
        return '🌍';
    }
  }

  void _viewProvider(HealthcareProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(provider.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company: ${provider.fullCompanyName}'),
            Text('Email: ${provider.email}'),
            Text('Phone: ${provider.directPhoneNumber}'),
            Text('Address: ${provider.businessAddress}'),
            Text('Package: ${provider.package}'),
            Text('Sales Person: ${provider.salesPerson}'),
            if (provider.additionalNotes != null)
              Text('Notes: ${provider.additionalNotes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _approveProvider(HealthcareProvider provider) {
    context.read<AdminProvider>().approveProvider(provider.id, 'Approved by admin');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${provider.fullName} has been approved')),
    );
  }

  void _rejectProvider(HealthcareProvider provider) {
    context.read<AdminProvider>().rejectProvider(provider.id, 'Rejected by admin');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${provider.fullName} has been rejected')),
    );
  }

  /// Build status chip for practitioner application
  Widget _buildStatusChipForPractitioner(PractitionerApplication practitioner) {
    Color color;
    String text;
    
    switch (practitioner.status.name.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        text = 'Approved';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = practitioner.status.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return '$difference days ago';
    }
  }

  /// View practitioner details
  void _viewPractitioner(PractitionerApplication practitioner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${practitioner.firstName} ${practitioner.lastName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', practitioner.email),
              _buildDetailRow('License Number', practitioner.licenseNumber),
              _buildDetailRow('Specialization', practitioner.specialization),
              _buildDetailRow('Years of Experience', '${practitioner.yearsOfExperience}'),
              _buildDetailRow('Practice Location', practitioner.practiceLocation),
              _buildDetailRow('Country', practitioner.country),
              _buildDetailRow('Status', practitioner.status.name),
              _buildDetailRow('Created', _formatDate(practitioner.submittedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Approve practitioner
  void _approvePractitioner(PractitionerApplication practitioner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Practitioner'),
        content: Text('Are you sure you want to approve ${practitioner.firstName} ${practitioner.lastName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminProvider>().approveProvider(practitioner.id, 'Approved by admin');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${practitioner.firstName} ${practitioner.lastName} approved')),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  /// Reject practitioner
  void _rejectPractitioner(PractitionerApplication practitioner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Practitioner'),
        content: Text('Are you sure you want to reject ${practitioner.firstName} ${practitioner.lastName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminProvider>().rejectProvider(practitioner.id, 'Rejected by admin');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${practitioner.firstName} ${practitioner.lastName} rejected')),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

}
