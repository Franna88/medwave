/// Role-based access control system for MedWave application
///
/// This utility manages user roles and permissions for both practitioner
/// and administrative functionalities within the unified MedWave app.

enum UserRole {
  practitioner('practitioner'),
  warehouse('warehouse'),
  installer('installer'),
  countryAdmin('country_admin'),
  superAdmin('super_admin'),
  marketingAdmin('marketing'),
  salesAdmin('sales'),
  operationsAdmin('operations'),
  supportAdmin('support');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.practitioner,
    );
  }
}

class RoleManager {
  /// Check if user can access admin panel features
  static bool canAccessAdminPanel(UserRole role) {
    return role == UserRole.countryAdmin ||
        role == UserRole.superAdmin ||
        role == UserRole.marketingAdmin ||
        role == UserRole.salesAdmin ||
        role == UserRole.operationsAdmin ||
        role == UserRole.supportAdmin;
  }

  /// Check if user can manage healthcare providers
  static bool canManageProviders(UserRole role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can view analytics across all providers
  static bool canViewGlobalAnalytics(UserRole role) {
    return role == UserRole.countryAdmin || role == UserRole.superAdmin;
  }

  /// Check if user can approve/reject provider applications
  static bool canApproveProviders(UserRole role) {
    return role == UserRole.countryAdmin || role == UserRole.superAdmin;
  }

  /// Check if user can manage products
  static bool canManageProducts(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.countryAdmin;
  }

  /// Check if user can manage admin users
  static bool canManageAdminUsers(UserRole role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can access patient data across providers
  static bool canAccessCrossProviderData(UserRole role) {
    return role == UserRole.countryAdmin || role == UserRole.superAdmin;
  }

  /// Check if user can generate marketing reports
  static bool canGenerateMarketingReports(UserRole role) {
    return role == UserRole.countryAdmin || role == UserRole.superAdmin;
  }

  /// Check if user can access advertisement performance data
  static bool canViewAdvertPerformance(UserRole role) {
    return role == UserRole.superAdmin;
  }

  /// Check if user can access a specific stream
  static bool canAccessStream(UserRole role, String streamName) {
    // Super admin and country admin can access all streams
    if (role == UserRole.superAdmin || role == UserRole.countryAdmin) {
      return true;
    }

    // Stream-specific admins can only access their own stream
    switch (streamName.toLowerCase()) {
      case 'marketing':
        return role == UserRole.marketingAdmin;
      case 'sales':
        return role == UserRole.salesAdmin;
      case 'operations':
        return role == UserRole.operationsAdmin;
      case 'support':
        return role == UserRole.supportAdmin;
      default:
        return false;
    }
  }

  /// Get list of streams accessible to a role
  static List<String> getAccessibleStreams(UserRole role) {
    if (role == UserRole.superAdmin || role == UserRole.countryAdmin) {
      return ['marketing', 'sales', 'operations', 'support'];
    }

    switch (role) {
      case UserRole.marketingAdmin:
        return ['marketing'];
      case UserRole.salesAdmin:
        return ['sales'];
      case UserRole.operationsAdmin:
        return ['operations'];
      case UserRole.supportAdmin:
        return ['support'];
      default:
        return [];
    }
  }

  /// Check if user can access warehouse/inventory features
  static bool canAccessWarehouse(UserRole role) {
    return role == UserRole.warehouse ||
        role == UserRole.superAdmin ||
        role == UserRole.countryAdmin;
  }

  /// Check if user can perform stock takes and update inventory
  static bool canUpdateInventory(UserRole role) {
    return role == UserRole.warehouse ||
        role == UserRole.superAdmin ||
        role == UserRole.countryAdmin;
  }

  /// Get appropriate dashboard route based on role
  static String getDashboardRoute(UserRole role) {
    switch (role) {
      case UserRole.practitioner:
        return '/dashboard';
      case UserRole.warehouse:
        return '/warehouse/inventory';
      case UserRole.installer:
        return '/installer/dashboard'; // Future installer mobile app dashboard
      case UserRole.countryAdmin:
      case UserRole.superAdmin:
      case UserRole.marketingAdmin:
      case UserRole.salesAdmin:
      case UserRole.operationsAdmin:
      case UserRole.supportAdmin:
        return '/admin/dashboard';
    }
  }

  /// Get user-friendly role display name
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.practitioner:
        return 'Healthcare Practitioner';
      case UserRole.warehouse:
        return 'Warehouse Staff';
      case UserRole.installer:
        return 'Installer';
      case UserRole.countryAdmin:
        return 'Country Administrator';
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.marketingAdmin:
        return 'Marketing Administrator';
      case UserRole.salesAdmin:
        return 'Sales Administrator';
      case UserRole.operationsAdmin:
        return 'Operations Administrator';
      case UserRole.supportAdmin:
        return 'Support Administrator';
    }
  }

