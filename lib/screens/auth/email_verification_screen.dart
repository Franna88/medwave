import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/responsive_utils.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  bool _isChecking = false;
  String? _message;

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() {
          _message = 'Verification email sent! Please check your inbox.';
          _isResending = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to send email. Please try again.';
        _isResending = false;
      });
    }
  }

  Future<void> _checkEmailVerified() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        
        if (updatedUser != null && updatedUser.emailVerified) {
          // Email is verified, proceed to app
          if (mounted) {
            context.go('/');
          }
        } else {
          setState(() {
            _message = 'Email not verified yet. Please check your inbox and click the verification link.';
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _message = 'Error checking verification status. Please try again.';
        _isChecking = false;
      });
    }
  }

  Future<void> _logout() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isTablet || isDesktop ? 600 : double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'We\'ve sent a verification email to:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.infoColor, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Next Steps',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStep(1, 'Check your email inbox'),
                        _buildStep(2, 'Click the verification link'),
                        _buildStep(3, 'Return here and click "I\'ve Verified"'),
                      ],
                    ),
                  ),
                  
                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _message!.contains('sent') || _message!.contains('verified')
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _message!.contains('sent') || _message!.contains('verified')
                              ? AppTheme.successColor.withOpacity(0.3)
                              : AppTheme.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _message!.contains('sent') || _message!.contains('verified')
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: _message!.contains('sent') || _message!.contains('verified')
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkEmailVerified,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'I\'ve Verified My Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isResending ? null : _resendVerificationEmail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                      ),
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            )
                          : const Text(
                              'Resend Verification Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  TextButton(
                    onPressed: _logout,
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

