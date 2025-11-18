import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/enhanced_photo_viewer.dart';

class AdminProviderApprovalsScreen extends StatefulWidget {
  const AdminProviderApprovalsScreen({super.key});

  @override
  State<AdminProviderApprovalsScreen> createState() => _AdminProviderApprovalsScreenState();
}

class _AdminProviderApprovalsScreenState extends State<AdminProviderApprovalsScreen> {
  String _statusFilter = 'All Applications';
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildPendingApprovalsList(adminProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provider Approvals',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review and approve new healthcare provider applications',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
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
          Text(
            'Filter by status:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: ['All Applications', 'Pending', 'Approved', 'Rejected'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) => setState(() => _statusFilter = value!),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Filter by country:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _countryFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                {'code': 'All', 'name': 'All Countries'},
                {'code': 'US', 'name': 'United States'},
                {'code': 'ZA', 'name': 'South Africa'},
              ].map((country) {
                return DropdownMenuItem(
                  value: country['code'],
                  child: Row(
                    children: [
                      Text(_getCountryFlag(country['code']!)),
                      const SizedBox(width: 8),
                      Text(country['name']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _countryFilter = value!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsList(AdminProvider adminProvider) {
    // Get REAL practitioners from users collection
    var practitioners = adminProvider.realPractitionersFromUsers;
    
    // Apply status filter
    if (_statusFilter == 'Pending') {
      practitioners = practitioners.where((p) => p['isApproved'] != true).toList();
    } else if (_statusFilter == 'Approved') {
      practitioners = practitioners.where((p) => p['isApproved'] == true).toList();
    }
    // Note: 'Rejected' status not tracked in users collection
    // If 'All Applications', show all
    
    // Apply country filter
    if (_countryFilter != 'All') {
      practitioners = practitioners.where((p) => p['country'] == _countryFilter).toList();
    }
    
    if (practitioners.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
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
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No pending approvals',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All provider applications have been processed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: practitioners.map((practitioner) {
        // Extract data from Map
        final name = practitioner['name'] as String? ?? 'Unknown';
        final email = practitioner['email'] as String? ?? '';
        final specialization = practitioner['specialization'] as String? ?? 'General';
        final country = practitioner['country'] as String? ?? 'Unknown';
        final isApproved = practitioner['isApproved'] as bool? ?? false;
        final createdAt = practitioner['createdAt'];
        final patientCount = practitioner['patientCount'] as int? ?? 0;
        
        // Calculate days since registration
        int daysSince = 0;
        if (createdAt != null) {
          try {
            final date = createdAt is DateTime ? createdAt : (createdAt as dynamic).toDate();
            daysSince = DateTime.now().difference(date).inDays;
          } catch (e) {
            daysSince = 0;
          }
        }
        
        final statusColor = isApproved ? Colors.green : Colors.orange;
        final statusText = isApproved ? 'Approved' : 'Pending';
        
        // Get initials from name
        final nameParts = name.split(' ');
        final initials = nameParts.length >= 2 
            ? nameParts[0][0] + nameParts[1][0]
            : name.length >= 2 ? name.substring(0, 2) : name[0];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$specialization${email.isNotEmpty ? " • $email" : ""}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_getCountryFlag(country)),
                    const SizedBox(width: 4),
                    Text(country),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Registered ${daysSince > 0 ? "$daysSince days ago" : "today"}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: !isApproved ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _approvePractitioner(practitioner, adminProvider),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rejectPractitioner(practitioner, adminProvider),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ) : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Name', name),
                    _buildDetailRow('Email', email),
                    _buildDetailRow('Specialization', specialization),
                    _buildDetailRow('Country', country),
                    _buildDetailRow('Patient Count', patientCount.toString()),
                    _buildDetailRow('Status', statusText),
                    _buildDetailRow('User ID', practitioner['uid'] as String? ?? practitioner['id'] as String? ?? 'N/A'),
                    if (daysSince > 0)
                      _buildDetailRow('Registered', '$daysSince days ago'),
                    
                    // Verification Documents Section
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(height: 16),
                    _buildVerificationDocumentsSection(practitioner),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCountryFlag(String country) {
    switch (country) {
      case 'US':
      case 'USA':
        return '🇺🇸';
      case 'ZA':
      case 'RSA':
        return '🇿🇦';
      case 'All':
        return '🌍';
      default:
        return '🌍';
    }
  }

  /// Approve a practitioner
  void _approvePractitioner(Map<String, dynamic> practitioner, AdminProvider adminProvider) async {
    final name = practitioner['name'] as String? ?? 'Unknown';
    final userId = practitioner['uid'] as String? ?? practitioner['id'] as String?;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to identify practitioner'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Practitioner'),
        content: Text('Are you sure you want to approve $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Call the admin service to approve
      await adminProvider.approveRealPractitioner(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $name has been approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving practitioner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Reject a practitioner
  void _rejectPractitioner(Map<String, dynamic> practitioner, AdminProvider adminProvider) async {
    final name = practitioner['name'] as String? ?? 'Unknown';
    final userId = practitioner['uid'] as String? ?? practitioner['id'] as String?;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Unable to identify practitioner'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reasonController = TextEditingController();

    // Show confirmation dialog with reason
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Practitioner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject $name?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reason = reasonController.text.isEmpty 
          ? 'Rejected by admin' 
          : reasonController.text;
      
      // Call the admin service to reject
      await adminProvider.rejectRealPractitioner(userId, reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $name has been rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting practitioner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build verification documents section
  Widget _buildVerificationDocumentsSection(Map<String, dynamic> practitioner) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(practitioner['uid'] as String? ?? practitioner['id'] as String?)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Unable to load verification documents');
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final idDocuments = (userData?['idDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [];
        final practiceImages = (userData?['practiceImageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification Documents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // ID Documents
            _buildDocumentSubsection(
              'ID Documents',
              idDocuments,
              Icons.badge,
              AppTheme.primaryColor,
              isRequired: true,
            ),
            
            const SizedBox(height: 16),
            
            // Practice Images
            _buildDocumentSubsection(
              'Practice Images',
              practiceImages,
              Icons.business,
              AppTheme.infoColor,
              isRequired: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentSubsection(
    String title,
    List<String> documents,
    IconData icon,
    Color color,
    {required bool isRequired}
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
            Text(
              '$title (${documents.length})',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
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
