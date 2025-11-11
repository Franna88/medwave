import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/role_manager.dart';
import '../providers/auth_provider.dart';

class SidebarNavigation extends StatefulWidget {
  const SidebarNavigation({super.key});

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  final Set<String> _expandedItems = {};

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
    
    // Auto-expand items if a sub-route is active
    for (final roleItem in roleNavItems) {
      if (roleItem.hasSubItems) {
        for (final subItem in roleItem.subItems!) {
          if (currentLocation.startsWith(subItem.route)) {
            _expandedItems.add(roleItem.route);
            break;
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: roleNavItems.map((roleItem) {
        return _buildNavigationItemWithSubItems(context, roleItem, currentLocation);
      }).toList(),
    );
  }

  Widget _buildNavigationItemWithSubItems(
    BuildContext context,
    NavigationItem roleItem,
    String currentLocation,
  ) {
    final isExpanded = _expandedItems.contains(roleItem.route);
    final hasSubItems = roleItem.hasSubItems;
    final isParentActive = _isRouteActive(currentLocation, roleItem.route);

    return Column(
      children: [
        // Main navigation item
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (hasSubItems) {
                  // Toggle expansion
                  setState(() {
                    if (isExpanded) {
                      _expandedItems.remove(roleItem.route);
                    } else {
                      _expandedItems.add(roleItem.route);
                    }
                  });
                } else {
                  // Navigate to route
                  GoRouter.of(context).go(roleItem.route);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isParentActive
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isParentActive
                      ? Border.all(color: AppTheme.primaryColor.withOpacity(0.2))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconData(roleItem.icon, isParentActive),
                      color: isParentActive
                          ? AppTheme.primaryColor
                          : AppTheme.secondaryColor.withOpacity(0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        roleItem.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isParentActive ? FontWeight.w600 : FontWeight.w500,
                          color: isParentActive
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryColor.withOpacity(0.8),
                        ),
                      ),
                    ),
                    if (hasSubItems)
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.expand_more,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Sub-items (if expanded)
        if (hasSubItems && isExpanded)
          ...roleItem.subItems!.map((subItem) {
            final isSubActive = currentLocation == subItem.route;
            return Container(
              margin: const EdgeInsets.only(bottom: 4, left: 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => GoRouter.of(context).go(subItem.route),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSubActive
                          ? AppTheme.primaryColor.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconData(subItem.icon, isSubActive),
                          size: 16,
                          color: isSubActive
                              ? AppTheme.primaryColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            subItem.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSubActive ? FontWeight.w600 : FontWeight.w500,
                              color: isSubActive
                                  ? AppTheme.primaryColor
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
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
      case 'summarize':
        return filled ? Icons.summarize : Icons.summarize_outlined;
      case 'ads_click':
        return filled ? Icons.ads_click : Icons.ads_click;
      case 'inventory':
        return filled ? Icons.inventory : Icons.inventory_outlined;
      case 'timeline':
        return filled ? Icons.timeline : Icons.timeline_outlined;
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
