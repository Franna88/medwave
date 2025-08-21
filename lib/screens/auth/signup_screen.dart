import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_utils.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Form Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cellNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _salesPersonController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  
  // Form State
  bool _isLoading = false;
  bool _consentToShareInfo = false;
  String _purchaseMethod = '';
  String _selectedPackage = '';
  
  int _currentStep = 0;
  final int _totalSteps = 3;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Package options
  final List<Map<String, dynamic>> _packages = [
    {
      'id': 'basic',
      'name': 'Basic Package',
      'description': 'Essential MedWave features for small practices',
      'price': '\$2,999',
      'features': ['Basic wound tracking', 'Patient management', 'Basic reporting'],
    },
    {
      'id': 'professional',
      'name': 'Professional Package',
      'description': 'Advanced features for growing medical practices',
      'price': '\$4,999',
      'features': ['Advanced analytics', 'Multi-user access', 'Custom reporting', 'Priority support'],
    },
    {
      'id': 'enterprise',
      'name': 'Enterprise Package',
      'description': 'Complete solution for large healthcare organizations',
      'price': '\$9,999',
      'features': ['Unlimited users', 'Advanced integrations', 'Custom development', '24/7 support'],
    },
  ];

  // Purchase method options
  final List<String> _purchaseMethods = [
    'Direct Purchase',
    'Lease to Own',
    'Monthly Subscription',
    'Financing through MedWave',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cellNumberController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _salesPersonController.dispose();
    _shippingAddressController.dispose();
    _additionalNotesController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPackage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a package')),
      );
      return;
    }
    if (_purchaseMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a purchase method')),
      );
      return;
    }
    if (!_consentToShareInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please consent to information sharing')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final signupData = {
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'email': _emailController.text,
      'cellNumber': _cellNumberController.text,
      'companyName': _companyNameController.text,
      'companyAddress': _companyAddressController.text,
      'salesPerson': _salesPersonController.text,
      'purchaseMethod': _purchaseMethod,
      'shippingAddress': _shippingAddressController.text,
      'selectedPackage': _selectedPackage,
      'additionalNotes': _additionalNotesController.text,
    };

    final success = await authProvider.signup(signupData);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        // Show success dialog
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit application. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Application Submitted'),
          ],
        ),
        content: const Text(
          'Thank you for your interest in MedWave! Our sales team will contact you within 24 hours to discuss your requirements and complete the setup process.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/welcome');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        child: Row(
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
                              'Join MedWave Today',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Transform your wound care practice with our advanced management platform. Get started with a comprehensive solution designed for healthcare professionals.',
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
                                Icons.rocket_launch,
                                'Quick Setup',
                                'Get started in minutes with our streamlined onboarding process',
                                AppTheme.successColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.support_agent,
                                'Expert Support',
                                'Dedicated support team to help you succeed',
                                AppTheme.infoColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.trending_up,
                                'Proven Results',
                                'Join thousands of healthcare professionals already using MedWave',
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
            
            // Right side - Signup form
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
                child: Column(
                  children: [
                    // Progress Indicator
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: List.generate(_totalSteps, (index) {
                              final isActive = index <= _currentStep;
                              final isCompleted = index < _currentStep;
                              
                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isCompleted 
                                              ? AppTheme.successColor
                                              : isActive 
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.borderColor,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: isCompleted
                                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                                            : Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    color: isActive ? Colors.white : AppTheme.secondaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _getStepTitle(index),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                          color: isActive ? AppTheme.primaryColor : AppTheme.secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: (_currentStep + 1) / _totalSteps,
                            backgroundColor: AppTheme.borderColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    
                    // Form Content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildTabletPersonalInfoStep(),
                          _buildTabletCompanyInfoStep(),
                          _buildTabletPackageSelectionStep(),
                        ],
                      ),
                    ),
                    
                    // Navigation Buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _previousStep,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                ),
                                child: const Text('Previous'),
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : (_currentStep == _totalSteps - 1 ? _handleSignup : _nextStep),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_currentStep == _totalSteps - 1 ? 'Submit Application' : 'Next'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textColor),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Sign Up',
          style: TextStyle(color: AppTheme.textColor),
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: List.generate(_totalSteps, (index) {
                    final isActive = index <= _currentStep;
                    final isCompleted = index < _currentStep;
                    
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted 
                                    ? AppTheme.successColor
                                    : isActive 
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: isCompleted
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isActive ? Colors.white : AppTheme.secondaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getStepTitle(index),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                color: isActive ? AppTheme.primaryColor : AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoStep(),
                _buildCompanyInfoStep(),
                _buildPackageSelectionStep(),
              ],
            ),
          ),
          
          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_currentStep == _totalSteps - 1 ? _handleSignup : _nextStep),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == _totalSteps - 1 ? 'Submit Application' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPersonalInfoStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your contact information',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    hintText: 'Enter your first name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    hintText: 'Enter your last name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Cell Number
                TextFormField(
                  controller: _cellNumberController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Direct Cell Number *',
                    hintText: 'Enter your cell phone number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your cell number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'What is the best email to reach you',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletCompanyInfoStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Information',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about your organization',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Company Name
              TextFormField(
                controller: _companyNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'What is the full legal name of your company',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Company Address
              TextFormField(
                controller: _companyAddressController,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Company Address *',
                  hintText: 'What is the address of your company (City, State, zip code)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your company address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Sales Person
              TextFormField(
                controller: _salesPersonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Sales Person *',
                  hintText: 'Who is the sales person you are dealing with',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the sales person name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Purchase Method
              const Text(
                'How are you planning to purchase your MedWave package? *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              ..._purchaseMethods.map((method) => RadioListTile<String>(
                title: Text(method),
                value: method,
                groupValue: _purchaseMethod,
                onChanged: (value) {
                  setState(() {
                    _purchaseMethod = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              )),
              const SizedBox(height: 20),
              
              // Shipping Address
              TextFormField(
                controller: _shippingAddressController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address *',
                  hintText: 'Please enter full shipping address',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your shipping address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletPackageSelectionStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Package Selection',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the MedWave package that best fits your needs',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Package Selection
              const Text(
                'Which package are you interested in? *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              
              ..._packages.map((package) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: RadioListTile<String>(
                  value: package['id'],
                  groupValue: _selectedPackage,
                  onChanged: (value) {
                    setState(() {
                      _selectedPackage = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        package['price'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...package['features'].map<Widget>((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  tileColor: _selectedPackage == package['id']
                      ? AppTheme.primaryColor.withOpacity(0.05)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedPackage == package['id']
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                      width: _selectedPackage == package['id'] ? 2 : 1,
                    ),
                  ),
                ),
              )),
              
              const SizedBox(height: 24),
              
              // Consent Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentToShareInfo,
                      onChanged: (value) {
                        setState(() {
                          _consentToShareInfo = value ?? false;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'I consent to MedWave sharing my information with our finance providers to facilitate the purchase process.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Additional Notes
              TextFormField(
                controller: _additionalNotesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Additional notes from sales or special requirements',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your contact information',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // First Name
                TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    hintText: 'Enter your first name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    hintText: 'Enter your last name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Cell Number
                TextFormField(
                  controller: _cellNumberController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Direct Cell Number *',
                    hintText: 'Enter your cell phone number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your cell number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'What is the best email to reach you',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfoStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about your organization',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Company Name
              TextFormField(
                controller: _companyNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'What is the full legal name of your company',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your company name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Company Address
              TextFormField(
                controller: _companyAddressController,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Company Address *',
                  hintText: 'What is the address of your company (City, State, zip code)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your company address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Sales Person
              TextFormField(
                controller: _salesPersonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Sales Person *',
                  hintText: 'Who is the sales person you are dealing with',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the sales person name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Purchase Method
              const Text(
                'How are you planning to purchase your MedWave package? *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              ..._purchaseMethods.map((method) => RadioListTile<String>(
                title: Text(method),
                value: method,
                groupValue: _purchaseMethod,
                onChanged: (value) {
                  setState(() {
                    _purchaseMethod = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              )),
              const SizedBox(height: 20),
              
              // Shipping Address
              TextFormField(
                controller: _shippingAddressController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address *',
                  hintText: 'Please enter full shipping address',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your shipping address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageSelectionStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Package Selection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the MedWave package that best fits your needs',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
              // Package Selection
              const Text(
                'Which package are you interested in? *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              
              ..._packages.map((package) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: RadioListTile<String>(
                  value: package['id'],
                  groupValue: _selectedPackage,
                  onChanged: (value) {
                    setState(() {
                      _selectedPackage = value!;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        package['price'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...package['features'].map<Widget>((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  tileColor: _selectedPackage == package['id']
                      ? AppTheme.primaryColor.withOpacity(0.05)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedPackage == package['id']
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                      width: _selectedPackage == package['id'] ? 2 : 1,
                    ),
                  ),
                ),
              )),
              
              const SizedBox(height: 24),
              
              // Consent Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentToShareInfo,
                      onChanged: (value) {
                        setState(() {
                          _consentToShareInfo = value ?? false;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'I consent to MedWave sharing my information with our finance providers to facilitate the purchase process.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Additional Notes
              TextFormField(
                controller: _additionalNotesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Additional notes from sales or special requirements',
                ),
              ),
            ],
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

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Info';
      case 1:
        return 'Company Info';
      case 2:
        return 'Package';
      default:
        return '';
    }
  }
}
