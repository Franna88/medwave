import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin/warehouse_user.dart';
import '../../theme/app_theme.dart';
import '../../utils/role_manager.dart';

class WarehouseUserManagementScreen extends StatefulWidget {
  const WarehouseUserManagementScreen({super.key});

  @override
  State<WarehouseUserManagementScreen> createState() =>
      _WarehouseUserManagementScreenState();
}

class _WarehouseUserManagementScreenState extends State<WarehouseUserManagementScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _countryFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Load warehouse users when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();

      // Only Super Admins can access this screen
      if (authProvider.userRole == UserRole.superAdmin) {
        context.read<AdminProvider>().loadWarehouseUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Access control: Only Super Admins can manage warehouse users
    if (authProvider.userRole != UserRole.superAdmin) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Only Super Administrators can manage warehouse users.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredUsers = _getFilteredWarehouseUsers(
            adminProvider.warehouseUsers,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, authProvider),
                const SizedBox(height: 24),
                _buildWarehouseUserStatistics(adminProvider),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildWarehouseUsersTable(filteredUsers),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Filter warehouse users based on search query and filters
  List<WarehouseUser> _getFilteredWarehouseUsers(List<WarehouseUser> users) {
    var filtered = users;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final searchLower = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(searchLower) ||
            user.email.toLowerCase().contains(searchLower) ||
            user.phoneNumber.toLowerCase().contains(searchLower) ||
            user.city.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      WarehouseUserStatus? statusToFilter;
      switch (_statusFilter) {
        case 'Active':
          statusToFilter = WarehouseUserStatus.active;
          break;
        case 'Inactive':
          statusToFilter = WarehouseUserStatus.inactive;
          break;
        case 'Suspended':
          statusToFilter = WarehouseUserStatus.suspended;
          break;
      }
      if (statusToFilter != null) {
        filtered =
            filtered.where((user) => user.status == statusToFilter).toList();
      }
    }

    // Filter by country
    if (_countryFilter != 'All') {
      filtered =
          filtered.where((user) => user.country == _countryFilter).toList();
    }

    return filtered;
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warehouse User Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage warehouse staff profiles and credentials',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateWarehouseUserDialog(context, authProvider),
          icon: const Icon(Icons.person_add),
          label: const Text('Add Warehouse User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseUserStatistics(AdminProvider adminProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Users',
            adminProvider.totalWarehouseUsers.toString(),
            Icons.warehouse,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active',
            adminProvider.activeWarehouseUsers.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Inactive',
            adminProvider.inactiveWarehouseUsers.toString(),
            Icons.pause_circle,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Suspended',
            adminProvider.suspendedWarehouseUsers.toString(),
            Icons.block,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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
                hintText: 'Search warehouse users...',
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
              items: ['All', 'Active', 'Inactive', 'Suspended'].map((status) {
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
                return DropdownMenuItem(
                  value: country,
                  child: Row(
                    children: [
                      if (country != 'All') ...[
                        Text(_getCountryFlag(country)),
                        const SizedBox(width: 8),
                      ],
                      Text(country),
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

  Widget _buildWarehouseUsersTable(List<WarehouseUser> users) {
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
              'Warehouse Users (${users.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 600,
            child: users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warehouse_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No warehouse users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "Add Warehouse User" to create your first warehouse user',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : DataTable2(
                    columnSpacing: 12,
                    horizontalMargin: 20,
                    minWidth: 1000,
                    columns: const [
                      DataColumn2(label: Text('User'), size: ColumnSize.L),
                      DataColumn2(label: Text('Contact'), size: ColumnSize.M),
                      DataColumn2(label: Text('Location'), size: ColumnSize.M),
                      DataColumn2(label: Text('Status'), size: ColumnSize.S),
                      DataColumn2(label: Text('Last Login'), size: ColumnSize.M),
                      DataColumn2(label: Text('Created'), size: ColumnSize.M),
                      DataColumn2(label: Text('Actions'), size: ColumnSize.M),
                    ],
                    rows: users.map((user) {
                      return DataRow2(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      _getStatusColor(user.status)
                                          .withOpacity(0.1),
                                  child: Text(
                                    user.initials,
                                    style: TextStyle(
                                      color: _getStatusColor(user.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              user.phoneNumber,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                Text(_getCountryFlag(user.country)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${user.city}, ${user.province}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(_buildStatusChip(user.status)),
                          DataCell(
                            Text(
                              user.lastLogin != null
                                  ? _formatDateTime(user.lastLogin!)
                                  : 'Never',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatDateTime(user.createdAt),
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editWarehouseUser(user),
                                  tooltip: 'Edit User',
                                ),
                                IconButton(
                                  icon: Icon(
                                    user.status == WarehouseUserStatus.active
                                        ? Icons.block
                                        : Icons.check_circle,
                                    size: 20,
                                    color: user.status == WarehouseUserStatus.active
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  onPressed: () => _toggleWarehouseUserStatus(user),
                                  tooltip: user.status == WarehouseUserStatus.active
                                      ? 'Suspend User'
                                      : 'Activate User',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  onPressed: () => _showMoreOptions(user),
                                  tooltip: 'More Options',
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

  Color _getStatusColor(WarehouseUserStatus status) {
    switch (status) {
      case WarehouseUserStatus.active:
        return Colors.green;
      case WarehouseUserStatus.inactive:
        return Colors.orange;
      case WarehouseUserStatus.suspended:
        return Colors.red;
    }
  }

  Widget _buildStatusChip(WarehouseUserStatus status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 30) {
      return '$difference days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Show create warehouse user dialog
  void _showCreateWarehouseUserDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final provinceController = TextEditingController();
    final postalCodeController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCountry = 'RSA';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Warehouse User'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        hintText: '+27 XX XXX XXXX',
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),

                    // Login Credentials Section
                    Text(
                      'Login Credentials',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (!value!.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (value!.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Address Section
                    Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: provinceController,
                            decoration: const InputDecoration(
                              labelText: 'Province/State',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: postalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Postal Code',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCountry,
                            decoration: const InputDecoration(
                              labelText: 'Country',
                              border: OutlineInputBorder(),
                            ),
                            items: ['USA', 'RSA'].map((country) {
                              return DropdownMenuItem(
                                value: country,
                                child: Row(
                                  children: [
                                    Text(_getCountryFlag(country)),
                                    const SizedBox(width: 8),
                                    Text(country),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedCountry = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Notes Section
                    Text(
                      'Additional Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context);

                  final success =
                      await context.read<AdminProvider>().createWarehouseUser(
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            phoneNumber: phoneController.text.trim(),
                            address: addressController.text.trim(),
                            city: cityController.text.trim(),
                            province: provinceController.text.trim(),
                            postalCode: postalCodeController.text.trim(),
                            country: selectedCountry,
                            countryName: selectedCountry == 'USA'
                                ? 'United States'
                                : 'South Africa',
                            createdBy: authProvider.user?.uid ?? 'unknown',
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );

                  if (!context.mounted) return;

                  if (success) {
                    // Reload the warehouse users list to show the new user
                    await context.read<AdminProvider>().loadWarehouseUsers();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Warehouse user ${firstNameController.text} ${lastNameController.text} created successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errorMessage = context.read<AdminProvider>().error ??
                        'Failed to create warehouse user';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  /// Edit warehouse user
  void _editWarehouseUser(WarehouseUser user) {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final addressController = TextEditingController(text: user.address);
    final cityController = TextEditingController(text: user.city);
    final provinceController = TextEditingController(text: user.province);
    final postalCodeController = TextEditingController(text: user.postalCode);
    final notesController = TextEditingController(text: user.notes ?? '');
    String selectedCountry = user.country;
    WarehouseUserStatus selectedStatus = user.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Warehouse User'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email (read-only)
                    TextFormField(
                      initialValue: user.email,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 24),

                    // Address Section
                    Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: provinceController,
                            decoration: const InputDecoration(
                              labelText: 'Province/State',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: postalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Postal Code',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCountry,
                            decoration: const InputDecoration(
                              labelText: 'Country',
                              border: OutlineInputBorder(),
                            ),
                            items: ['USA', 'RSA'].map((country) {
                              return DropdownMenuItem(
                                value: country,
                                child: Row(
                                  children: [
                                    Text(_getCountryFlag(country)),
                                    const SizedBox(width: 8),
                                    Text(country),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedCountry = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Section
                    Text(
                      'Status & Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WarehouseUserStatus>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: WarehouseUserStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context);

                  // Convert status to accountStatus for users collection
                  String accountStatus;
                  switch (selectedStatus) {
                    case WarehouseUserStatus.active:
                      accountStatus = 'approved';
                    case WarehouseUserStatus.suspended:
                      accountStatus = 'suspended';
                    case WarehouseUserStatus.inactive:
                      accountStatus = 'pending';
                  }

                  final updates = <String, dynamic>{
                    'firstName': firstNameController.text.trim(),
                    'lastName': lastNameController.text.trim(),
                    'phoneNumber': phoneController.text.trim(),
                    'address': addressController.text.trim(),
                    'city': cityController.text.trim(),
                    'province': provinceController.text.trim(),
                    'postalCode': postalCodeController.text.trim(),
                    'country': selectedCountry,
                    'countryName': selectedCountry == 'USA'
                        ? 'United States'
                        : 'South Africa',
                    'accountStatus': accountStatus,
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  };

                  final success = await context
                      .read<AdminProvider>()
                      .updateWarehouseUser(user.id, updates);

                  if (!context.mounted) return;

                  if (success) {
                    // Reload the warehouse users list to show the updated user
                    await context.read<AdminProvider>().loadWarehouseUsers();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${user.fullName} updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errorMessage = context.read<AdminProvider>().error ??
                        'Failed to update warehouse user';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle warehouse user status
  void _toggleWarehouseUserStatus(WarehouseUser user) async {
    final newStatus = user.status == WarehouseUserStatus.active
        ? WarehouseUserStatus.suspended
        : WarehouseUserStatus.active;

    final success = await context.read<AdminProvider>().updateWarehouseUserStatus(
          user.id,
          newStatus,
        );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user.fullName} status updated to ${newStatus.displayName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update warehouse user status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show more options menu
  void _showMoreOptions(WarehouseUser user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteWarehouseUser(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Delete warehouse user
  void _deleteWarehouseUser(WarehouseUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Warehouse User'),
        content: Text(
          'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await context
                  .read<AdminProvider>()
                  .deleteWarehouseUser(user.id);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user.fullName} deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete warehouse user'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