  /// Get role-specific navigation items
  /// Optional parameters allow filtering based on feature flags
  static List<NavigationItem> getNavigationItems(
    UserRole role, {
    bool showForms = true,
    bool showLeads = true,
  }) {
    // Check if role is a stream admin
    final isStreamAdmin =
        role == UserRole.marketingAdmin ||
        role == UserRole.salesAdmin ||
        role == UserRole.operationsAdmin ||
        role == UserRole.supportAdmin;

    if (role == UserRole.superAdmin ||
        role == UserRole.countryAdmin ||
        isStreamAdmin) {
      // Admin users see ONLY admin navigation items
      final List<NavigationItem> adminItems = [
        NavigationItem(
          'Admin Dashboard',
          '/admin/dashboard',
          'admin_panel_settings',
        ),
      ];

      // Common pages for all admins (including stream admins)
      if (role == UserRole.superAdmin ||
          role == UserRole.countryAdmin ||
          isStreamAdmin) {
        // Stream admins get common pages
        if (isStreamAdmin) {
          // Stream admins only get Dashboard, Forms, and Streams
          if (showForms) {
            adminItems.add(
              NavigationItem('Forms', '/admin/forms', 'description'),
            );
          }
        } else {
          // Super admin and country admin get full access
          adminItems.addAll([
            NavigationItem(
              'Provider Management',
              '/admin/providers',
              'business',
            ),
            NavigationItem(
              'Provider Approvals',
              '/admin/approvals',
              'approval',
            ),
            NavigationItem('Analytics', '/admin/analytics', 'analytics'),
            NavigationItem(
              'Patient Management',
              '/admin/patients',
              'medical_services',
            ),
          ]);
        }
      }

      // Super admin exclusive items
      if (role == UserRole.superAdmin) {
        adminItems.addAll([
          NavigationItem(
            'Advertisement Performance',
            '/admin/adverts/campaigns',
            'campaign',
            subItems: [
              NavigationSubItem(
                'Campaigns',
                '/admin/adverts/campaigns',
                'campaign',
              ),
              // NavigationSubItem('Campaigns (Old)', '/admin/adverts/campaigns-old', 'history'),
              NavigationSubItem(
                'Comparison',
                '/admin/adverts/comparison',
                'compare',
              ),
            ],
          ),
          NavigationItem(
            'Sales Performance',
            '/admin/sales-performance',
            'trending_up',
          ),
          NavigationItem(
            'User Management',
            '/admin/users',
            'people',
            subItems: [
              NavigationSubItem(
                'Admin Users',
                '/admin/users',
                'admin_panel_settings',
              ),
              NavigationSubItem(
                'Warehouse Users',
                '/admin/warehouse-users',
                'warehouse',
              ),
              NavigationSubItem(
                'Installers',
                '/admin/installers',
                'engineering',
              ),
            ],
          ),
          NavigationItem(
            'Admin Management',
            '/admin/product-management',
            'settings',
            subItems: [
              NavigationSubItem(
                'Product Management',
                '/admin/product-management',
                'inventory',
              ),
              NavigationSubItem(
                'Contract Content',
                '/admin/contract-content',
                'description',
              ),
              NavigationSubItem('Contracts', '/admin/contracts', 'description'),
            ],
          ),
          NavigationItem('Report Builder', '/admin/report-builder', 'build'),
        ]);
      } else if (role == UserRole.countryAdmin) {
        adminItems.add(
          NavigationItem(
            'Admin Management',
            '/admin/users',
            'admin_panel_settings',
            subItems: [
              NavigationSubItem(
                'Product Management',
                '/admin/product-management',
                'inventory',
              ),
            ],
          ),
        );
      }

      // Add Forms for super admin if not already added
      if (role == UserRole.superAdmin && showForms) {
        if (!adminItems.any((item) => item.title == 'Forms')) {
          adminItems.add(
            NavigationItem('Forms', '/admin/forms', 'description'),
          );
        }
      }

      // Add Streams section - show all streams for all admin roles
      if (showLeads) {
        adminItems.add(
          NavigationItem(
            'Streams',
            '/admin/streams/marketing',
            'stream',
            subItems: [
              NavigationSubItem(
                'Marketing',
                '/admin/streams/marketing',
                'campaign',
              ),
              NavigationSubItem(
                'Sales',
                '/admin/streams/sales',
                'attach_money',
              ),
              NavigationSubItem(
                'Operations',
                '/admin/streams/operations',
                'local_shipping',
              ),
              NavigationSubItem(
                'Support',
                '/admin/streams/support',
                'support_agent',
              ),
            ],
          ),
        );
      }

      return adminItems;
    }

    // Practitioners see ONLY practitioner navigation items
    if (role == UserRole.practitioner) {
      return [
        NavigationItem('Dashboard', '/dashboard', 'dashboard'),
        NavigationItem('Patients', '/patients', 'people'),
        NavigationItem('Calendar', '/calendar', 'calendar_today'),
        NavigationItem('Reports', '/reports', 'assessment'),
        NavigationItem('Notifications', '/notifications', 'notifications'),
      ];
    }

    // Warehouse staff see inventory navigation items
    if (role == UserRole.warehouse) {
      return [
        NavigationItem('Inventory', '/warehouse/inventory', 'inventory_2'),
        NavigationItem('Orders', '/warehouse/orders', 'shopping_cart'),
      ];
    }

    return [];
  }
}

class NavigationItem {
  final String title;
  final String route;
  final String icon;
  final List<NavigationSubItem>? subItems;

  NavigationItem(this.title, this.route, this.icon, {this.subItems});

  bool get hasSubItems => subItems != null && subItems!.isNotEmpty;
}

class NavigationSubItem {
  final String title;
  final String route;
  final String icon;

  NavigationSubItem(this.title, this.route, this.icon);
}
