import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final sidebarWidth = ResponsiveUtils.getSidebarWidth(context);
    
    return Container(
      width: sidebarWidth,
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
          _buildMinimalHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: _buildMinimalNavigationItems(context, currentLocation),
          ),
          _buildMinimalFooter(),
        ],
      ),
    );
  }

  Widget _buildMinimalHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Image.asset(
            'images/medwave_logo_black.png',
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalNavigationItems(BuildContext context, String currentLocation) {
    final navigationItems = [
      _NavigationItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        route: '/',
        isActive: currentLocation == '/',
      ),
      _NavigationItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Patients',
        route: '/patients',
        isActive: currentLocation.startsWith('/patients'),
      ),
      // TODO: Re-enable when appointment system is complete
      // _NavigationItem(
      //   icon: Icons.calendar_today_outlined,
      //   activeIcon: Icons.calendar_today,
      //   label: 'Calendar',
      //   route: '/calendar',
      //   isActive: currentLocation.startsWith('/calendar'),
      // ),
      _NavigationItem(
        icon: Icons.assessment_outlined,
        activeIcon: Icons.assessment,
        label: 'Reports',
        route: '/reports',
        isActive: currentLocation.startsWith('/reports'),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: navigationItems.map((item) => _buildMinimalNavigationTile(context, item)).toList(),
    );
  }

  Widget _buildMinimalNavigationTile(BuildContext context, _NavigationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Tooltip(
        message: item.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => GoRouter.of(context).go(item.route),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: item.isActive 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: item.isActive
                  ? Border.all(color: AppTheme.primaryColor.withOpacity(0.2))
                  : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    item.isActive ? item.activeIcon : item.icon,
                    key: ValueKey(item.isActive),
                    color: item.isActive 
                      ? AppTheme.primaryColor 
                      : AppTheme.secondaryColor.withOpacity(0.7),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Divider(
            color: AppTheme.borderColor,
            thickness: 1,
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: 'Dr. Provider',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.person_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
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
