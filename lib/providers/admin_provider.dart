import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/admin/healthcare_provider.dart';
import '../models/admin/country_analytics.dart';
import '../models/admin/admin_report.dart';
import '../models/admin/admin_user.dart';
import '../models/admin/installer.dart';
import '../models/practitioner_application.dart';
import '../services/firebase/admin_service.dart';

/// Provider for managing admin-specific data and operations
/// Handles healthcare provider management, analytics, and reporting
class AdminProvider extends ChangeNotifier {
  // Local state
  List<HealthcareProvider> _providers = [];
  List<HealthcareProvider> _pendingApprovals = [];
  List<CountryAnalytics> _countryAnalytics = [];
  List<AdminReport> _reports = [];
  
  // Real Firebase data (from users collection)
  List<Map<String, dynamic>> _realPractitionersFromUsers = [];
  
  // Practitioner applications (from practitionerApplications collection - may be empty)
  List<PractitionerApplication> _realPractitioners = [];
  List<PractitionerApplication> _realPendingApprovals = [];

  // Admin User Management
  List<AdminUser> _adminUsers = [];
  StreamSubscription<List<AdminUser>>? _adminUsersSubscription;
  Map<String, dynamic> _adminAnalytics = {};

  // Installer Management
  List<Installer> _installers = [];
  StreamSubscription<List<Installer>>? _installersSubscription;
  
  // Streams subscriptions
  StreamSubscription<List<PractitionerApplication>>? _practitionersSubscription;
  StreamSubscription<List<PractitionerApplication>>? _pendingSubscription;
  
  bool _isLoading = false;
  String? _error;
  String? _selectedCountry;
  
  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = true;
  
  // Getters
  List<HealthcareProvider> get providers => _providers;
  List<HealthcareProvider> get pendingApprovals => _pendingApprovals;
  List<HealthcareProvider> get approvedProviders => 
      _providers.where((p) => p.isApproved).toList();
  List<CountryAnalytics> get countryAnalytics => _countryAnalytics;
  List<AdminReport> get reports => _reports;
  
  // Real practitioners from users collection (actual users of the app)
  List<Map<String, dynamic>> get realPractitionersFromUsers => _realPractitionersFromUsers;
  int get realPractitionersCount => _realPractitionersFromUsers.length;
  int get realApprovedPractitionersCount => _realPractitionersFromUsers
      .where((p) => p['isApproved'] == true)
      .length;
  int get realPendingPractitionersCount => _realPractitionersFromUsers
      .where((p) => p['isApproved'] != true)
      .length;
  
  // Real Firebase data getters (from applications - may be empty)
  List<PractitionerApplication> get realPractitioners => _realPractitioners;
  List<PractitionerApplication> get realPendingApprovals => _realPendingApprovals;

  // Admin User Management getters
  List<AdminUser> get adminUsers => _adminUsers;
  bool get hasAdminUsers => _adminUsers.isNotEmpty;
  List<PractitionerApplication> get realApprovedPractitioners => 
      _realPractitioners.where((p) => p.isApproved).toList();
  Map<String, dynamic> get adminAnalytics => _adminAnalytics;

  // Installer Management getters
  List<Installer> get installers => _installers;
  bool get hasInstallers => _installers.isNotEmpty;
  int get totalInstallers => _installers.length;
  int get activeInstallers => _installers.where((i) => i.status == InstallerStatus.active).length;
  int get inactiveInstallers => _installers.where((i) => i.status == InstallerStatus.inactive).length;
  int get suspendedInstallers => _installers.where((i) => i.status == InstallerStatus.suspended).length;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCountry => _selectedCountry;

  // Filtered data based on country selection
  List<HealthcareProvider> get filteredProviders {
    if (_selectedCountry == null) return _providers;
    return _providers.where((p) => p.country == _selectedCountry).toList();
  }

  List<HealthcareProvider> get filteredPendingApprovals {
    if (_selectedCountry == null) return _pendingApprovals;
    return _pendingApprovals.where((p) => p.country == _selectedCountry).toList();
  }

  // Statistics
  int get totalProviders {
    if (_useFirebase) {
      return _realPractitioners.length;
    }
    return _providers.length;
  }
  
  int get totalPendingApprovals {
    if (_useFirebase) {
      return _realPendingApprovals.length;
    }
    return _pendingApprovals.length;
  }
  
  int get totalApprovedProviders {
    if (_useFirebase) {
      return realApprovedPractitioners.length;
    }
    return approvedProviders.length;
  }
  
