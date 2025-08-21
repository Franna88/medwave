import 'package:flutter/foundation.dart';

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
    );
  }
}

class AppSettings {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final bool biometricEnabled;
  final String language;
  final String timezone;

  AppSettings({
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.biometricEnabled,
    required this.language,
    required this.timezone,
  });

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    bool? biometricEnabled,
    String? language,
    String? timezone,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
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

  // Initialize with default data
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
  }) async {
    if (_userProfile == null) return false;

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      _userProfile = _userProfile!.copyWith(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        licenseNumber: licenseNumber,
        specialization: specialization,
        yearsOfExperience: yearsOfExperience,
        practiceLocation: practiceLocation,
        lastUpdated: DateTime.now(),
      );
      
      notifyListeners();
      return true;
    } catch (e) {
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
