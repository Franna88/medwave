import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/admin/admin_user.dart';
import '../../theme/app_theme.dart';
import '../../utils/role_manager.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Load admin users when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();

      // Only Super Admins can access this screen
      if (authProvider.userRole == UserRole.superAdmin) {
        context.read<AdminProvider>().loadAdminUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Access control: Only Super Admins can manage admin users
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
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Only Super Administrators can manage admin users.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
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

          final filteredAdminUsers = _getFilteredAdminUsers(
            adminProvider.adminUsers,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, authProvider),
                const SizedBox(height: 24),
                _buildUserStatistics(filteredAdminUsers),
                const SizedBox(height: 24),
                _buildFiltersSection(),
                const SizedBox(height: 24),
                _buildUsersTable(filteredAdminUsers),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Filter admin users based on search query and filters
  List<AdminUser> _getFilteredAdminUsers(List<AdminUser> adminUsers) {
    var filtered = adminUsers;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final searchLower = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(searchLower) ||
            user.email.toLowerCase().contains(searchLower) ||
            user.country.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Filter by role
    if (_roleFilter != 'All') {
      AdminRole? roleToFilter;
      switch (_roleFilter) {
        case 'Super Admin':
          roleToFilter = AdminRole.superAdmin;
          break;
        case 'Country Admin':
          roleToFilter = AdminRole.countryAdmin;
          break;
        case 'Marketing':
          roleToFilter = AdminRole.marketing;
          break;
        case 'Sales':
          roleToFilter = AdminRole.sales;
          break;
        case 'Operations':
          roleToFilter = AdminRole.operations;
          break;
        case 'Support':
          roleToFilter = AdminRole.support;
          break;
      }
      if (roleToFilter != null) {
        filtered = filtered.where((user) => user.role == roleToFilter).toList();
      }
    }

    // Filter by status
    if (_statusFilter != 'All') {
      AdminUserStatus? statusToFilter;
      switch (_statusFilter) {
        case 'Active':
          statusToFilter = AdminUserStatus.active;
          break;
        case 'Inactive':
          statusToFilter = AdminUserStatus.inactive;
          break;
        case 'Suspended':
          statusToFilter = AdminUserStatus.suspended;
          break;
      }
      if (statusToFilter != null) {
        filtered = filtered
            .where((user) => user.status == statusToFilter)
            .toList();
      }
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
                'Admin User Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage super admins and country administrators',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateAdminUserDialog(context, authProvider),
          icon: const Icon(Icons.person_add),
          label: const Text('Create Admin User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildUserStatistics(List<AdminUser> adminUsers) {
    final totalUsers = adminUsers.length;
    final superAdmins = adminUsers
        .where((u) => u.role == AdminRole.superAdmin)
        .length;
    final countryAdmins = adminUsers
        .where((u) => u.role == AdminRole.countryAdmin)
        .length;
    final marketingAdmins = adminUsers
        .where((u) => u.role == AdminRole.marketing)
        .length;
    final salesAdmins = adminUsers
        .where((u) => u.role == AdminRole.sales)
        .length;
    final operationsAdmins = adminUsers
        .where((u) => u.role == AdminRole.operations)
        .length;
    final supportAdmins = adminUsers
        .where((u) => u.role == AdminRole.support)
        .length;
    final activeUsers = adminUsers
        .where((u) => u.status == AdminUserStatus.active)
        .length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Admin Users',
                totalUsers.toString(),
                Icons.admin_panel_settings,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Super Admins',
                superAdmins.toString(),
                Icons.supervisor_account,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Country Admins',
                countryAdmins.toString(),
                Icons.location_on,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Active Users',
                activeUsers.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Marketing',
                marketingAdmins.toString(),
                Icons.campaign,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Sales',
                salesAdmins.toString(),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Operations',
                operationsAdmins.toString(),
                Icons.local_shipping,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Support',
                supportAdmins.toString(),
                Icons.support_agent,
                Colors.indigo,
              ),
            ),
          ],
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
                hintText: 'Search admin users...',
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
              value: _roleFilter,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items:
                  [
                    'All',
                    'Super Admin',
                    'Country Admin',
                    'Marketing',
                    'Sales',
                    'Operations',
                    'Support',
                  ].map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
              onChanged: (value) => setState(() => _roleFilter = value!),
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
        ],
      ),
    );
  }

  Widget _buildUsersTable(List<AdminUser> adminUsers) {
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
              'Admin Users (${adminUsers.length})',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 600,
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 20,
              minWidth: 1000,
              columns: const [
                DataColumn2(label: Text('User'), size: ColumnSize.L),
                DataColumn2(label: Text('Role'), size: ColumnSize.M),
                DataColumn2(label: Text('Country'), size: ColumnSize.S),
                DataColumn2(label: Text('Status'), size: ColumnSize.S),
                DataColumn2(label: Text('Last Login'), size: ColumnSize.M),
                DataColumn2(label: Text('Created'), size: ColumnSize.M),
                DataColumn2(label: Text('Actions'), size: ColumnSize.M),
              ],
              rows: adminUsers.map((user) {
                return DataRow2(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getRoleColor(
                              user.role,
                            ).withOpacity(0.1),
                            child: Text(
                              user.fullName
                                  .split(' ')
                                  .map((n) => n[0])
                                  .join(''),
                              style: TextStyle(
                                color: _getRoleColor(user.role),
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
                    DataCell(Text(user.role.displayName)),
                    DataCell(
                      Row(
                        children: [
                          Text(_getCountryFlag(user.country)),
                          const SizedBox(width: 4),
                          Text(user.country),
                        ],
                      ),
                    ),
                    DataCell(Text(user.status.displayName)),
                    DataCell(
                      Text(
                        user.lastLogin != null
                            ? _formatDateTime(user.lastLogin!)
                            : 'Never',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDateTime(user.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editAdminUser(user),
                            tooltip: 'Edit User',
                          ),
                          IconButton(
                            icon: Icon(
                              user.status == AdminUserStatus.active
                                  ? Icons.block
                                  : Icons.check_circle,
                              color: user.status == AdminUserStatus.active
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            onPressed: () => _toggleUserStatus(user),
                            tooltip: user.status == AdminUserStatus.active
                                ? 'Suspend User'
                                : 'Activate User',
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) => _deleteAdminUser(user),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'permissions',
                                child: Text('Manage Permissions'),
                              ),
                              const PopupMenuItem(
                                value: 'reset_password',
                                child: Text('Reset Password'),
                              ),
                              const PopupMenuItem(
                                value: 'activity_log',
                                child: Text('View Activity Log'),
                              ),
                              if (user.role != AdminRole.superAdmin)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete User'),
                                ),
                            ],
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

  Color _getRoleColor(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return Colors.purple;
      case AdminRole.countryAdmin:
        return Colors.blue;
      case AdminRole.marketing:
        return Colors.orange;
      case AdminRole.sales:
        return Colors.green;
      case AdminRole.operations:
        return Colors.teal;
      case AdminRole.support:
        return Colors.indigo;
    }
  }

  List<Map<String, dynamic>> _getMockAdminUsers() {
    return [
      {
        'name': 'John Smith',
        'email': 'john.smith@medwave.com',
        'role': 'Super Admin',
        'country': 'USA',
        'status': 'Active',
        'lastLogin': '2 hours ago',
        'created': '2023-01-15',
      },
      {
        'name': 'Sarah Johnson',
        'email': 'sarah.johnson@medwave.com',
        'role': 'Country Admin',
        'country': 'USA',
        'status': 'Active',
        'lastLogin': '1 day ago',
        'created': '2023-02-20',
      },
      {
        'name': 'Michael Chen',
        'email': 'michael.chen@medwave.com',
        'role': 'Country Admin',
        'country': 'RSA',
        'status': 'Active',
        'lastLogin': '3 days ago',
        'created': '2023-03-10',
      },
      {
        'name': 'Emily Rodriguez',
        'email': 'emily.rodriguez@medwave.com',
        'role': 'Country Admin',
        'country': 'USA',
        'status': 'Inactive',
        'lastLogin': '2 weeks ago',
        'created': '2023-04-05',
      },
    ];
  }

  List<Map<String, dynamic>> _getFilteredUsers(
    List<Map<String, dynamic>> users,
  ) {
    var filtered = users;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        return user['name'].toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            user['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by role
    if (_roleFilter != 'All') {
      filtered = filtered.where((user) => user['role'] == _roleFilter).toList();
    }

    // Filter by status
    if (_statusFilter != 'All') {
      filtered = filtered
          .where((user) => user['status'] == _statusFilter)
          .toList();
    }

    return filtered;
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

  void _createNewAdminUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Admin User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: ['Country Admin', 'Super Admin'].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                items: ['USA', 'RSA'].map((country) {
                  return DropdownMenuItem(value: country, child: Text(country));
                }).toList(),
                onChanged: null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin user created successfully'),
                ),
              );
            },
            child: const Text('Create User'),
          ),
        ],
      ),
    );
  }

  void _editUser(Map<String, dynamic> user) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Editing user: ${user['name']}')));
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'permissions':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Managing permissions for ${user['name']}')),
        );
        break;
      case 'reset_password':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset sent to ${user['email']}')),
        );
        break;
      case 'activity_log':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing activity log for ${user['name']}')),
        );
        break;
      case 'delete':
        _confirmDeleteUser(user);
        break;
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user['name']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User ${user['name']} has been deleted'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show create admin user dialog
  void _showCreateAdminUserDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final notesController = TextEditingController();
    AdminRole selectedRole = AdminRole.countryAdmin;
    String selectedCountry = 'USA';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Admin User'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
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
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
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
                      if (value != passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AdminRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: AdminRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
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

                  final success = await context
                      .read<AdminProvider>()
                      .createAdminUser(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        role: selectedRole,
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
                    // Reload the admin users list to show the new user
                    await context.read<AdminProvider>().loadAdminUsers();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Admin user ${firstNameController.text} ${lastNameController.text} created successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errorMessage =
                        context.read<AdminProvider>().error ??
                        'Failed to create admin user';
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

  /// Build role chip for admin user
  Widget _buildRoleChip(AdminRole role) {
    Color color = role == AdminRole.superAdmin ? Colors.purple : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build status chip for admin user
  Widget _buildStatusChip(AdminUserStatus status) {
    Color color;
    switch (status) {
      case AdminUserStatus.active:
        color = Colors.green;
        break;
      case AdminUserStatus.inactive:
        color = Colors.orange;
        break;
      case AdminUserStatus.suspended:
        color = Colors.red;
        break;
    }

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

  /// Format date time for display
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

  /// Edit admin user
  void _editAdminUser(AdminUser user) {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final emailController = TextEditingController(text: user.email);
    final notesController = TextEditingController(text: user.notes ?? '');
    AdminRole selectedRole = user.role;
    String selectedCountry = user.country;
    AdminUserStatus selectedStatus = user.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Admin User'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
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
                    DropdownButtonFormField<AdminRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: AdminRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AdminUserStatus>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: AdminUserStatus.values.map((status) {
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
                      maxLines: 3,
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

                  final updates = <String, dynamic>{
                    'firstName': firstNameController.text.trim(),
                    'lastName': lastNameController.text.trim(),
                    'email': emailController.text.trim(),
                    'role': selectedRole.value,
                    'country': selectedCountry,
                    'countryName': selectedCountry == 'USA'
                        ? 'United States'
                        : 'South Africa',
                    'status': selectedStatus.value,
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  };

                  final success = await context
                      .read<AdminProvider>()
                      .updateAdminUser(user.id, updates);

                  if (!context.mounted) return;

                  if (success) {
                    // Reload the admin users list to show the updated user
                    await context.read<AdminProvider>().loadAdminUsers();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${user.fullName} updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final errorMessage =
                        context.read<AdminProvider>().error ??
                        'Failed to update admin user';
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

  /// Toggle user status
  void _toggleUserStatus(AdminUser user) async {
    final newStatus = user.status == AdminUserStatus.active
        ? AdminUserStatus.suspended
        : AdminUserStatus.active;

    final success = await context.read<AdminProvider>().updateAdminUserStatus(
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
          content: Text('Failed to update user status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Delete admin user
  void _deleteAdminUser(AdminUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin User'),
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
                  .deleteAdminUser(user.id, user.userId);

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
                    content: Text('Failed to delete user'),
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