  double get approvalRate {
    final total = totalProviders + totalPendingApprovals;
    if (total == 0) return 0.0;
    return (totalApprovedProviders / total) * 100;
  }

  /// Initialize with real Firebase data or mock data for development
  void initializeWithMockData() {
    if (_useFirebase) {
      _loadFirebaseData();
    } else {
      _loadMockDataOnly();
    }
  }

  /// Load real Firebase data
  void _loadFirebaseData() {
    _isLoading = true;
    notifyListeners();

    try {
      // Subscribe to REAL practitioners from users collection (actual app users)
      _practitionersSubscription?.cancel();
      AdminService.getRealPractitionersStream().listen(
        (practitioners) {
          _realPractitionersFromUsers = practitioners;
          _isLoading = false;
          _error = null;
          notifyListeners();
          
          if (kDebugMode) {
            print('✅ AdminProvider: Loaded ${practitioners.length} REAL practitioners from users collection');
            print('   - Approved: ${practitioners.where((p) => p['isApproved'] == true).length}');
            print('   - Pending: ${practitioners.where((p) => p['isApproved'] != true).length}');
          }
        },
        onError: (error) {
          _error = 'Failed to load real practitioners: $error';
          _isLoading = false;
          notifyListeners();
          
          if (kDebugMode) {
            print('❌ AdminProvider ERROR: Failed to load real practitioners: $error');
          }
        },
      );
      
      // Also subscribe to practitioner applications (may be empty)
      AdminService.getAllPractitionersStream().listen(
        (practitioners) {
          _realPractitioners = practitioners;
          notifyListeners();
          
          if (kDebugMode) {
            print('📋 AdminProvider: Loaded ${practitioners.length} practitioner applications');
          }
        },
      );

      // Subscribe to pending approvals
      _pendingSubscription = AdminService.getPendingPractitionersStream().listen(
        (pendingPractitioners) {
          _realPendingApprovals = pendingPractitioners;
          notifyListeners();
          
          if (kDebugMode) {
            print('✅ AdminProvider: Loaded ${pendingPractitioners.length} pending applications from Firebase');
          }
        },
        onError: (error) {
          _error = 'Failed to load pending applications: $error';
          notifyListeners();
          
          if (kDebugMode) {
            print('❌ AdminProvider ERROR: Failed to load pending applications: $error');
          }
        },
      );

      // Load analytics data
      _loadAnalyticsData();
      
    } catch (e) {
      _error = 'Failed to initialize Firebase data: $e';
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to initialize Firebase data: $e');
      }
    }
  }

  /// Load analytics data from Firebase
  Future<void> _loadAnalyticsData() async {
    try {
      _adminAnalytics = await AdminService.getAdminAnalytics();
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ AdminProvider: Loaded analytics data from Firebase');
        print('   - Total Patients: ${_adminAnalytics['totalPatients']}');
        print('   - Total Sessions: ${_adminAnalytics['totalSessions']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to load analytics: $e');
      }
    }
  }

  /// Load mock data only (for development)
  void _loadMockDataOnly() {
    _isLoading = true;
    notifyListeners();

    // Simulate API delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      _loadMockData();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Load mock data for development and testing
  void _loadMockData() {
    // Mock approved providers
    _providers = [
      HealthcareProvider(
        id: '1',
        firstName: 'Dr. Sarah',
        lastName: 'Johnson',
        email: 'sarah.johnson@clinic.com',
        directPhoneNumber: '+1-555-0101',
        fullCompanyName: 'Johnson Wound Care Clinic',
        businessAddress: '123 Medical Center Dr, Boston, MA',
        salesPerson: 'John Smith',
        purchasePlan: 'Premium',
        shippingAddress: '123 Medical Center Dr, Boston, MA',
        package: 'Complete Wound Care System',
        isApproved: true,
        registrationDate: DateTime.now().subtract(const Duration(days: 30)),
        approvalDate: DateTime.now().subtract(const Duration(days: 25)),
        country: 'USA',
      ),
      HealthcareProvider(
        id: '2',
        firstName: 'Dr. Michael',
        lastName: 'Chen',
        email: 'michael.chen@healthcare.com',
        directPhoneNumber: '+1-555-0102',
        fullCompanyName: 'Chen Medical Associates',
        businessAddress: '456 Health Plaza, San Francisco, CA',
        salesPerson: 'Jane Doe',
        purchasePlan: 'Standard',
        shippingAddress: '456 Health Plaza, San Francisco, CA',
        package: 'Basic Wound Care System',
        isApproved: true,
        registrationDate: DateTime.now().subtract(const Duration(days: 45)),
        approvalDate: DateTime.now().subtract(const Duration(days: 40)),
        country: 'USA',
      ),
    ];

    // Mock pending approvals
    _pendingApprovals = [
      HealthcareProvider(
        id: '3',
        firstName: 'Dr. Emily',
        lastName: 'Rodriguez',
        email: 'emily.rodriguez@clinic.com',
        directPhoneNumber: '+1-555-0103',
        fullCompanyName: 'Rodriguez Dermatology',
        businessAddress: '789 Skin Care Ave, Miami, FL',
        salesPerson: 'Bob Wilson',
        purchasePlan: 'Premium',
        shippingAddress: '789 Skin Care Ave, Miami, FL',
        package: 'Complete Wound Care System',
        isApproved: false,
        registrationDate: DateTime.now().subtract(const Duration(days: 5)),
        country: 'USA',
      ),
      HealthcareProvider(
        id: '4',
        firstName: 'Dr. James',
        lastName: 'Wilson',
        email: 'james.wilson@medical.com',
        directPhoneNumber: '+1-555-0104',
        fullCompanyName: 'Wilson Family Medicine',
        businessAddress: '321 Family Dr, Chicago, IL',
        salesPerson: 'Alice Brown',
        purchasePlan: 'Standard',
        shippingAddress: '321 Family Dr, Chicago, IL',
        package: 'Basic Wound Care System',
        isApproved: false,
        registrationDate: DateTime.now().subtract(const Duration(days: 3)),
        country: 'USA',
      ),
    ];

    // Mock country analytics
    _countryAnalytics = [
      CountryAnalytics(
        id: 'USA',
        countryName: 'United States',
        totalPractitioners: 45,
        activePractitioners: 38,
        pendingApplications: 8,
        approvedThisMonth: 12,
        rejectedThisMonth: 2,
        totalPatients: 234,
        newPatientsThisMonth: 45,
        totalSessions: 1456,
        sessionsThisMonth: 234,
        averageSessionsPerPractitioner: 32.4,
        averagePatientsPerPractitioner: 5.2,
        averageWoundHealingRate: 78.5,
        provinces: {
          'California': ProvinceStats(
            totalPractitioners: 12,
            totalPatients: 78,
            totalSessions: 456,
          ),
          'Texas': ProvinceStats(
            totalPractitioners: 10,
            totalPatients: 65,
            totalSessions: 398,
          ),
          'Florida': ProvinceStats(
            totalPractitioners: 8,
            totalPatients: 52,
            totalSessions: 312,
          ),
        },
        lastCalculated: DateTime.now().subtract(const Duration(hours: 2)),
        calculatedBy: 'admin_system',
      ),
      CountryAnalytics(
        id: 'RSA',
        countryName: 'South Africa',
        totalPractitioners: 23,
        activePractitioners: 19,
        pendingApplications: 4,
        approvedThisMonth: 6,
        rejectedThisMonth: 1,
        totalPatients: 145,
        newPatientsThisMonth: 28,
        totalSessions: 892,
        sessionsThisMonth: 156,
        averageSessionsPerPractitioner: 38.8,
        averagePatientsPerPractitioner: 6.3,
        averageWoundHealingRate: 82.1,
        provinces: {
          'Gauteng': ProvinceStats(
            totalPractitioners: 8,
            totalPatients: 52,
            totalSessions: 312,
          ),
          'Western Cape': ProvinceStats(
            totalPractitioners: 6,
            totalPatients: 39,
            totalSessions: 234,
          ),
          'KwaZulu-Natal': ProvinceStats(
            totalPractitioners: 5,
            totalPatients: 32,
            totalSessions: 198,
          ),
        },
        lastCalculated: DateTime.now().subtract(const Duration(hours: 3)),
        calculatedBy: 'admin_system',
      ),
    ];

    if (kDebugMode) {
      print('✅ AdminProvider: Mock data loaded successfully');
      print('   - Providers: ${_providers.length}');
      print('   - Pending: ${_pendingApprovals.length}');
      print('   - Analytics: ${_countryAnalytics.length}');
    }
  }

  /// Set country filter
  void setCountryFilter(String? country) {
    _selectedCountry = country;
    notifyListeners();
  }

  /// Approve a provider application
  Future<void> approveProvider(String providerId, String reason) async {
    if (_useFirebase) {
      return _approveProviderFirebase(providerId, reason);
    } else {
      return _approveProviderMock(providerId, reason);
    }
  }

  /// Approve provider using Firebase
  Future<void> _approveProviderFirebase(String providerId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      await AdminService.approvePractitioner(providerId, reason);

      _isLoading = false;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('✅ AdminProvider: Provider approved via Firebase: $providerId');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to approve provider: $e');
      }
    }
  }

  /// Approve provider using mock data
  Future<void> _approveProviderMock(String providerId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Find the provider in pending approvals
      final providerIndex = _pendingApprovals.indexWhere((p) => p.id == providerId);
      if (providerIndex == -1) {
        throw Exception('Provider not found in pending approvals');
      }

      final provider = _pendingApprovals[providerIndex];
      
      // Move to approved providers
      final approvedProvider = provider.copyWith(
        isApproved: true,
        approvalDate: DateTime.now(),
      );

      _providers.add(approvedProvider);
      _pendingApprovals.removeAt(providerIndex);

      _isLoading = false;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Provider approved: ${provider.fullName}');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ Error approving provider: $e');
      }
    }
  }

  /// Approve a real practitioner (in users collection)
  Future<void> approveRealPractitioner(String userId) async {
    try {
      await AdminService.approveRealPractitioner(userId);
      
      if (kDebugMode) {
        print('✅ AdminProvider: Real practitioner approved: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to approve real practitioner: $e');
      }
      rethrow;
    }
  }

  /// Reject a real practitioner (in users collection)
  Future<void> rejectRealPractitioner(String userId, String reason) async {
    try {
      await AdminService.rejectRealPractitioner(userId, reason);
      
      if (kDebugMode) {
        print('❌ AdminProvider: Real practitioner rejected: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to reject real practitioner: $e');
      }
      rethrow;
    }
  }

  /// Reject a provider application
  Future<void> rejectProvider(String providerId, String reason) async {
    if (_useFirebase) {
      return _rejectProviderFirebase(providerId, reason);
    } else {
      return _rejectProviderMock(providerId, reason);
    }
  }

  /// Reject provider using Firebase
  Future<void> _rejectProviderFirebase(String providerId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      await AdminService.rejectPractitioner(providerId, reason);

      _isLoading = false;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('✅ AdminProvider: Provider rejected via Firebase: $providerId');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ AdminProvider ERROR: Failed to reject provider: $e');
      }
    }
  }

  /// Reject provider using mock data
  Future<void> _rejectProviderMock(String providerId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Remove from pending approvals
      _pendingApprovals.removeWhere((p) => p.id == providerId);

      _isLoading = false;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Provider rejected: $providerId, Reason: $reason');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      
      if (kDebugMode) {
        print('❌ Error rejecting provider: $e');
      }
    }
  }

  /// Get analytics for specific country
  CountryAnalytics? getCountryAnalytics(String countryCode) {
    try {
      return _countryAnalytics.firstWhere((analytics) => analytics.id == countryCode);
    } catch (e) {
      return null;
    }
  }

  /// Refresh analytics data
  Future<void> refreshAnalytics() async {
    _isLoading = true;
    notifyListeners();

    // Simulate refresh delay
    await Future.delayed(const Duration(milliseconds: 1500));

    // Update analytics with current timestamp
    _countryAnalytics = _countryAnalytics.map((analytics) => 
      analytics.copyWith(lastCalculated: DateTime.now())
    ).toList();

    _isLoading = false;
    notifyListeners();

    if (kDebugMode) {
      print('✅ Analytics refreshed');
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel Firebase subscriptions
    _practitionersSubscription?.cancel();
    _pendingSubscription?.cancel();
    _adminUsersSubscription?.cancel();
    _installersSubscription?.cancel();
    super.dispose();
  }

  // ============================================================================
  // ADMIN USER MANAGEMENT METHODS
  // ============================================================================

  /// Load admin users (Super Admin only)
  Future<void> loadAdminUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Cancel existing subscription
      _adminUsersSubscription?.cancel();

      // Subscribe to admin users stream
      _adminUsersSubscription = AdminService.getAdminUsersStream().listen(
        (adminUsers) {
          _adminUsers = adminUsers;
          _isLoading = false;
          notifyListeners();

          if (kDebugMode) {
            print('✅ ADMIN PROVIDER: Loaded ${adminUsers.length} admin users');
          }
        },
        onError: (error) {
          _error = 'Failed to load admin users: $error';
          _isLoading = false;
          notifyListeners();

          if (kDebugMode) {
            print('❌ ADMIN PROVIDER ERROR: Failed to load admin users: $error');
          }
        },
      );
    } catch (e) {
      _error = 'Failed to load admin users: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to load admin users: $e');
      }
    }
  }

  /// Create a new admin user (Super Admin only)
  Future<bool> createAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required AdminRole role,
    required String country,
    String? countryName,
    required String createdBy,
    String? notes,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await AdminService.createAdminUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        country: country,
        countryName: countryName,
        createdBy: createdBy,
        notes: notes,
      );

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Created admin user: $firstName $lastName ($email)');
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to create admin user: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to create admin user: $e');
      }

      return false;
    }
  }

  /// Update admin user status
  Future<bool> updateAdminUserStatus(String adminUserId, AdminUserStatus status) async {
    try {
      await AdminService.updateAdminUserStatus(adminUserId, status);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Updated admin user status: $adminUserId -> ${status.value}');
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to update admin user status: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to update admin user status: $e');
      }

      return false;
    }
  }

  /// Update admin user details
  Future<bool> updateAdminUser(String adminUserId, Map<String, dynamic> updates) async {
    try {
      await AdminService.updateAdminUser(adminUserId, updates);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Updated admin user: $adminUserId');
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to update admin user: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to update admin user: $e');
      }

      return false;
    }
  }

  /// Delete admin user (Super Admin only)
  Future<bool> deleteAdminUser(String adminUserId, String userId) async {
    try {
      await AdminService.deleteAdminUser(adminUserId, userId);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Deleted admin user: $adminUserId');
      }

      return true;
    } catch (e) {
      _error = 'Failed to delete admin user: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to delete admin user: $e');
      }

      return false;
    }
  }

  // ============================================================================
  // INSTALLER MANAGEMENT METHODS
  // ============================================================================

  /// Load installers (Super Admin only)
  Future<void> loadInstallers() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Cancel existing subscription
      _installersSubscription?.cancel();

      // Subscribe to installers stream
      _installersSubscription = AdminService.getInstallersStream().listen(
        (installers) {
          _installers = installers;
          _isLoading = false;
          notifyListeners();

          if (kDebugMode) {
            print('✅ ADMIN PROVIDER: Loaded ${installers.length} installers');
          }
        },
        onError: (error) {
          _error = 'Failed to load installers: $error';
          _isLoading = false;
          notifyListeners();

          if (kDebugMode) {
            print('❌ ADMIN PROVIDER ERROR: Failed to load installers: $error');
          }
        },
      );
    } catch (e) {
      _error = 'Failed to load installers: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to load installers: $e');
      }
    }
  }

  /// Create a new installer (Super Admin only)
  Future<bool> createInstaller({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String address,
    required String city,
    required String province,
    required String postalCode,
    required String country,
    String? countryName,
    required String serviceArea,
    required String createdBy,
    String? notes,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await AdminService.createInstaller(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        address: address,
        city: city,
        province: province,
        postalCode: postalCode,
        country: country,
        countryName: countryName,
        serviceArea: serviceArea,
        createdBy: createdBy,
        notes: notes,
      );

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Created installer: $firstName $lastName ($email)');
      }

      return true;
    } catch (e) {
      _error = 'Failed to create installer: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to create installer: $e');
      }

      return false;
    }
  }

  /// Update installer status
  Future<bool> updateInstallerStatus(String installerId, InstallerStatus status) async {
    try {
      await AdminService.updateInstallerStatus(installerId, status);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Updated installer status: $installerId -> ${status.value}');
      }

      return true;
    } catch (e) {
      _error = 'Failed to update installer status: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to update installer status: $e');
      }

      return false;
    }
  }

  /// Update installer details
  Future<bool> updateInstaller(String installerId, Map<String, dynamic> updates) async {
    try {
      await AdminService.updateInstaller(installerId, updates);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Updated installer: $installerId');
      }

      return true;
    } catch (e) {
      _error = 'Failed to update installer: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to update installer: $e');
      }

      return false;
    }
  }

  /// Delete installer (Super Admin only)
  Future<bool> deleteInstaller(String installerId, String userId) async {
    try {
      await AdminService.deleteInstaller(installerId, userId);

      if (kDebugMode) {
        print('✅ ADMIN PROVIDER: Deleted installer: $installerId');
      }

      return true;
    } catch (e) {
      _error = 'Failed to delete installer: $e';
      notifyListeners();

      if (kDebugMode) {
        print('❌ ADMIN PROVIDER ERROR: Failed to delete installer: $e');
      }

      return false;
    }
  }
}