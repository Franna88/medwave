import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isEditing = false;
  
  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  
  // Settings
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _biometricEnabled = false;
  String _language = 'English';
  String _timezone = 'Africa/Johannesburg';
  
  // App info
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppInfo();
  }

  void _loadAppInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Initialize profile if needed
    if (userProfileProvider.userProfile == null) {
      final userName = authProvider.userName ?? '';
      final userEmail = authProvider.userEmail ?? '';
      userProfileProvider.initializeProfile(userEmail, userName);
    }
    
    // Load profile data
    userProfileProvider.loadProfile().then((_) {
      final profile = userProfileProvider.userProfile;
      final settings = userProfileProvider.appSettings;
      
      if (profile != null) {
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _emailController.text = profile.email;
        _phoneController.text = profile.phoneNumber ?? '';
        _licenseNumberController.text = profile.licenseNumber ?? '';
      }
      
      // Load settings
      _notificationsEnabled = settings.notificationsEnabled;
      _darkModeEnabled = settings.darkModeEnabled;
      _biometricEnabled = settings.biometricEnabled;
      _language = settings.language;
      _timezone = settings.timezone;
      
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildPersonalInfoCard(),
                  const SizedBox(height: 20),
                  _buildProfessionalInfoCard(),
                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                  const SizedBox(height: 20),
                  _buildAppInfoCard(),
                  const SizedBox(height: 20),
                  _buildSupportCard(),
                  const SizedBox(height: 100), // Space for bottom navigation
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditing ? _buildSaveFAB() : null,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: const Text(
        'Profile',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: AppTheme.textColor, size: 20),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
      ),
      actions: [
        if (!_isEditing)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: AppTheme.textColor, size: 20),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isEditing = true;
              });
            },
          ),
        const SizedBox(width: 16),
      ],
             flexibleSpace: FlexibleSpaceBar(
         background: Container(
           decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [
                 AppTheme.primaryColor.withOpacity(0.3),
                 Colors.white,
               ],
               stops: const [0.0, 0.6],
             ),
           ),
         ),
       ),
    );
  }

  Widget _buildProfileHeader() {
    final userProfileProvider = context.watch<UserProfileProvider>();
    final profile = userProfileProvider.userProfile;
    
    if (profile == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                                 child: Text(
                   profile.initials,
                   style: const TextStyle(
                     color: Colors.white,
                     fontWeight: FontWeight.bold,
                     fontSize: 36,
                   ),
                 ),
              ),
            ),
            const SizedBox(height: 20),
            
                         // User Name
             Text(
               profile.fullName,
               style: const TextStyle(
                 fontSize: 24,
                 fontWeight: FontWeight.bold,
                 color: AppTheme.textColor,
               ),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 8),
             
             // User Email
             Text(
               profile.email,
               style: TextStyle(
                 fontSize: 16,
                 color: AppTheme.secondaryColor.withOpacity(0.8),
                 fontWeight: FontWeight.w500,
               ),
               textAlign: TextAlign.center,
             ),
            const SizedBox(height: 16),
            
            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.successColor.withOpacity(0.15),
                    AppTheme.successColor.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 16,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Healthcare Professional',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_outline, size: 20, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // First Name
            _buildEditableField(
              label: 'First Name',
              controller: _firstNameController,
              icon: Icons.person_outline,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            
            // Last Name
            _buildEditableField(
              label: 'Last Name',
              controller: _lastNameController,
              icon: Icons.person_outline,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            
            // Email
            _buildEditableField(
              label: 'Email Address',
              controller: _emailController,
              icon: Icons.email_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            // Phone
            _buildEditableField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    final userProfileProvider = context.watch<UserProfileProvider>();
    final profile = userProfileProvider.userProfile;
    
    if (profile == null) {
      return const SizedBox.shrink();
    }
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.work_outline, size: 20, color: AppTheme.infoColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Professional Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // License Number
            _buildEditableField(
              label: 'HPCSA License Number',
              controller: _licenseNumberController,
              icon: Icons.verified_user_outlined,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            
                         // Specialization
             _buildInfoRow(
               label: 'Specialization',
               value: profile.specialization,
               icon: Icons.medical_services_outlined,
             ),
             const SizedBox(height: 16),
             
             // Experience
             _buildInfoRow(
               label: 'Years of Experience',
               value: '${profile.yearsOfExperience} years',
               icon: Icons.timeline_outlined,
             ),
             const SizedBox(height: 16),
             
             // Practice Location
             _buildInfoRow(
               label: 'Practice Location',
               value: profile.practiceLocation,
               icon: Icons.location_on_outlined,
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings_outlined, size: 20, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Notifications
            _buildSettingTile(
              title: 'Push Notifications',
              subtitle: 'Receive alerts for appointments and updates',
              icon: Icons.notifications_outlined,
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: _isEditing ? (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                } : null,
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dark Mode
            _buildSettingTile(
              title: 'Dark Mode',
              subtitle: 'Use dark theme for the app',
              icon: Icons.dark_mode_outlined,
              trailing: Switch(
                value: _darkModeEnabled,
                onChanged: _isEditing ? (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                } : null,
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Biometric Authentication
            _buildSettingTile(
              title: 'Biometric Authentication',
              subtitle: 'Use fingerprint or face ID to login',
              icon: Icons.fingerprint_outlined,
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: _isEditing ? (value) {
                  setState(() {
                    _biometricEnabled = value;
                  });
                } : null,
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Language
            _buildSettingTile(
              title: 'Language',
              subtitle: _language,
              icon: Icons.language_outlined,
              trailing: _isEditing ? DropdownButton<String>(
                value: _language,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _language = value;
                    });
                  }
                },
                items: ['English', 'Afrikaans', 'Zulu', 'Xhosa'].map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(lang),
                  );
                }).toList(),
              ) : null,
            ),
            const SizedBox(height: 16),
            
            // Timezone
            _buildSettingTile(
              title: 'Timezone',
              subtitle: _timezone,
              icon: Icons.access_time_outlined,
              trailing: _isEditing ? DropdownButton<String>(
                value: _timezone,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _timezone = value;
                    });
                  }
                },
                items: ['Africa/Johannesburg', 'Africa/Cape_Town', 'Africa/Durban'].map((tz) {
                  return DropdownMenuItem(
                    value: tz,
                    child: Text(tz.split('/').last.replaceAll('_', ' ')),
                  );
                }).toList(),
              ) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline, size: 20, color: AppTheme.successColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildInfoRow(
              label: 'App Version',
              value: _appVersion.isEmpty ? 'Loading...' : _appVersion,
              icon: Icons.app_settings_alt_outlined,
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              label: 'Build Number',
              value: _buildNumber.isEmpty ? 'Loading...' : _buildNumber,
              icon: Icons.build_outlined,
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              label: 'Last Updated',
              value: DateFormat('MMM d, yyyy').format(DateTime.now()),
              icon: Icons.update_outlined,
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              label: 'Device ID',
              value: 'MED-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
              icon: Icons.device_hub_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.support_agent_outlined, size: 20, color: AppTheme.errorColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Support & Help',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildSupportTile(
              title: 'Help Center',
              subtitle: 'Find answers to common questions',
              icon: Icons.help_outline,
              onTap: () {
                // Navigate to help center
              },
            ),
            const SizedBox(height: 16),
            
            _buildSupportTile(
              title: 'Contact Support',
              subtitle: 'Get in touch with our team',
              icon: Icons.contact_support_outlined,
              onTap: () {
                // Open contact support
              },
            ),
            const SizedBox(height: 16),
            
            _buildSupportTile(
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              icon: Icons.privacy_tip_outlined,
              onTap: () {
                // Open privacy policy
              },
            ),
            const SizedBox(height: 16),
            
            _buildSupportTile(
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              icon: Icons.description_outlined,
              onTap: () {
                // Open terms of service
              },
            ),
            const SizedBox(height: 16),
            
            _buildSupportTile(
              title: 'Logout',
              subtitle: 'Sign out of your account',
              icon: Icons.logout,
              onTap: () {
                _showLogoutDialog();
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : AppTheme.cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? AppTheme.borderColor : AppTheme.borderColor.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.primaryColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.secondaryColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSupportTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive 
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                size: 20, 
                color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
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
                      color: isDestructive ? AppTheme.errorColor : AppTheme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.secondaryColor.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.secondaryColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveFAB() {
    return FloatingActionButton.extended(
      onPressed: _saveProfile,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.save),
      label: const Text(
        'Save Changes',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _saveProfile() async {
    // Save profile changes
    HapticFeedback.lightImpact();
    
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Update profile
    final profileSuccess = await userProfileProvider.updateProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      licenseNumber: _licenseNumberController.text,
    );
    
    // Update settings
    final settingsSuccess = await userProfileProvider.updateSettings(
      notificationsEnabled: _notificationsEnabled,
      darkModeEnabled: _darkModeEnabled,
      biometricEnabled: _biometricEnabled,
      language: _language,
      timezone: _timezone,
    );
    
    setState(() {
      _isEditing = false;
    });
    
    if (profileSuccess && settingsSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update profile'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to sign in again to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
                     ElevatedButton(
             onPressed: () {
               Navigator.of(context).pop();
               context.read<AuthProvider>().logout();
               context.read<UserProfileProvider>().clearProfile();
               context.go('/login');
             },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }


}
