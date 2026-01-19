import 'package:flutter/material.dart';
import '../models/installation/installation_signoff.dart';
import '../models/streams/order.dart' as models;
import '../services/firebase/installation_signoff_service.dart';

/// Provider for managing installation sign-off state
class InstallationSignoffProvider extends ChangeNotifier {
  final InstallationSignoffService _signoffService = InstallationSignoffService();

  InstallationSignoff? _currentSignoff;
  bool _isLoading = false;
  String? _error;

  InstallationSignoff? get currentSignoff => _currentSignoff;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load sign-off by ID and token (public access)
  Future<InstallationSignoff?> loadSignoffByIdAndToken(
    String signoffId,
    String? token,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSignoff = await _signoffService.getSignoffByIdAndToken(
        signoffId,
        token,
      );

      if (_currentSignoff == null) {
        _error = 'Invalid or expired link. Please contact support.';
      }

      _isLoading = false;
      notifyListeners();
      return _currentSignoff;
    } catch (e) {
      _error = 'Failed to load sign-off: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Mark sign-off as viewed
  Future<void> markSignoffAsViewed(String signoffId) async {
    try {
      await _signoffService.markAsViewed(signoffId);
      
      // Update current sign-off if it's the same one
      if (_currentSignoff?.id == signoffId) {
        _currentSignoff = _currentSignoff?.copyWith(
          status: SignoffStatus.viewed,
          viewedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      // Don't show error to user, just log it
      debugPrint('Error marking sign-off as viewed: $e');
    }
  }

  /// Sign a sign-off
  Future<bool> signSignoff({
    required String signoffId,
    required String digitalSignature,
    required Map<String, bool> itemsConfirmed,
    String? ipAddress,
    String? userAgent,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _signoffService.signSignoff(
        signoffId: signoffId,
        digitalSignature: digitalSignature,
        itemsConfirmed: itemsConfirmed,
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      // Update current sign-off
      if (_currentSignoff?.id == signoffId) {
        _currentSignoff = _currentSignoff?.copyWith(
          status: SignoffStatus.signed,
          hasSigned: true,
          digitalSignature: digitalSignature,
          signedAt: DateTime.now(),
          ipAddress: ipAddress,
          userAgent: userAgent,
          itemsConfirmed: itemsConfirmed,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to sign: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Generate sign-off for an order (admin function)
  Future<InstallationSignoff?> generateSignoffForOrder({
    required models.Order order,
    required String createdBy,
    required String createdByName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final signoff = await _signoffService.createSignoff(
        order: order,
        createdBy: createdBy,
        createdByName: createdByName,
      );

      _isLoading = false;
      notifyListeners();
      return signoff;
    } catch (e) {
      _error = 'Failed to generate sign-off: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load sign-offs by order ID (admin function)
  Future<List<InstallationSignoff>> loadSignoffsByOrderId(
    String orderId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final signoffs = await _signoffService.getSignoffsByOrderId(orderId);
      _isLoading = false;
      notifyListeners();
      return signoffs;
    } catch (e) {
      _error = 'Failed to load sign-offs: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get full sign-off URL
  String getFullSignoffUrl(InstallationSignoff signoff) {
    return _signoffService.getFullSignoffUrl(signoff);
  }

  /// Clear current sign-off
  void clearCurrentSignoff() {
    _currentSignoff = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
