import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin/product_item.dart';

/// Firestore service for CRUD operations on `product_items`
class ProductItemService {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('product_items');

  Stream<List<ProductItem>> watchProductItems() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ProductItem.fromFirestore).toList(growable: false),
        );
  }

  Future<void> createProductItem({
    required String name,
    required String description,
    required String country,
    required bool isActive,
    required double price,
    double? costAmount,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _collection.add({
      'name': name,
      'description': description,
      'country': country,
      'isActive': isActive,
      'price': price,
      if (costAmount != null) 'costAmount': costAmount,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateProductItem(ProductItem item) async {
    await _collection.doc(item.id).update({
      'name': item.name,
      'description': item.description,
      'country': item.country,
      'isActive': item.isActive,
      'price': item.price,
      if (item.costAmount != null) 'costAmount': item.costAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProductItem(String id) async {
    await _collection.doc(id).delete();
  }
}
