import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin/product_item.dart';
import '../services/firebase/product_item_service.dart';

/// Provider to manage product_items collection state
class ProductItemsProvider extends ChangeNotifier {
  final ProductItemService _service = ProductItemService();
  StreamSubscription<List<ProductItem>>? _subscription;

  List<ProductItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<ProductItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Start listening to product items collection
  Future<void> listenToProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = _service.watchProductItems().listen(
      (items) {
        _items = items;
        _isLoading = false;
        _error = null;
        if (kDebugMode) {
          debugPrint('ProductItemsProvider: loaded ${items.length} items');
        }
        notifyListeners();
      },
      onError: (e, stack) {
        _isLoading = false;
        _error = 'Failed to load products: $e';
        if (kDebugMode) {
          debugPrint('ProductItemsProvider error: $e');
          debugPrintStack(stackTrace: stack);
        }
        notifyListeners();
      },
    );
  }

  Future<void> addProductItem({
    required String name,
    required String description,
    required String country,
    required bool isActive,
    required double price,
    double? costAmount,
  }) {
    return _service.createProductItem(
      name: name,
      description: description,
      country: country,
      isActive: isActive,
      price: price,
      costAmount: costAmount,
    );
  }

  Future<void> updateProductItem(ProductItem item) {
    return _service.updateProductItem(item);
  }

  Future<void> deleteProductItem(String id) {
    return _service.deleteProductItem(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
