import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_utils.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      context.go('/welcome');
    }
  }

  void _refreshStatus() async {
    final authProvider = context.read<AuthProvider>();
    // Trigger a reload of user profile to check for approval status changes
    if (authProvider.user != null) {
      // This would typically trigger a profile refresh
      // The auth provider should automatically listen for changes
      setState(() {
        // Force a rebuild to check latest status
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final userProfile = context.watch<AuthProvider>().userProfile;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: isTablet || isDesktop 
            ? _buildTabletLayout(userProfile)
            : _buildMobileLayout(userProfile),
      ),
    );
  }

  Widget _buildTabletLayout(userProfile) {
    return Row(
      children: [
        // Left side - Illustration
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.warningColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(
                        Icons.pending_actions,
                        size: 80,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'Application Under Review',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We\'re reviewing your practitioner credentials to ensure the highest standards of care.',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.secondaryColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Right side - Status details
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(-4, 0),
                  blurRadius: 20,
                ),
              ],
            ),
            child: _buildStatusContent(userProfile),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(userProfile) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Animated Icon
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warningColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    size: 60,
                    color: AppTheme.warningColor,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title and description
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Text(
                      'Application Under Review',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We\'re reviewing your practitioner credentials to ensure the highest standards of care.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.secondaryColor,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Status content
            _buildStatusContent(userProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(userProfile) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Application Status Card
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.warningColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Application Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your application was submitted ${userProfile?.applicationDate != null ? _formatDate(userProfile!.applicationDate!) : 'recently'} and is currently being reviewed by our admin team.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // What happens next
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'What happens next?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTimelineItem(
                      Icons.verified_user,
                      'Credential Verification',
                      'We verify your professional license and qualifications',
                      true,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTimelineItem(
                      Icons.assessment,
                      'Application Review',
                      'Our team reviews your application and professional background',
                      false,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTimelineItem(
                      Icons.email,
                      'Notification',
                      'You\'ll receive an email with your approval status within 24-48 hours',
                      false,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTimelineItem(
                      Icons.check_circle,
                      'Access Granted',
                      'Once approved, you can log in and start using MedWave',
                      false,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _refreshStatus,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 20),
                          const SizedBox(width: 8),
                          const Text('Refresh Status'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _handleLogout,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: AppTheme.secondaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Contact support
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    color: AppTheme.infoColor,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you have questions about your application status, please contact our support team.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // TODO: Add support contact functionality
                    },
                    child: const Text('Contact Support'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(IconData icon, String title, String description, bool isActive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.successColor : AppTheme.borderColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isActive ? Icons.check : icon,
            color: isActive ? Colors.white : AppTheme.secondaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppTheme.successColor : AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }
}
