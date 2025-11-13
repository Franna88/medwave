/// Role-based access control system for MedWave application
/// 
/// This utility manages user roles and permissions for both practitioner
/// and administrative functionalities within the unified MedWave app.

enum UserRole {
  practitioner('practitioner'),
  countryAdmin('country_admin'),
  superAdmin('super_admin');

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
    return role == UserRole.countryAdmin || role == UserRole.superAdmin;
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

  /// Get appropriate dashboard route based on role
  static String getDashboardRoute(UserRole role) {
    switch (role) {
      case UserRole.practitioner:
        return '/dashboard';
      case UserRole.countryAdmin:
      case UserRole.superAdmin:
        return '/admin/dashboard';
    }
  }

  /// Get user-friendly role display name
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.practitioner:
        return 'Healthcare Practitioner';
      case UserRole.countryAdmin:
        return 'Country Administrator';
      case UserRole.superAdmin:
        return 'Super Administrator';
    }
  }

  /// Get role-specific navigation items
  static List<NavigationItem> getNavigationItems(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
      case UserRole.countryAdmin:
        // Admin users see ONLY admin navigation items
        final List<NavigationItem> adminItems = [
          NavigationItem('Admin Dashboard', '/admin/dashboard', 'admin_panel_settings'),
          NavigationItem('Provider Management', '/admin/providers', 'business'),
          NavigationItem('Provider Approvals', '/admin/approvals', 'approval'),
          NavigationItem('Analytics', '/admin/analytics', 'analytics'),
          NavigationItem('Patient Management', '/admin/patients', 'medical_services'),
        ];

        // Super admin exclusive items
        if (role == UserRole.superAdmin) {
          adminItems.addAll([
            NavigationItem(
              'Advertisement Performance',
              '/admin/adverts/campaigns',
              'campaign',
              subItems: [
                NavigationSubItem('Campaigns', '/admin/adverts/campaigns', 'campaign'),
                NavigationSubItem('Campaigns (Old)', '/admin/adverts/campaigns-old', 'history'),
                NavigationSubItem('Timeline', '/admin/adverts/timeline', 'timeline'),
                NavigationSubItem('Comparison', '/admin/adverts/comparison', 'compare'),
                NavigationSubItem('Products', '/admin/adverts/products', 'inventory'),
              ],
            ),
            NavigationItem('Sales Performance', '/admin/sales-performance', 'trending_up'),
            NavigationItem('Admin Management', '/admin/users', 'admin_panel_settings'),
            NavigationItem('Report Builder', '/admin/report-builder', 'build'),
          ]);
        }

        return adminItems;

      case UserRole.practitioner:
        // Practitioners see ONLY practitioner navigation items
        return [
          NavigationItem('Dashboard', '/dashboard', 'dashboard'),
          NavigationItem('Patients', '/patients', 'people'),
          NavigationItem('Calendar', '/calendar', 'calendar_today'),
          NavigationItem('Reports', '/reports', 'assessment'),
          NavigationItem('Notifications', '/notifications', 'notifications'),
        ];
    }
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
