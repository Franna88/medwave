import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Feature flag for development - allows switching between mock and Firebase
  static const bool _useFirebase = true; // Firebase is now configured!
  
  // Feature flag for auto-approval during development/testing
  // Set to true for testing, false for production approval workflow
  static const bool _autoApprovePractitioners = true; // Enable for testing
  
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
  String? get userName => _userProfile?.fullName ?? (_useFirebase ? _user?.displayName : _mockUserName);
  
  // Helper getters for development
  bool get isAutoApprovalEnabled => _autoApprovePractitioners;
  bool get isUsingFirebase => _useFirebase;
  
  // Check if user can access the app (approved practitioner or super admin)
  bool get canAccessApp {
    if (!_useFirebase) return _mockAuthenticated;
    return _userProfile?.accountStatus == 'approved' || 
           _userProfile?.role == 'super_admin';
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
        await _loadUserProfile();
      } else {
        _userProfile = null;
      }
      _isLoading = false; // Auth state has been determined
      notifyListeners();
    });
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
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login time
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'lastActivityDate': FieldValue.serverTimestamp(),
        });
      }
      
      return true;
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
        // Create user profile in Firestore
        await _createUserProfile(credential.user!.uid, signupData);
        
        // Create practitioner application
        await _createPractitionerApplication(credential.user!.uid, signupData);
        
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
      await _auth.signOut();
      _userProfile = null;
      _setError(null);
    } catch (e) {
      _setError('Failed to sign out. Please try again.');
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
        debugPrint('User profile loaded: ${_userProfile?.accountStatus}, canAccessApp: $canAccessApp');
      } else {
        debugPrint('User profile document does not exist');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }
  
  Future<void> _createUserProfile(String userId, Map<String, dynamic> signupData) async {
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
      'approvalDate': _autoApprovePractitioners ? FieldValue.serverTimestamp() : null,
      'role': 'practitioner',
      'licenseVerified': _autoApprovePractitioners ? true : false,
      'professionalReferences': [],
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
  
  Future<void> _createPractitionerApplication(String userId, Map<String, dynamic> signupData) async {
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
      'approvedAt': _autoApprovePractitioners ? FieldValue.serverTimestamp() : null,
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
    
    debugPrint('Mock ${_autoApprovePractitioners ? 'auto-approved' : 'pending'} practitioner: ${signupData['email']}');
    notifyListeners();
    return true;
  }
  
  void _mockLogout() {
    _mockAuthenticated = false;
    _mockEmail = null;
    _mockUserName = null;
    notifyListeners();
  }
}
