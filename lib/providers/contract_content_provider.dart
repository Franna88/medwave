import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin/contract_content.dart';
import '../services/firebase/contract_content_service.dart';

/// Provider for managing contract content state
class ContractContentProvider extends ChangeNotifier {
  final ContractContentService _service = ContractContentService();
  
  ContractContent? _contractContent;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  bool _hasUnsavedChanges = false;
  StreamSubscription<ContractContent>? _subscription;

  // Getters
  ContractContent? get contractContent => _contractContent;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get hasContent => _contractContent?.hasContent ?? false;

  /// Initialize and load contract content
  Future<void> initialize() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contractContent = await _service.getContractContent();
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractContentProvider: Initialized with version ${_contractContent?.version}');
      }
    } catch (e) {
      _error = 'Failed to load contract content: $e';
      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractContentProvider: Error initializing: $e');
      }
    }
  }

  /// Subscribe to real-time updates
  void subscribeToUpdates() {
    _subscription?.cancel();
    _subscription = _service.watchContractContent().listen(
      (content) {
        _contractContent = content;
        notifyListeners();

        if (kDebugMode) {
          print('✅ ContractContentProvider: Received update (version ${content.version})');
        }
      },
      onError: (error) {
        _error = 'Failed to watch contract content: $error';
        notifyListeners();

        if (kDebugMode) {
          print('❌ ContractContentProvider: Watch error: $error');
        }
      },
    );
  }

  /// Save contract content
  Future<bool> saveContractContent({
    required List<dynamic> content,
    required String plainText,
    required String modifiedBy,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _service.saveContractContent(
        content: content,
        plainText: plainText,
        modifiedBy: modifiedBy,
      );

      // Reload to get updated version
      _contractContent = await _service.getContractContent();
      _hasUnsavedChanges = false;
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractContentProvider: Saved successfully');
      }

      return true;
    } catch (e) {
      _error = 'Failed to save contract content: $e';
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractContentProvider: Error saving: $e');
      }

      return false;
    }
  }

  /// Mark that there are unsaved changes
  void markAsChanged() {
    if (!_hasUnsavedChanges) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  /// Clear unsaved changes flag
  void clearChanges() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  /// Delete contract content
  Future<bool> deleteContractContent() async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _service.deleteContractContent();
      _contractContent = ContractContent.empty();
      _hasUnsavedChanges = false;
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('✅ ContractContentProvider: Deleted successfully');
      }

      return true;
    } catch (e) {
      _error = 'Failed to delete contract content: $e';
      _isSaving = false;
      notifyListeners();

      if (kDebugMode) {
        print('❌ ContractContentProvider: Error deleting: $e');
      }

      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

