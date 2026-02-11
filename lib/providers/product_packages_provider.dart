import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin/product_package.dart';
import '../services/firebase/product_package_service.dart';

/// Provider to manage product_packages collection state
class ProductPackagesProvider extends ChangeNotifier {
  final ProductPackageService _service = ProductPackageService();
  StreamSubscription<List<ProductPackage>>? _subscription;

  List<ProductPackage> _packages = [];
  bool _isLoading = false;
  String? _error;

  List<ProductPackage> get packages => _packages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Start listening to product packages collection
  Future<void> listenToPackages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = _service.watchProductPackages().listen(
      (packages) {
        _packages = packages;
        _isLoading = false;
        _error = null;
        if (kDebugMode) {
          debugPrint('ProductPackagesProvider: loaded ${packages.length} packages');
        }
        notifyListeners();
      },
      onError: (e, stack) {
        _isLoading = false;
        _error = 'Failed to load packages: $e';
        if (kDebugMode) {
          debugPrint('ProductPackagesProvider error: $e');
          debugPrintStack(stackTrace: stack);
        }
        notifyListeners();
      },
    );
  }

  Future<void> addProductPackage({
    required String name,
    required String description,
    required String country,
    required bool isActive,
    required double price,
    required List<PackageItemEntry> packageItems,
  }) {
    return _service.createProductPackage(
      name: name,
      description: description,
      country: country,
      isActive: isActive,
      price: price,
      packageItems: packageItems,
    );
  }

  Future<void> updateProductPackage(ProductPackage package) {
    return _service.updateProductPackage(package);
  }

  Future<void> deleteProductPackage(String id) {
    return _service.deleteProductPackage(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
