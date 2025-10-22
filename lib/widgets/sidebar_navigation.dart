import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/role_manager.dart';
import '../providers/auth_provider.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    
    return Container(
      width: 280, // Fixed wider width for icon + text
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildExpandedHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: _buildExpandedNavigationItems(context, currentLocation),
          ),
          _buildExpandedFooter(),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Image.asset(
                'images/medwave_logo_black.png',
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MedWave',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Text(
                      authProvider.isAdmin ? 'Admin Panel' : 'Provider',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedNavigationItems(BuildContext context, String currentLocation) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole;
    
    // Get role-based navigation items
    final roleNavItems = RoleManager.getNavigationItems(userRole);
    
    // Convert to internal navigation items
    final navigationItems = roleNavItems.map((roleItem) {
      return _NavigationItem(
        icon: _getIconData(roleItem.icon, false),
        activeIcon: _getIconData(roleItem.icon, true),
        label: roleItem.title,
        route: roleItem.route,
        isActive: _isRouteActive(currentLocation, roleItem.route),
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: navigationItems.map((item) => _buildExpandedNavigationTile(context, item)).toList(),
    );
  }

  /// Get icon data based on string identifier
  IconData _getIconData(String iconName, bool filled) {
    switch (iconName) {
      case 'dashboard':
        return filled ? Icons.dashboard : Icons.dashboard_outlined;
      case 'people':
        return filled ? Icons.people : Icons.people_outline;
      case 'calendar_today':
        return filled ? Icons.calendar_today : Icons.calendar_today_outlined;
      case 'assessment':
        return filled ? Icons.assessment : Icons.assessment_outlined;
      case 'notifications':
        return filled ? Icons.notifications : Icons.notifications_outlined;
      case 'admin_panel_settings':
        return filled ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined;
      case 'business':
        return filled ? Icons.business : Icons.business_outlined;
      case 'approval':
        return filled ? Icons.approval : Icons.approval_outlined;
      case 'analytics':
        return filled ? Icons.analytics : Icons.analytics_outlined;
      case 'medical_services':
        return filled ? Icons.medical_services : Icons.medical_services_outlined;
      case 'campaign':
        return filled ? Icons.campaign : Icons.campaign_outlined;
      case 'trending_up':
        return filled ? Icons.trending_up : Icons.trending_up_outlined;
      case 'build':
        return filled ? Icons.build : Icons.build_outlined;
      default:
        return filled ? Icons.circle : Icons.circle_outlined;
    }
  }

  /// Check if route is active
  bool _isRouteActive(String currentLocation, String route) {
    if (route == '/dashboard' || route == '/') {
      return currentLocation == '/' || currentLocation == '/dashboard';
    }
    return currentLocation.startsWith(route);
  }

  Widget _buildExpandedNavigationTile(BuildContext context, _NavigationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).go(item.route),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: item.isActive 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: item.isActive
                ? Border.all(color: AppTheme.primaryColor.withOpacity(0.2))
                : null,
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    item.isActive ? item.activeIcon : item.icon,
                    key: ValueKey(item.isActive),
                    color: item.isActive 
                      ? AppTheme.primaryColor 
                      : AppTheme.secondaryColor.withOpacity(0.7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.isActive ? FontWeight.w600 : FontWeight.w500,
                      color: item.isActive 
                        ? AppTheme.primaryColor 
                        : AppTheme.secondaryColor.withOpacity(0.8),
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

  Widget _buildExpandedFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Divider(
            color: AppTheme.borderColor,
            thickness: 1,
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.userName ?? 'User',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          RoleManager.getRoleDisplayName(authProvider.userRole),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => authProvider.logout(),
                    icon: Icon(
                      Icons.logout,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    tooltip: 'Sign Out',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isActive;

  const _NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.isActive,
  });
}
