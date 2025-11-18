import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_utils.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Focus nodes for better keyboard management
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }

  // Simplified keyboard dismissal - single clean method
  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard before processing
    _dismissKeyboard();

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        // Navigate to main app
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _openDownloadPage() {
    // Navigate to download page within the app
    context.push('/download-app');
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    
    if (isTablet || isDesktop) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  // Left side - Hero section
                  Expanded(
                    flex: 3,
                    child: Container(
                    padding: const EdgeInsets.all(48),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo and Welcome Section
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.headerGradientEnd,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    offset: const Offset(0, 12),
                                    blurRadius: 32,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.medical_services,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sign in to your MedWave account to continue managing your patients and wound care treatments.',
                              style: TextStyle(
                                fontSize: 20,
                                color: AppTheme.secondaryColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Features Section
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              _buildTabletFeatureItem(
                                Icons.medical_information,
                                'Patient Records',
                                'Access comprehensive patient histories and treatment plans',
                                AppTheme.infoColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.analytics,
                                'Advanced Analytics',
                                'Track healing progress with AI-powered insights',
                                AppTheme.successColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.security,
                                'Secure & Compliant',
                                'HIPAA compliant platform with enterprise-grade security',
                                AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Footer
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: const Text(
                          '© 2024 MedWave. All rights reserved.',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Right side - Login form
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter your credentials to access your account',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  // Move focus to password field when "next" is pressed
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'Enter your email',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: !_isPasswordVisible,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  // Dismiss keyboard and attempt login when "done" is pressed
                                  _dismissKeyboard();
                                  if (!_isLoading) _handleLogin();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(12),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible 
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppTheme.secondaryColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Remember Me & Forgot Password
                              Row(
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        activeColor: AppTheme.primaryColor,
                                      ),
                                      const Text(
                                        'Remember me',
                                        style: TextStyle(
                                          color: AppTheme.secondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => const ForgotPasswordDialog(),
                                      );
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Sign Up Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: AppTheme.secondaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      context.push('/signup');
                                    },
                                    child: const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
              // Right side - Login form (second Expanded in Row)
              ],
            ),
            // Download App Button (positioned at top right)
            Positioned(
                top: 16,
                right: 16,
                child: TextButton.icon(
                  onPressed: _openDownloadPage,
                  icon: const Icon(
                    Icons.download,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  label: const Text(
                    'Download App',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                // Download App Button - Hidden on Mobile
                // Users on mobile devices should already have the app installed
                
                const SizedBox(height: 20),
                
                // Logo and Welcome Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.headerGradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 8),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to your MedWave account',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Login Form
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              // Move focus to password field when "next" is pressed
                              FocusScope.of(context).requestFocus(_passwordFocusNode);
                            },
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.email_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              // Dismiss keyboard and attempt login when "done" is pressed
                              FocusScope.of(context).unfocus();
                              if (!_isLoading) _handleLogin();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.lock_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible 
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppTheme.secondaryColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Remember Me & Forgot Password
                          Row(
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    activeColor: AppTheme.primaryColor,
                                  ),
                                  const Text(
                                    'Remember me',
                                    style: TextStyle(
                                      color: AppTheme.secondaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const ForgotPasswordDialog(),
                                  );
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppTheme.borderColor,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppTheme.borderColor,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.push('/signup');
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Footer
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      '© 2024 MedWave. All rights reserved.',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 12,
                      ),
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

  Widget _buildTabletFeatureItem(IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
