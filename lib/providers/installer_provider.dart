import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin/installer.dart';
import '../services/firebase/installer_service.dart';

/// Provider to manage installer state for operations
class InstallerProvider extends ChangeNotifier {
  final InstallerService _service = InstallerService();
  StreamSubscription<List<Installer>>? _installersSubscription;

  List<Installer> _installers = [];
  List<Installer> _activeInstallers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Getters
  List<Installer> get installers => _filteredInstallers;
  List<Installer> get allInstallers => _installers;
  List<Installer> get activeInstallers => _activeInstallers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// Get filtered installers based on search
  List<Installer> get _filteredInstallers {
    if (_searchQuery.isEmpty) {
      return _installers;
    }

    final query = _searchQuery.toLowerCase();
    return _installers.where((installer) {
      return installer.fullName.toLowerCase().contains(query) ||
          installer.email.toLowerCase().contains(query) ||
          installer.serviceArea.toLowerCase().contains(query) ||
          installer.city.toLowerCase().contains(query);
    }).toList();
  }

  /// Start listening to installers
  Future<void> listenToInstallers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _installersSubscription?.cancel();
    _installersSubscription = _service.installersStream().listen(
      (installers) {
        _installers = installers;
        _activeInstallers =
            installers.where((i) => i.status == InstallerStatus.active).toList();
        _isLoading = false;
        _error = null;
        if (kDebugMode) {
          debugPrint('InstallerProvider: loaded ${installers.length} installers');
        }
        notifyListeners();
      },
      onError: (e, stack) {
        _isLoading = false;
        _error = 'Failed to load installers: $e';
        if (kDebugMode) {
          debugPrint('InstallerProvider error: $e');
          debugPrintStack(stackTrace: stack);
        }
        notifyListeners();
      },
    );
  }

  /// Load installers once (not streaming)
  Future<void> loadInstallers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _installers = await _service.getAllInstallers();
      _activeInstallers =
          _installers.where((i) => i.status == InstallerStatus.active).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load installers: $e';
      notifyListeners();
    }
  }

  /// Get installer by ID
  Installer? getInstallerById(String id) {
    try {
      return _installers.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Create a new installer
  Future<String> createInstaller(Installer installer) async {
    try {
      final id = await _service.createInstaller(installer);
      return id;
    } catch (e) {
      _error = 'Failed to create installer: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update an installer
  Future<void> updateInstaller(Installer installer) async {
    try {
      await _service.updateInstaller(installer);
    } catch (e) {
      _error = 'Failed to update installer: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete an installer
  Future<void> deleteInstaller(String installerId) async {
    try {
      await _service.deleteInstaller(installerId);
    } catch (e) {
      _error = 'Failed to delete installer: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update installer status
  Future<void> updateInstallerStatus(
    String installerId,
    InstallerStatus status,
  ) async {
    try {
      await _service.updateInstallerStatus(installerId, status);
    } catch (e) {
      _error = 'Failed to update installer status: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _installersSubscription?.cancel();
    super.dispose();
  }
}

