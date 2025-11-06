import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? licenseNumber;
  final String specialization;
  final int yearsOfExperience;
  final String practiceLocation;
  final DateTime createdAt;
  final DateTime lastUpdated;
  
  // Bank account fields for manual payouts
  final String? bankName;
  final String? bankCode;
  final String? bankAccountNumber;
  final String? bankAccountName;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.licenseNumber,
    required this.specialization,
    required this.yearsOfExperience,
    required this.practiceLocation,
    required this.createdAt,
    required this.lastUpdated,
    this.bankName,
    this.bankCode,
    this.bankAccountNumber,
    this.bankAccountName,
  });

  String get fullName => '$firstName $lastName';
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    return 'U';
  }
  
  // Default platform commission percentage
  double get platformCommissionPercentage => 5.0;

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? licenseNumber,
    String? specialization,
    int? yearsOfExperience,
    String? practiceLocation,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? bankName,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      practiceLocation: practiceLocation ?? this.practiceLocation,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
    );
  }
}

class AppSettings {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final bool biometricEnabled;
  final String language;
  final String timezone;
  
  // Payment settings
  final bool sessionFeeEnabled;
  final double defaultSessionFee;
  final String currency;
  final String? paystackPublicKey;
  final String? paystackSecretKey;

  AppSettings({
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.biometricEnabled,
    required this.language,
    required this.timezone,
    this.sessionFeeEnabled = true,  // Enable by default for testing
    this.defaultSessionFee = 500.0,  // R500 default consultation fee
    this.currency = 'ZAR',
    this.paystackPublicKey,
    this.paystackSecretKey,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    bool? biometricEnabled,
    String? language,
    String? timezone,
    bool? sessionFeeEnabled,
    double? defaultSessionFee,
    String? currency,
    String? paystackPublicKey,
    String? paystackSecretKey,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      sessionFeeEnabled: sessionFeeEnabled ?? this.sessionFeeEnabled,
      defaultSessionFee: defaultSessionFee ?? this.defaultSessionFee,
      currency: currency ?? this.currency,
      paystackPublicKey: paystackPublicKey ?? this.paystackPublicKey,
      paystackSecretKey: paystackSecretKey ?? this.paystackSecretKey,
    );
  }
}

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  AppSettings _appSettings = AppSettings(
    notificationsEnabled: true,
    darkModeEnabled: false,
    biometricEnabled: false,
    language: 'English',
    timezone: 'Africa/Johannesburg',
  );

  UserProfile? get userProfile => _userProfile;
  AppSettings get appSettings => _appSettings;

  // Load profile from Firebase
  Future<void> loadProfileFromFirebase(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _userProfile = UserProfile(
          id: userId,
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          email: data['email'] ?? '',
          phoneNumber: data['phoneNumber'],
          licenseNumber: data['licenseNumber'],
          specialization: data['specialization'] ?? 'Practitioner',
          yearsOfExperience: data['yearsOfExperience'] ?? 0,
          practiceLocation: data['practiceLocation'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
          bankName: data['bankName'],
          bankCode: data['bankCode'],
          bankAccountNumber: data['bankAccountNumber'],
          bankAccountName: data['bankAccountName'],
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading profile from Firebase: $e');
    }
  }

  // Initialize with default data (fallback if no Firebase profile)
  void initializeProfile(String email, String userName) {
    final nameParts = userName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    _userProfile = UserProfile(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: '+27 82 123 4567',
      licenseNumber: 'HPCSA-123456',
      specialization: 'Wound Care Specialist',
      yearsOfExperience: 8,
      practiceLocation: 'Johannesburg, South Africa',
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  // Update user profile
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? licenseNumber,
    String? specialization,
    int? yearsOfExperience,
    String? practiceLocation,
    String? paystackSubaccountCode,
    bool? paystackSubaccountVerified,
    String? bankName,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
    DateTime? subaccountCreatedAt,
  }) async {
    if (_userProfile == null) return false;

    try {
      // Update local state first
      _userProfile = _userProfile!.copyWith(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        licenseNumber: licenseNumber,
        specialization: specialization,
        yearsOfExperience: yearsOfExperience,
        practiceLocation: practiceLocation,
        bankName: bankName,
        bankCode: bankCode,
        bankAccountNumber: bankAccountNumber,
        bankAccountName: bankAccountName,
        lastUpdated: DateTime.now(),
      );
      
      // Write to Firebase
      final updates = <String, dynamic>{};
      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      if (email != null) updates['email'] = email;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (licenseNumber != null) updates['licenseNumber'] = licenseNumber;
      if (specialization != null) updates['specialization'] = specialization;
      if (yearsOfExperience != null) updates['yearsOfExperience'] = yearsOfExperience;
      if (practiceLocation != null) updates['practiceLocation'] = practiceLocation;
      if (bankName != null) updates['bankName'] = bankName;
      if (bankCode != null) updates['bankCode'] = bankCode;
      if (bankAccountNumber != null) updates['bankAccountNumber'] = bankAccountNumber;
      if (bankAccountName != null) updates['bankAccountName'] = bankAccountName;
      if (subaccountCreatedAt != null) updates['subaccountCreatedAt'] = Timestamp.fromDate(subaccountCreatedAt);
      updates['lastUpdated'] = FieldValue.serverTimestamp();
      
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userProfile!.id)
          .update(updates);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Update app settings
  Future<bool> updateSettings({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    bool? biometricEnabled,
    String? language,
    String? timezone,
    bool? sessionFeeEnabled,
    double? defaultSessionFee,
    String? currency,
    String? paystackPublicKey,
    String? paystackSecretKey,
  }) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 300));
      
      _appSettings = _appSettings.copyWith(
        notificationsEnabled: notificationsEnabled,
        darkModeEnabled: darkModeEnabled,
        biometricEnabled: biometricEnabled,
        language: language,
        timezone: timezone,
        sessionFeeEnabled: sessionFeeEnabled,
        defaultSessionFee: defaultSessionFee,
        currency: currency,
        paystackPublicKey: paystackPublicKey,
        paystackSecretKey: paystackSecretKey,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Load profile from storage (in a real app, this would load from local storage or API)
  Future<void> loadProfile() async {
    // Simulate loading from storage
    await Future.delayed(const Duration(milliseconds: 200));
    
    // For demo purposes, create a default profile if none exists
    if (_userProfile == null) {
      _userProfile = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@medwave.com',
        phoneNumber: '+27 82 123 4567',
        licenseNumber: 'HPCSA-123456',
        specialization: 'Wound Care Specialist',
        yearsOfExperience: 8,
        practiceLocation: 'Johannesburg, South Africa',
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        lastUpdated: DateTime.now(),
      );
    }
    
    notifyListeners();
  }

  // Save profile to storage (in a real app, this would save to local storage or API)
  Future<bool> saveProfile() async {
    try {
      // Simulate saving to storage
      await Future.delayed(const Duration(milliseconds: 400));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear profile data (for logout)
  void clearProfile() {
    _userProfile = null;
    _appSettings = AppSettings(
      notificationsEnabled: true,
      darkModeEnabled: false,
      biometricEnabled: false,
      language: 'English',
      timezone: 'Africa/Johannesburg',
    );
    notifyListeners();
  }
}
