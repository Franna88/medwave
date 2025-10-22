import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../services/testflight_service.dart';

class DownloadAppScreen extends StatefulWidget {
  const DownloadAppScreen({super.key});

  @override
  State<DownloadAppScreen> createState() => _DownloadAppScreenState();
}

class _DownloadAppScreenState extends State<DownloadAppScreen> {
  final TestFlightService _testFlightService = TestFlightService();
  
  // Form controllers for iOS TestFlight request
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Show iOS TestFlight request form dialog
  Future<void> _showIOSRequestDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.apple, color: Color(0xFF007AFF), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Request iOS TestFlight Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'iOS TestFlight is available by private invitation only. Please provide your details and we will add you to TestFlight manually.',
                    style: TextStyle(fontSize: 14, color: AppTheme.secondaryColor, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  
                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Last Name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Contact Number
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Instructions box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2196F3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'What happens next?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. We will add you to TestFlight manually\n'
                          '2. You will receive an email invitation\n'
                          '3. Download TestFlight from the App Store\n'
                          '4. Accept the invitation and install MedWave',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0D47A1),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _firstNameController.clear();
                _lastNameController.clear();
                _contactController.clear();
                _emailController.clear();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  // Capture the widget context
                  final widgetContext = context;
                  
                  // Show loading
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (BuildContext loadingDialogContext) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );
                  
                  try {
                    await _testFlightService.submitTestFlightRequest(
                      firstName: _firstNameController.text.trim(),
                      lastName: _lastNameController.text.trim(),
                      contactNumber: _contactController.text.trim(),
                      email: _emailController.text.trim(),
                    );
                    
                    // Close loading dialog
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    // Close form dialog
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    // Show success message
                    if (widgetContext.mounted) {
                      _showSuccessDialog(widgetContext);
                    }
                    
                    // Clear form
                    _firstNameController.clear();
                    _lastNameController.clear();
                    _contactController.clear();
                    _emailController.clear();
                    
                  } catch (e) {
                    // Close loading dialog
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    // Show error
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit request: $e'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show success dialog after iOS request submission
  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Request Submitted!'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your TestFlight access request has been submitted successfully.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
              Text(
                'We will review your request and send you a TestFlight invitation to your email within 24-48 hours.',
                style: TextStyle(fontSize: 14, color: AppTheme.secondaryColor, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Please check your email (including spam folder) for the invitation.',
                style: TextStyle(fontSize: 14, color: AppTheme.secondaryColor, height: 1.5),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show Android installation instructions dialog before download
  Future<void> _showAndroidInstructionsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.android, color: Color(0xFF3DDC84), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Android APK Installation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before installing the MedWave APK, please follow these steps:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                
                // Warning box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Color(0xFF856404), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Important Security Note',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF856404),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This app is distributed outside Google Play Store. Only download from this official MedWave page.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF856404),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Installation steps
                _buildInstallStep(
                  '1',
                  'Enable Unknown Sources',
                  'Go to Settings → Apps → Special app access → Install unknown apps → Select your browser → Enable "Allow from this source"',
                ),
                _buildInstallStep(
                  '2',
                  'Download the APK',
                  'Click "Continue to Download" below. The APK file (66.8 MB) will be downloaded to your device.',
                ),
                _buildInstallStep(
                  '3',
                  'Install the App',
                  'Open your Downloads folder, tap the APK file, and tap "Install" when prompted.',
                ),
                _buildInstallStep(
                  '4',
                  'Disable Unknown Sources',
                  'For security, return to Settings and disable "Install unknown apps" for your browser.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _downloadAndroidAPK(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DDC84),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Continue to Download'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildInstallStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
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
  
  /// Download Android APK from Firebase Storage via Cloud Function
  Future<void> _downloadAndroidAPK(BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Preparing download...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Call Cloud Function to get signed download URL
      final response = await http.get(
        Uri.parse('https://us-central1-medx-ai.cloudfunctions.net/api/api/download/apk'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final downloadUrl = data['downloadUrl'] as String;
        
        // Launch download URL
        final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
          
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
                content: Text('Download started! Check your downloads folder.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          throw Exception('Could not launch download URL');
        }
      } else {
        throw Exception('Failed to get download URL: ${response.statusCode}');
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isLargeScreen = isTablet || isDesktop;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Download MedWave App',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w600,
            fontSize: screenWidth < 600 ? 16 : 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 16 : (isLargeScreen ? 48 : 24),
            vertical: screenWidth < 600 ? 16 : 24,
          ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth < 600 ? double.infinity : 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Beta Notice Banner
                  _buildBetaBanner(screenWidth),
                  
                  SizedBox(height: screenWidth < 600 ? 16 : 24),
                  
                  // Header with Logo
                  SizedBox(height: screenWidth < 600 ? 10 : 20),
                  // MedWave Logo
                  Container(
                    width: screenWidth < 600 ? 100 : 120,
                    height: screenWidth < 600 ? 100 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.headerGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(screenWidth < 600 ? 25 : 30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          offset: const Offset(0, 8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.medical_services,
                      size: screenWidth < 600 ? 50 : 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: screenWidth < 600 ? 16 : 24),
                  Text(
                    'Choose Your Platform',
                    style: TextStyle(
                      fontSize: screenWidth < 600 ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenWidth < 600 ? 8 : 12),
                  Text(
                    'Download MedWave for your device',
                    style: TextStyle(
                      fontSize: screenWidth < 600 ? 14 : 18,
                      color: AppTheme.secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: screenWidth < 600 ? 32 : 60),
                  
                  // Download Cards
                  isLargeScreen
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: _buildIOSCard(context, screenWidth),
                            ),
                            SizedBox(width: screenWidth < 900 ? 16 : 32),
                            Flexible(
                              child: _buildAndroidCard(context, screenWidth),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildIOSCard(context, screenWidth),
                            SizedBox(height: screenWidth < 600 ? 16 : 24),
                            _buildAndroidCard(context, screenWidth),
                          ],
                        ),
                  
                  SizedBox(height: screenWidth < 600 ? 32 : 60),
                  
                  // Key Features to Test
                  _buildKeyFeatures(screenWidth),
                  
                  SizedBox(height: screenWidth < 600 ? 32 : 60),
                  
                  // App Info
                  _buildAppInfo(),
                  
                  const SizedBox(height: 40),
                  
                  // Beta Testing Info
                  _buildBetaTestingInfo(screenWidth),
                  
                  const SizedBox(height: 40),
                  
                  // Support Section
                  _buildSupportSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSCard(BuildContext context, double screenWidth) {
    final isMobile = screenWidth < 600;
    final cardPadding = isMobile ? 20.0 : 32.0;
    final iconSize = isMobile ? 60.0 : 80.0;
    
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: isMobile ? 15 : 20,
            offset: Offset(0, isMobile ? 5 : 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        children: [
          // iOS Icon
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            ),
            child: Icon(
              Icons.apple,
              size: isMobile ? 40 : 50,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          Text(
            'iOS',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 8 : 12),
          
          Text(
            'iPhone & iPad',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: AppTheme.secondaryColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          Text(
            'Available via TestFlight - private invitation only. Submit your details to request access.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: AppTheme.secondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isMobile ? 24 : 32),
          
          SizedBox(
            width: double.infinity,
            height: isMobile ? 48 : 56,
            child: ElevatedButton.icon(
              onPressed: () => _showIOSRequestDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
              ),
              icon: Icon(Icons.edit_outlined, size: isMobile ? 18 : 20),
              label: Text(
                'Request TestFlight Access',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          SizedBox(height: isMobile ? 12 : 16),
          
          Text(
            'Requires iOS 12.0 or later',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: AppTheme.secondaryColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          // Installation Steps
          _buildInstallationSteps([
            'Submit your request details',
            'Wait for TestFlight invitation email',
            'Download TestFlight from App Store',
            'Accept invitation and install MedWave',
          ]),
        ],
      ),
    );
  }

  Widget _buildAndroidCard(BuildContext context, double screenWidth) {
    final isMobile = screenWidth < 600;
    final cardPadding = isMobile ? 20.0 : 32.0;
    final iconSize = isMobile ? 60.0 : 80.0;
    
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: isMobile ? 15 : 20,
            offset: Offset(0, isMobile ? 5 : 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        children: [
          // Android Icon
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3DDC84), Color(0xFF00C853)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            ),
            child: Icon(
              Icons.android,
              size: isMobile ? 40 : 50,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          Text(
            'Android',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 8 : 12),
          
          Text(
            'Phones & Tablets',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: AppTheme.secondaryColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          Text(
            'Download the APK file directly. Easy installation with step-by-step instructions.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: AppTheme.secondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isMobile ? 24 : 32),
          
          SizedBox(
            width: double.infinity,
            height: isMobile ? 48 : 56,
            child: ElevatedButton.icon(
              onPressed: () => _showAndroidInstructionsDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DDC84),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
              ),
              icon: Icon(Icons.download, size: isMobile ? 18 : 20),
              label: Text(
                'Download App',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          SizedBox(height: isMobile ? 12 : 16),
          
          Text(
            'Requires Android 5.0 or later',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: AppTheme.secondaryColor,
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          // Installation Steps
          _buildInstallationSteps([
            'Enable "Install from Unknown Sources"',
            'Download APK file (~67 MB)',
            'Open Downloads and tap APK file',
            'Follow installation prompts',
          ]),
        ],
      ),
    );
  }

  Widget _buildInstallationSteps(List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Installation Steps:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'App Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem('Version', '1.2.12 Beta'),
              _buildInfoItem('Size', '~67 MB'),
              _buildInfoItem('Updated', 'Oct 2025'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.help_outline,
            size: 40,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Contact our support team for assistance with installation or any questions.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'support@medwave.com',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetaBanner(double screenWidth) {
    final isMobile = screenWidth < 600;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.science_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'BETA VERSION',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You\'re downloading a beta version of MedWave. This version is for testing purposes and may contain bugs or incomplete features.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              color: Colors.white.withOpacity(0.95),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⚠️ Your feedback helps us improve!',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyFeatures(double screenWidth) {
    final isMobile = screenWidth < 600;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppTheme.primaryColor,
                size: isMobile ? 28 : 32,
              ),
              const SizedBox(width: 12),
              Text(
                'Key Features to Test',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFeatureItem(
            '🏥 Patient Management',
            'Add new patients, complete intake forms, and manage patient records with ease',
            isMobile,
          ),
          _buildFeatureItem(
            '📊 Session Logging',
            'Record treatment sessions, track wound measurements, and document progress with photos',
            isMobile,
          ),
          _buildFeatureItem(
            '🩹 Multi-Wound Tracking',
            'Monitor multiple wounds per patient with individual measurements and healing progress',
            isMobile,
          ),
          _buildFeatureItem(
            '📈 Progress Analytics',
            'View interactive charts showing pain reduction, wound healing, and weight changes',
            isMobile,
          ),
          _buildFeatureItem(
            '📅 Calendar & Appointments',
            'Schedule and manage appointments with integrated calendar functionality',
            isMobile,
          ),
          _buildFeatureItem(
            '📋 AI-Powered Reports',
            'Generate comprehensive progress reports and motivation letters with AI assistance',
            isMobile,
          ),
          _buildFeatureItem(
            '🔔 Smart Notifications',
            'Receive alerts for patient improvements, appointments, and important updates',
            isMobile,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please test all features and report any bugs or issues you encounter',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: AppTheme.textColor,
                      height: 1.5,
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

  Widget _buildFeatureItem(String title, String description, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: AppTheme.secondaryColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetaTestingInfo(double screenWidth) {
    final isMobile = screenWidth < 600;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF5F7FA),
            Color(0xFFE8EDF2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: AppTheme.secondaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: AppTheme.primaryColor,
                size: isMobile ? 28 : 32,
              ),
              const SizedBox(width: 12),
              Text(
                'Beta Testing Guide',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTestingInfoItem(
            Icons.bug_report_outlined,
            'Report Bugs',
            'Found an issue? Email us at support@medwave.com with details and screenshots',
            isMobile,
          ),
          _buildTestingInfoItem(
            Icons.feedback_outlined,
            'Share Feedback',
            'Your suggestions help us improve. Contact us with your thoughts and ideas',
            isMobile,
          ),
          _buildTestingInfoItem(
            Icons.update_outlined,
            'Stay Updated',
            'We release updates regularly based on feedback. Check this page for new versions',
            isMobile,
          ),
          _buildTestingInfoItem(
            Icons.description_outlined,
            'Full Testing Guide',
            'Check out BETA_TESTING_GUIDE.md in our repository for detailed instructions',
            isMobile,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Testing Priority:',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Patient onboarding and data entry\n'
                  '2. Session logging with photo uploads\n'
                  '3. Progress tracking and charts\n'
                  '4. Appointment scheduling\n'
                  '5. Report generation',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: AppTheme.secondaryColor,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingInfoItem(IconData icon, String title, String description, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: isMobile ? 20 : 24,
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
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: AppTheme.secondaryColor,
                    height: 1.5,
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
