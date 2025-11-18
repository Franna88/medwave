import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin/healthcare_provider.dart';
import '../../models/practitioner_application.dart';
import '../../theme/app_theme.dart';
import '../../widgets/enhanced_photo_viewer.dart';

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

          // Use real practitioners from users collection (actual app users)
          final realPractitioners = adminProvider.realPractitionersFromUsers;
          final filteredRealPractitioners = _getFilteredRealPractitionersFromUsers(realPractitioners);
        
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
                _buildRealProvidersTable(filteredRealPractitioners),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Filter real practitioners from users collection
  List<Map<String, dynamic>> _getFilteredRealPractitionersFromUsers(List<Map<String, dynamic>> practitioners) {
    var filtered = practitioners;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((practitioner) {
        final searchLower = _searchQuery.toLowerCase();
        final name = (practitioner['name'] as String? ?? '').toLowerCase();
        final email = (practitioner['email'] as String? ?? '').toLowerCase();
        final specialization = (practitioner['specialization'] as String? ?? '').toLowerCase();
        
        return name.contains(searchLower) ||
               email.contains(searchLower) ||
               specialization.contains(searchLower);
      }).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      if (_statusFilter == 'Approved') {
        filtered = filtered.where((p) => p['isApproved'] == true).toList();
      } else if (_statusFilter == 'Pending') {
        filtered = filtered.where((p) => p['isApproved'] != true).toList();
      }
    }

    // Filter by country
    if (_countryFilter != 'All') {
      filtered = filtered.where((practitioner) => 
          practitioner['country'] == _countryFilter).toList();
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
    // Use real practitioners from users collection
    final total = adminProvider.realPractitionersCount;
    final approved = adminProvider.realApprovedPractitionersCount;
    final pending = adminProvider.realPendingPractitionersCount;
    final approvalRate = total > 0 ? (approved / total * 100) : 0.0;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Providers',
            total.toString(),
            Icons.business,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved',
            approved.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending',
            pending.toString(),
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approval Rate',
            '${approvalRate.toStringAsFixed(1)}%',
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
              items: [
                {'code': 'All', 'name': 'All Countries'},
                {'code': 'US', 'name': 'United States'},
                {'code': 'ZA', 'name': 'South Africa'},
              ].map((country) {
                return DropdownMenuItem(
                  value: country['code'],
                  child: Text(country['name']!),
                );
              }).toList(),
              onChanged: (value) => setState(() => _countryFilter = value!),
            ),
          ),
        ],
      ),
    );
  }

  /// Build table for real practitioners from users collection
  Widget _buildRealProvidersTable(List<Map<String, dynamic>> practitioners) {
    if (practitioners.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No practitioners found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
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
                  label: Text('Specialization'),
                  size: ColumnSize.L,
                ),
                DataColumn2(
                  label: Text('Country'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Patients'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Status'),
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Registered'),
                  size: ColumnSize.M,
                ),
                DataColumn2(
                  label: Text('Actions'),
                  size: ColumnSize.M,
                ),
              ],
              rows: practitioners.map((practitioner) {
                final name = practitioner['name'] as String? ?? 'Unknown';
                final email = practitioner['email'] as String? ?? '';
                final specialization = practitioner['specialization'] as String? ?? 'General';
                final country = practitioner['country'] as String? ?? 'Unknown';
                final isApproved = practitioner['isApproved'] as bool? ?? false;
                final patientCount = practitioner['patientCount'] as int? ?? 0;
                final createdAt = practitioner['createdAt'];
                
                return DataRow2(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(Text(specialization)),
                    DataCell(
                      Row(
                        children: [
                          Text(_getCountryFlag(country)),
                          const SizedBox(width: 4),
                          Text(country),
                        ],
                      ),
                    ),
                    DataCell(Text(patientCount.toString())),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      ),
                    ),
                    DataCell(
                      Text(
                        createdAt != null ? _formatTimestamp(createdAt) : 'N/A',
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
                            onPressed: () => _viewRealPractitioner(practitioner),
                            tooltip: 'View Details',
                          ),
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
      case 'US':
      case 'USA':
        return '🇺🇸';
      case 'ZA':
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

  /// Format timestamp from Firebase
  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays < 1) {
        return 'Today';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  /// View real practitioner details from users collection
  void _viewRealPractitioner(Map<String, dynamic> practitioner) async {
    // Get user ID from practitioner data
    final userId = practitioner['uid'] as String? ?? practitioner['id'] as String?;
    
    if (userId == null) {
      _showSnackBar('User ID not found', Colors.red);
      return;
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Fetch full user document to get bank details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (!userDoc.exists) {
        _showSnackBar('User document not found', Colors.red);
        return;
      }
      
      final userData = userDoc.data()!;
      final hasBankAccount = userData['bankAccountNumber'] != null && 
                            userData['bankAccountNumber'].toString().isNotEmpty;
      
      if (!mounted) return;
      
      // Show practitioner details dialog with bank information
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(practitioner['name'] as String? ?? 'Practitioner Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Personal Details
                _buildDetailRow('Name', practitioner['name'] as String? ?? 'N/A'),
                _buildDetailRow('Email', practitioner['email'] as String? ?? 'N/A'),
                _buildDetailRow('Specialization', practitioner['specialization'] as String? ?? 'N/A'),
                _buildDetailRow('Country', practitioner['country'] as String? ?? 'N/A'),
                _buildDetailRow('Status', (practitioner['isApproved'] == true) ? 'Approved' : 'Pending'),
                _buildDetailRow('Patient Count', (practitioner['patientCount'] as int? ?? 0).toString()),
                _buildDetailRow('User ID', userId),
                _buildDetailRow('Registered', _formatTimestamp(practitioner['createdAt'])),
                
                // Bank Account Details Section
                const SizedBox(height: 16),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      hasBankAccount ? Icons.account_balance : Icons.warning_amber,
                      color: hasBankAccount ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bank Account Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: hasBankAccount ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (hasBankAccount) ...[
                  _buildDetailRow('Bank Name', userData['bankName'] as String? ?? 'N/A'),
                  _buildDetailRow('Account Holder', userData['bankAccountName'] as String? ?? 'N/A'),
                  _buildDetailRow('Account Number', userData['bankAccountNumber'] as String? ?? 'N/A'),
                  _buildDetailRow('Branch Code', userData['bankCode'] as String? ?? 'N/A'),
                  _buildDetailRow('Added On', 
                    userData['subaccountCreatedAt'] != null 
                      ? _formatTimestamp(userData['subaccountCreatedAt']) 
                      : 'N/A'),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Practitioner has not added bank account details yet',
                            style: TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Verification Documents Section
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      userData['idDocumentUrls'] != null && (userData['idDocumentUrls'] as List).isNotEmpty
                          ? Icons.verified_user
                          : Icons.warning_amber,
                      color: userData['idDocumentUrls'] != null && (userData['idDocumentUrls'] as List).isNotEmpty
                          ? Colors.green
                          : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Verification Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildVerificationDocumentsSection(userData),
              ],
            ),
          ),
          actions: [
            if (hasBankAccount)
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Bank Details'),
                onPressed: () {
                  // Copy bank details to clipboard for payout processing
                  final bankDetails = '''
Bank: ${userData['bankName'] ?? 'N/A'}
Account Holder: ${userData['bankAccountName'] ?? 'N/A'}
Account Number: ${userData['bankAccountNumber'] ?? 'N/A'}
Branch Code: ${userData['bankCode'] ?? 'N/A'}
                  '''.trim();
                  Clipboard.setData(ClipboardData(text: bankDetails));
                  _showSnackBar('Bank details copied to clipboard', Colors.green);
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error loading practitioner details: $e', Colors.red);
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Build verification documents section
  Widget _buildVerificationDocumentsSection(Map<String, dynamic> userData) {
    final idDocuments = (userData['idDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final practiceImages = (userData['practiceImageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final idUploadedAt = userData['idDocumentUploadedAt'];
    final practiceUploadedAt = userData['practiceImageUploadedAt'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ID Documents
        _buildDocumentSubsection(
          'ID Documents',
          idDocuments,
          Icons.badge,
          AppTheme.primaryColor,
          isRequired: true,
          uploadedAt: idUploadedAt,
        ),
        
        const SizedBox(height: 16),
        
        // Practice Images
        _buildDocumentSubsection(
          'Practice Images',
          practiceImages,
          Icons.business,
          AppTheme.infoColor,
          isRequired: false,
          uploadedAt: practiceUploadedAt,
        ),
      ],
    );
  }

  Widget _buildDocumentSubsection(
    String title,
    List<String> documents,
    IconData icon,
    Color color,
    {required bool isRequired, dynamic uploadedAt}
  ) {
    if (documents.isEmpty && !isRequired) {
      return Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(
            '$title: None uploaded',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      );
    }
    
    if (documents.isEmpty && isRequired) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.errorColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.errorColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ No $title uploaded (Required)',
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title (${documents.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (uploadedAt != null)
                    Text(
                      'Uploaded: ${_formatTimestamp(uploadedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: documents.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EnhancedPhotoViewer(
                      photoUrls: documents,
                      initialIndex: entry.key,
                      photoLabels: documents.asMap().entries.map((e) => 
                        '$title ${e.key + 1}'
                      ).toList(),
                      enableComparison: false,
                    ),
                  ),
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    entry.value,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('❌ Error loading image: $error');
                      debugPrint('Image URL: ${entry.value}');
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EnhancedPhotoViewer(
                  photoUrls: documents,
                  photoLabels: documents.asMap().entries.map((e) => 
                    '$title ${e.key + 1}'
                  ).toList(),
                  enableComparison: false,
                ),
              ),
            );
          },
          icon: const Icon(Icons.open_in_full, size: 16),
          label: Text('View All $title'),
        ),
      ],
    );
  }

}
