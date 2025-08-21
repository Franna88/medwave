import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  Future<bool> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    // For demo purposes, accept any valid email/password
    if (email.isNotEmpty && password.isNotEmpty) {
      _isAuthenticated = true;
      _userEmail = email;
      _userName = email.split('@')[0]; // Use email prefix as username
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    notifyListeners();
  }

  Future<bool> signup(Map<String, dynamic> signupData) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    // For demo purposes, always succeed
    _isAuthenticated = true;
    _userEmail = signupData['email'];
    _userName = '${signupData['firstName']} ${signupData['lastName']}';
    notifyListeners();
    return true;
  }
}
