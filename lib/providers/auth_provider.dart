import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../utils/role_manager.dart';
import '../services/verification_document_service.dart';
import '../services/emailjs_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VerificationDocumentService _verificationService =
      VerificationDocumentService();

  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;

  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = true; // Firebase is now configured!

  // Feature flag for auto-approval during development/testing
  // Set to true for testing, false for production approval workflow
  static const bool _autoApprovePractitioners =
      false; // Disabled for production - require admin approval

  // Mock data for development
  bool _mockAuthenticated = false;
  String? _mockEmail;
  String? _mockUserName;

  // Getters
  User? get user => _useFirebase ? _user : null;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _useFirebase ? _user != null : _mockAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userEmail => _useFirebase ? _user?.email : _mockEmail;
  String? get userName =>
      _userProfile?.fullName ??
      (_useFirebase ? _user?.displayName : _mockUserName);

  // Helper getters for development
  bool get isAutoApprovalEnabled => _autoApprovePractitioners;
  bool get isUsingFirebase => _useFirebase;

  // Check if user can access the app (approved practitioner or super admin)
  bool get canAccessApp {
    if (!_useFirebase) return _mockAuthenticated;
    return _userProfile?.accountStatus == 'approved' ||
        _userProfile?.role == 'super_admin';
  }

  // Get user role for role-based access control
  UserRole get userRole {
    if (!_useFirebase) return UserRole.practitioner;
    return UserRole.fromString(_userProfile?.role ?? 'practitioner');
  }

  // Check if user has admin privileges
  bool get isAdmin {
    return RoleManager.canAccessAdminPanel(userRole);
  }

  // Get appropriate dashboard route based on user role
  String get dashboardRoute {
    return RoleManager.getDashboardRoute(userRole);
  }

  AuthProvider() {
    if (_useFirebase) {
      _isLoading = true; // Set loading while initializing
      _initializeAuthStateListener();
    }
  }

  void _initializeAuthStateListener() {
    _auth.authStateChanges().listen((User? user) async {
      debugPrint('Auth state changed: user=${user?.email}, uid=${user?.uid}');
      _user = user;
      if (user != null) {
        _setupUserProfileListener(user.uid);
      } else {
        _userProfile = null;
      }
      _isLoading = false; // Auth state has been determined
      notifyListeners();
    });
  }

  void _setupUserProfileListener(String userId) async {
    // Cancel any existing subscription
    _userProfileSubscription?.cancel();

    // First check if this is an admin user
    try {
      final adminQuery = await _firestore
          .collection('adminUsers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        // This is an admin user - create a UserProfile from admin data
        final adminDoc = adminQuery.docs.first;
        final adminData = adminDoc.data();

        final adminRoleValue = adminData['role'] ?? 'super_admin';

        _userProfile = UserProfile(
          id: userId,
          email: adminData['email'] ?? '',
          firstName: adminData['firstName'] ?? '',
          lastName: adminData['lastName'] ?? '',
          phoneNumber: '',
          licenseNumber: '',
          specialization: 'Administrator',
          yearsOfExperience: 0,
          practiceLocation: adminData['country'] ?? '',
          country: adminData['country'] ?? '',
          countryName: adminData['countryName'] ?? '',
          province: '',
          city: '',
          address: '',
          postalCode: '',
          accountStatus: 'approved', // Admin users are always approved
          role: adminRoleValue,
          licenseVerified: true,
          professionalReferences: [],
          totalPatients: 0,
          totalSessions: 0,
          settings: UserSettings(
            notificationsEnabled: true,
            darkModeEnabled: false,
            biometricEnabled: false,
            language: 'en',
            timezone: 'UTC',
          ),
          createdAt:
              (adminData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          lastLogin: DateTime.now(),
        );

        debugPrint(
          'Admin user profile loaded: ${_userProfile?.role}, canAccessApp: $canAccessApp',
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error checking admin users: $e');
    }

    // Check if this is an installer user
    try {
      final installerQuery = await _firestore
          .collection('installers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (installerQuery.docs.isNotEmpty) {
        // This is an installer user - create a UserProfile from installer data
        final installerDoc = installerQuery.docs.first;
        final installerData = installerDoc.data();

        // Check if installer is active
        final installerStatus = installerData['status'] ?? 'inactive';
        final isActive = installerStatus == 'active';

        _userProfile = UserProfile(
          id: userId,
          email: installerData['email'] ?? '',
          firstName: installerData['firstName'] ?? '',
          lastName: installerData['lastName'] ?? '',
          phoneNumber: installerData['phoneNumber'] ?? '',
          licenseNumber: '',
          specialization: 'Installer',
          yearsOfExperience: 0,
          practiceLocation: installerData['serviceArea'] ?? '',
          country: installerData['country'] ?? '',
          countryName: installerData['countryName'] ?? '',
          province: installerData['province'] ?? '',
          city: installerData['city'] ?? '',
          address: installerData['address'] ?? '',
          postalCode: installerData['postalCode'] ?? '',
          accountStatus: isActive ? 'approved' : 'suspended',
          role: 'installer',
          licenseVerified: true,
          professionalReferences: [],
          totalPatients: 0,
          totalSessions: 0,
          settings: UserSettings(
            notificationsEnabled: true,
            darkModeEnabled: false,
            biometricEnabled: false,
            language: 'en',
            timezone: 'UTC',
          ),
          createdAt:
              (installerData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          lastLogin: DateTime.now(),
        );

        debugPrint(
          'Installer user profile loaded: ${_userProfile?.role}, status: $installerStatus, canAccessApp: $canAccessApp',
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error checking installer users: $e');
    }

    // Not an admin or installer user, listen to regular user profile
    _userProfileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              _userProfile = UserProfile.fromFirestore(doc);
              debugPrint(
                'User profile updated: ${_userProfile?.accountStatus}, canAccessApp: $canAccessApp',
              );
              notifyListeners();
            } else {
              debugPrint('User profile document does not exist');
            }
          },
          onError: (e) {
            debugPrint('Error listening to user profile: $e');
          },
        );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    if (!_useFirebase) {
      return _mockLogin(email, password);
    }

    try {
      _setLoading(true);
      _setError(null);

      // Add 30-second timeout to prevent indefinite loading
      await Future.any([
        Future.delayed(const Duration(seconds: 30)).then((_) {
          throw TimeoutException(
            'Login request timed out. Please check your internet connection and try again.',
          );
        }),
        _performLogin(email, password),
      ]);

      return true;
    } on TimeoutException catch (e) {
      _setError(e.message ?? 'Request timed out. Please try again.');
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performLogin(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last login time with separate timeout - don't fail login if this fails
    if (credential.user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({
              'lastLogin': FieldValue.serverTimestamp(),
              'lastActivityDate': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint(
                  '⚠️ Firestore lastLogin update timed out - continuing anyway',
                );
                return;
              },
            );
      } catch (e) {
        debugPrint('⚠️ Failed to update lastLogin timestamp: $e');
        // Continue anyway - login succeeded, timestamp update is not critical
      }
    }
  }

  Future<bool> signup(Map<String, dynamic> signupData) async {
    if (!_useFirebase) {
      return _mockSignup(signupData);
    }

    try {
      _setLoading(true);
      _setError(null);

      // Create user account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: signupData['email'],
        password: signupData['password'],
      );

      if (credential.user != null) {
        // Send email verification
        await credential.user!.sendEmailVerification();
        debugPrint('Email verification sent to: ${credential.user!.email}');

        // Upload verification documents
        List<String> idDocumentUrls = [];
        List<String> practiceImageUrls = [];

        if (signupData['idDocuments'] != null &&
            (signupData['idDocuments'] as List).isNotEmpty) {
          debugPrint('📤 Uploading ID documents...');
          idDocumentUrls = await _verificationService.uploadIdDocuments(
            credential.user!.uid,
            signupData['idDocuments'] as List<XFile>,
          );
          debugPrint('✅ Uploaded ${idDocumentUrls.length} ID documents');
        }

        if (signupData['practiceImages'] != null &&
            (signupData['practiceImages'] as List).isNotEmpty) {
          debugPrint('📤 Uploading practice images...');
          practiceImageUrls = await _verificationService.uploadPracticeImages(
            credential.user!.uid,
            signupData['practiceImages'] as List<XFile>,
          );
          debugPrint('✅ Uploaded ${practiceImageUrls.length} practice images');
        }

        // Add document URLs to signup data
        signupData['idDocumentUrls'] = idDocumentUrls;
        signupData['practiceImageUrls'] = practiceImageUrls;

        // Create user profile in Firestore
        await _createUserProfile(credential.user!.uid, signupData);

        // Create practitioner application
        await _createPractitionerApplication(credential.user!.uid, signupData);

        // Send email notification to admin about new practitioner registration
        // Do this asynchronously without blocking - failures shouldn't stop signup
        EmailJSService.sendPractitionerRegistrationNotification(
          practitionerName:
              '${signupData['firstName']} ${signupData['lastName']}',
          practitionerEmail: signupData['email'],
          specialization: signupData['specialization'] ?? 'N/A',
          licenseNumber: signupData['licenseNumber'] ?? 'N/A',
          country: signupData['countryName'] ?? signupData['country'] ?? 'N/A',
          registrationDate: DateFormat('MMMM d, yyyy').format(DateTime.now()),
        ).catchError((error) {
          debugPrint('⚠️ Failed to send admin notification email: $error');
          // Don't throw - email failure shouldn't block signup
          return false;
        });

        // If auto-approval is enabled, set user and load profile immediately
        if (_autoApprovePractitioners) {
          _user = credential.user;
          // Add a small delay to ensure Firestore write is complete
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadUserProfile();

          debugPrint('Auto-approved practitioner: ${credential.user!.email}');
          debugPrint('User profile loaded: ${_userProfile?.accountStatus}');
          debugPrint('Can access app: $canAccessApp');
        }
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    } catch (e) {
      debugPrint('Signup error: $e');
      _setError('Failed to create account: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    if (!_useFirebase) {
      _mockLogout();
      return;
    }

    try {
      // Cancel user profile subscription
      await _userProfileSubscription?.cancel();
      _userProfileSubscription = null;

      await _auth.signOut();
      _userProfile = null;
      _setError(null);
    } catch (e) {
      _setError('Failed to sign out. Please try again.');
    }
  }

  /// Manually refresh user profile (useful for "Refresh Status" button)
  Future<void> refreshUserProfile() async {
    if (_user == null) return;

    try {
      debugPrint('Manually refreshing user profile...');
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userProfile = UserProfile.fromFirestore(doc);
        debugPrint(
          'User profile refreshed: ${_userProfile?.accountStatus}, canAccessApp: $canAccessApp',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing user profile: $e');
    }
  }

  Future<bool> resetPassword(String email) async {
    if (!_useFirebase) {
      // Mock password reset
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    try {
      _setLoading(true);
      _setError(null);

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e));
      return false;
    } catch (e) {
      _setError('Failed to send password reset email.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;

    try {
      debugPrint('Loading user profile for: ${_user!.uid}');
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userProfile = UserProfile.fromFirestore(doc);
        debugPrint(
          'User profile loaded: ${_userProfile?.accountStatus}, canAccessApp: $canAccessApp',
        );
      } else {
        debugPrint('User profile document does not exist');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _createUserProfile(
    String userId,
    Map<String, dynamic> signupData,
  ) async {
    debugPrint('Creating user profile for: $userId');
    debugPrint('Signup data: ${signupData.keys.toList()}');

    final userProfile = {
      'firstName': signupData['firstName'],
      'lastName': signupData['lastName'],
      'email': signupData['email'],
      'phoneNumber': signupData['phoneNumber'] ?? '',
      'licenseNumber': signupData['licenseNumber'] ?? '',
      'specialization': signupData['specialization'] ?? '',
      'yearsOfExperience': signupData['yearsOfExperience'] ?? 0,
      'practiceLocation': signupData['practiceLocation'] ?? '',
      'country': signupData['country'] ?? '',
      'countryName': signupData['countryName'] ?? '',
      'province': signupData['province'] ?? '',
      'city': signupData['city'] ?? '',
      'address': signupData['address'] ?? '',
      'postalCode': signupData['postalCode'] ?? '',
      'accountStatus': _autoApprovePractitioners ? 'approved' : 'pending',
      'applicationDate': FieldValue.serverTimestamp(),
      'approvalDate': _autoApprovePractitioners
          ? FieldValue.serverTimestamp()
          : null,
      'role': 'practitioner',
      'licenseVerified': _autoApprovePractitioners ? true : false,
      'professionalReferences': [],
      // Verification documents
      'idDocumentUrls': signupData['idDocumentUrls'] ?? [],
      'practiceImageUrls': signupData['practiceImageUrls'] ?? [],
      'idDocumentUploadedAt':
          (signupData['idDocumentUrls'] as List?)?.isNotEmpty == true
          ? FieldValue.serverTimestamp()
          : null,
      'practiceImageUploadedAt':
          (signupData['practiceImageUrls'] as List?)?.isNotEmpty == true
          ? FieldValue.serverTimestamp()
          : null,
      'settings': {
        'notificationsEnabled': true,
        'darkModeEnabled': false,
        'biometricEnabled': false,
        'language': 'en',
        'timezone': 'UTC',
      },
      'totalPatients': 0,
      'totalSessions': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('users').doc(userId).set(userProfile);
      debugPrint('User profile created successfully');
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<void> _createPractitionerApplication(
    String userId,
    Map<String, dynamic> signupData,
  ) async {
    final application = {
      'userId': userId,
      'email': signupData['email'],
      'firstName': signupData['firstName'],
      'lastName': signupData['lastName'],
      'licenseNumber': signupData['licenseNumber'] ?? '',
      'specialization': signupData['specialization'] ?? '',
      'yearsOfExperience': signupData['yearsOfExperience'] ?? 0,
      'practiceLocation': signupData['practiceLocation'] ?? '',
      'country': signupData['country'] ?? '',
      'countryName': signupData['countryName'] ?? '',
      'province': signupData['province'] ?? '',
      'city': signupData['city'] ?? '',
      'status': _autoApprovePractitioners ? 'approved' : 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'approvedAt': _autoApprovePractitioners
          ? FieldValue.serverTimestamp()
          : null,
      'approvedBy': _autoApprovePractitioners ? 'auto-system' : null,
      'documents': {},
      'documentsVerified': _autoApprovePractitioners ? true : false,
      'licenseVerified': _autoApprovePractitioners ? true : false,
      'referencesVerified': false,
    };

    try {
      await _firestore.collection('practitionerApplications').add(application);
      debugPrint('Practitioner application created successfully');
    } catch (e) {
      debugPrint('Error creating practitioner application: $e');
      throw Exception('Failed to create practitioner application: $e');
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Mock methods for development
  Future<bool> _mockLogin(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.isNotEmpty && password.isNotEmpty) {
      _mockAuthenticated = true;
      _mockEmail = email;
      _mockUserName = email.split('@')[0];

      // Create mock user profile based on email for testing different roles
      String role = 'practitioner';
      String accountStatus = _autoApprovePractitioners ? 'approved' : 'pending';

      // Special test accounts for different roles
      if (email.toLowerCase() == 'admin@medwave.com' ||
          email.toLowerCase() == 'superadmin@medwave.com') {
        role = 'super_admin';
        accountStatus = 'approved';
      } else if (email.toLowerCase() == 'countryadmin@medwave.com') {
        role = 'country_admin';
        accountStatus = 'approved';
      }

      // Create mock user profile for testing
      _userProfile = UserProfile(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        firstName: 'Test',
        lastName: role == 'super_admin'
            ? 'Super Admin'
            : role == 'country_admin'
            ? 'Country Admin'
            : 'Practitioner',
        phoneNumber: '+1-555-0123',
        licenseNumber: 'TEST123',
        specialization: 'Wound Care',
        yearsOfExperience: 5,
        practiceLocation: 'Test Clinic',
        country: 'USA',
        countryName: 'United States',
        province: 'California',
        city: 'San Francisco',
        address: '123 Test Street',
        postalCode: '94102',
        accountStatus: accountStatus,
        role: role,
        licenseVerified: true,
        professionalReferences: [],
        totalPatients: 0,
        totalSessions: 0,
        settings: UserSettings(
          notificationsEnabled: true,
          darkModeEnabled: false,
          biometricEnabled: false,
          language: 'en',
          timezone: 'UTC',
        ),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> _mockSignup(Map<String, dynamic> signupData) async {
    await Future.delayed(const Duration(seconds: 2));
    _mockAuthenticated = true;
    _mockEmail = signupData['email'];
    _mockUserName = '${signupData['firstName']} ${signupData['lastName']}';

    // Create mock user profile for testing
    _userProfile = UserProfile(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      email: signupData['email'],
      firstName: signupData['firstName'],
      lastName: signupData['lastName'],
      phoneNumber: signupData['phoneNumber'] ?? '',
      licenseNumber: signupData['licenseNumber'] ?? '',
      specialization: signupData['specialization'] ?? '',
      yearsOfExperience: signupData['yearsOfExperience'] ?? 0,
      practiceLocation: signupData['practiceLocation'] ?? '',
      country: signupData['country'] ?? '',
      countryName: signupData['countryName'] ?? '',
      province: signupData['province'] ?? '',
      city: signupData['city'] ?? '',
      address: signupData['address'] ?? '',
      postalCode: signupData['postalCode'] ?? '',
      accountStatus: _autoApprovePractitioners ? 'approved' : 'pending',
      role: 'practitioner',
      licenseVerified: _autoApprovePractitioners,
      professionalReferences: [],
      settings: UserSettings(
        notificationsEnabled: true,
        darkModeEnabled: false,
        biometricEnabled: false,
        language: 'en',
        timezone: 'UTC',
      ),
      createdAt: DateTime.now(),
      totalPatients: 0,
      totalSessions: 0,
    );

    debugPrint(
      'Mock ${_autoApprovePractitioners ? 'auto-approved' : 'pending'} practitioner: ${signupData['email']}',
    );
    notifyListeners();
    return true;
  }

  void _mockLogout() {
    _mockAuthenticated = false;
    _mockEmail = null;
    _mockUserName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    super.dispose();
  }
}
