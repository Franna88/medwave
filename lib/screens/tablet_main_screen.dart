import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/notification_badge.dart';
import '../utils/responsive_utils.dart';
import '../theme/app_theme.dart';
import '../providers/notification_provider.dart';

class TabletMainScreen extends StatelessWidget {
  final Widget child;

  const TabletMainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Sidebar Navigation
          const SidebarNavigation(),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: ResponsiveUtils.getScreenPadding(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Page Title Area - will be customized per screen
          Expanded(
            child: _buildPageTitle(context),
          ),
          
          // Action Buttons
          _buildTopBarActions(context),
        ],
      ),
    );
  }

  Widget _buildPageTitle(BuildContext context) {
    // This will be enhanced to show context-aware titles
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getCurrentPageTitle(context),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          _getCurrentPageSubtitle(context),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTopBarActions(BuildContext context) {
    return Row(
      children: [
        // Search Button
        _buildActionButton(
          icon: Icons.search_outlined,
          onPressed: () {
            // Global search functionality coming soon
          },
        ),
        const SizedBox(width: 8),
        
        // Notifications
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            return NotificationBadge(
              count: notificationProvider.unreadCount,
              child: _buildActionButton(
                icon: Icons.notifications_outlined,
                onPressed: () {
                  context.push('/notifications');
                },
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        
        // Settings
        _buildActionButton(
          icon: Icons.settings_outlined,
          onPressed: () {
            context.push('/profile'); // Navigate to profile/settings
          },
        ),
        const SizedBox(width: 12),
        
        // User Profile
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/profile'); // Navigate to profile
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.borderColor.withOpacity(0.3),
            ),
          ),
          child: Icon(
            icon,
            color: AppTheme.secondaryColor.withOpacity(0.8),
            size: 18,
          ),
        ),
      ),
    );
  }

  String _getCurrentPageTitle(BuildContext context) {
    // This would ideally be passed from the route or determined by current location
    return 'Dashboard'; // Placeholder - will be enhanced
  }

  String _getCurrentPageSubtitle(BuildContext context) {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, y');
    return formatter.format(now);
  }
}
