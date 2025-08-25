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
  
  // Form Controllers - Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  
  // Form Controllers - Professional Information
  final _licenseNumberController = TextEditingController();
  final _specializationController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _practiceLocationController = TextEditingController();
  
  // Form Controllers - Location Information
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();
  
  // Form State
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptTerms = false;
  String _selectedCountry = 'ZA';
  String _selectedCountryName = 'South Africa';
  
  int _currentStep = 0;
  final int _totalSteps = 3;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Country options with country codes
  final List<Map<String, String>> _countries = [
    {'code': 'ZA', 'name': 'South Africa', 'flag': '🇿🇦'},
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'AU', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': 'NZ', 'name': 'New Zealand', 'flag': '🇳🇿'},
    {'code': 'DE', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
    {'code': 'NL', 'name': 'Netherlands', 'flag': '🇳🇱'},
    {'code': 'BE', 'name': 'Belgium', 'flag': '🇧🇪'},
  ];

  // Specialization options
  final List<String> _specializations = [
    'Wound Care Specialist',
    'General Practitioner',
    'Dermatologist',
    'Plastic Surgeon',
    'Vascular Surgeon',
    'Podiatrist',
    'Nurse Practitioner',
    'Registered Nurse',
    'Physical Therapist',
    'Occupational Therapist',
    'Other Medical Professional',
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _yearsOfExperienceController.dispose();
    _practiceLocationController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Validate current step before proceeding
      if (!_validateCurrentStep()) return;
      
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

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validatePersonalInfo();
      case 1:
        return _validateProfessionalInfo();
      case 2:
        return _validateLocationInfo();
      default:
        return true;
    }
  }

  bool _validatePersonalInfo() {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _phoneNumberController.text.isEmpty) {
      _showError('Please fill in all required fields');
      return false;
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      _showError('Please enter a valid email address');
      return false;
    }
    
    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return false;
    }
    
    return true;
  }

  bool _validateProfessionalInfo() {
    if (_licenseNumberController.text.isEmpty ||
        _specializationController.text.isEmpty ||
        _yearsOfExperienceController.text.isEmpty ||
        _practiceLocationController.text.isEmpty) {
      _showError('Please fill in all professional information fields');
      return false;
    }
    
    final experience = int.tryParse(_yearsOfExperienceController.text);
    if (experience == null || experience < 0 || experience > 50) {
      _showError('Please enter valid years of experience (0-50)');
      return false;
    }
    
    return true;
  }

  bool _validateLocationInfo() {
    if (_addressController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _provinceController.text.isEmpty ||
        _postalCodeController.text.isEmpty) {
      _showError('Please fill in all location fields');
      return false;
    }
    
    if (!_acceptTerms) {
      _showError('Please accept the terms and conditions');
      return false;
    }
    
    return true;
  }

  void _showError(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
      );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate() || !_validateLocationInfo()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    
    debugPrint('Starting signup process...');
    
    final signupData = {
      // Personal Information
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'password': _passwordController.text,
      'phoneNumber': _phoneNumberController.text.trim(),
      
      // Professional Information
      'licenseNumber': _licenseNumberController.text.trim(),
      'specialization': _specializationController.text.trim(),
      'yearsOfExperience': int.tryParse(_yearsOfExperienceController.text.trim()) ?? 0,
      'practiceLocation': _practiceLocationController.text.trim(),
      
      // Location Information
      'country': _selectedCountry,
      'countryName': _selectedCountryName,
      'province': _provinceController.text.trim(),
      'city': _cityController.text.trim(),
      'address': _addressController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
    };

    debugPrint('Calling authProvider.signup with email: ${signupData['email']}');
    final success = await authProvider.signup(signupData);
    debugPrint('Signup result: $success');

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        _showSuccessDialog();
      } else {
        _showError(authProvider.errorMessage ?? 'Failed to submit application. Please try again.');
      }
    }
  }

  void _showSuccessDialog() {
    final authProvider = context.read<AuthProvider>();
    final isAutoApproved = authProvider.isAutoApprovalEnabled;
    
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
                isAutoApproved ? Icons.verified : Icons.check_circle,
                color: AppTheme.successColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(isAutoApproved ? 'Account Created & Approved!' : 'Application Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAutoApproved 
                  ? 'Welcome to MedWave! Your account is ready to use.'
                  : 'Thank you for your application to join MedWave!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              isAutoApproved
                  ? 'Your practitioner account has been automatically approved for testing purposes. You can now access all features of the app.'
                  : 'Your practitioner application has been submitted for review. Our admin team will verify your credentials and notify you within 24-48 hours.',
            ),
            const SizedBox(height: 12),
            if (isAutoApproved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Development Mode: Auto-approval is enabled for testing',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'You will receive an email confirmation shortly with further instructions.',
                style: TextStyle(color: AppTheme.secondaryColor),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isAutoApproved) {
                // If auto-approved, go directly to dashboard
                context.go('/');
              } else {
                // If pending approval, go to login
                context.go('/login');
              }
            },
            child: Text(isAutoApproved ? 'Start Using MedWave' : 'Go to Login'),
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
                              'Join MedWave',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Healthcare Professionals',
                              style: TextStyle(
                                fontSize: 24,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Apply to become a verified practitioner and transform your wound care practice with our advanced management platform.',
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
                                Icons.verified_user,
                                'Professional Verification',
                                'Secure application process with credential verification',
                                AppTheme.successColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.medical_information,
                                'Advanced Wound Care',
                                'Comprehensive tools for wound management and tracking',
                                AppTheme.infoColor,
                              ),
                              const SizedBox(height: 32),
                              _buildTabletFeatureItem(
                                Icons.analytics,
                                'Clinical Analytics',
                                'Evidence-based insights to improve patient outcomes',
                                AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Right side - Registration form
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
                                        textAlign: TextAlign.center,
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
                      child: Form(
                        key: _formKey,
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                            _buildPersonalInfoStep(),
                            _buildProfessionalInfoStep(),
                            _buildLocationInfoStep(),
                          ],
                        ),
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
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          'Practitioner Registration',
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
                              textAlign: TextAlign.center,
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
            child: Form(
              key: _formKey,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoStep(),
                  _buildProfessionalInfoStep(),
                  _buildLocationInfoStep(),
              ],
              ),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
            'Enter your personal details',
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
              prefixIcon: Icon(Icons.person),
            ),
                ),
                const SizedBox(height: 20),
                
                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    hintText: 'Enter your last name',
              prefixIcon: Icon(Icons.person_outline),
            ),
                ),
                const SizedBox(height: 20),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
              hintText: 'Enter your professional email',
              prefixIcon: Icon(Icons.email),
            ),
              ),
              const SizedBox(height: 20),
              
          // Phone Number
              TextFormField(
            controller: _phoneNumberController,
            keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: 'Enter your contact number',
              prefixIcon: Icon(Icons.phone),
            ),
              ),
              const SizedBox(height: 20),
              
          // Password
              TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
                textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password *',
              hintText: 'Create a secure password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
          ),
              const SizedBox(height: 20),
              
          // Confirm Password
              TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_confirmPasswordVisible,
                textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              hintText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                    setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                    });
                  },
              ),
                              ),
                            ),
                          ],
      ),
    );
  }

  Widget _buildProfessionalInfoStep() {
    return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
            'Professional Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
            'Tell us about your professional credentials',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
          // License Number
                TextFormField(
            controller: _licenseNumberController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
              labelText: 'License Number *',
              hintText: 'Enter your professional license number',
              prefixIcon: Icon(Icons.badge),
            ),
                ),
                const SizedBox(height: 20),
                
          // Specialization Dropdown
          DropdownButtonFormField<String>(
            value: _specializationController.text.isEmpty ? null : _specializationController.text,
                  decoration: const InputDecoration(
              labelText: 'Specialization *',
              hintText: 'Select your specialization',
              prefixIcon: Icon(Icons.medical_services),
            ),
            items: _specializations.map((specialization) {
              return DropdownMenuItem(
                value: specialization,
                child: Text(specialization),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _specializationController.text = value ?? '';
              });
                  },
                ),
                const SizedBox(height: 20),
                
          // Years of Experience
                TextFormField(
            controller: _yearsOfExperienceController,
            keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
              labelText: 'Years of Experience *',
              hintText: 'Enter years of professional experience',
              prefixIcon: Icon(Icons.timeline),
            ),
                ),
                const SizedBox(height: 20),
                
          // Practice Location
                TextFormField(
            controller: _practiceLocationController,
                  textInputAction: TextInputAction.done,
            maxLines: 2,
                  decoration: const InputDecoration(
              labelText: 'Practice Location *',
              hintText: 'Enter your primary practice location/facility',
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfoStep() {
    return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
            'Location Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
            'Provide your location details',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              
          // Country Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCountry,
                decoration: const InputDecoration(
              labelText: 'Country *',
              prefixIcon: Icon(Icons.public),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem(
                value: country['code'],
                child: Row(
                  children: [
                    Text(country['flag']!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(country['name']!),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCountry = value!;
                _selectedCountryName = _countries.firstWhere((c) => c['code'] == value)['name']!;
              });
                },
              ),
              const SizedBox(height: 20),
              
          // Province/State
              TextFormField(
            controller: _provinceController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
              labelText: 'Province/State *',
              hintText: 'Enter your province or state',
              prefixIcon: Icon(Icons.location_city),
            ),
              ),
              const SizedBox(height: 20),
              
          // City
              TextFormField(
            controller: _cityController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
              labelText: 'City *',
              hintText: 'Enter your city',
              prefixIcon: Icon(Icons.location_on),
            ),
              ),
              const SizedBox(height: 20),
              
          // Address
          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address *',
              hintText: 'Enter your street address',
              prefixIcon: Icon(Icons.home),
            ),
          ),
              const SizedBox(height: 20),
              
          // Postal Code
              TextFormField(
            controller: _postalCodeController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
              labelText: 'Postal Code *',
              hintText: 'Enter your postal code',
              prefixIcon: Icon(Icons.markunread_mailbox),
            ),
          ),
          const SizedBox(height: 32),
          
          // Terms and Conditions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
          child: Column(
              children: [
                Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    Checkbox(
                      value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                          _acceptTerms = value ?? false;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy. I understand that my application will be reviewed by MedWave administrators before approval.',
                        style: TextStyle(
                                fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              Container(
                  padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.infoColor,
                        size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                          'Your application will be reviewed within 24-48 hours. You will receive an email notification once approved.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
                ),
              ),
            ],
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
        return 'Personal';
      case 1:
        return 'Professional';
      case 2:
        return 'Location';
      default:
        return '';
    }
  }
}