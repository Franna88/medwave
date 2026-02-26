import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin/product_package.dart';

/// Firestore service for CRUD operations on `product_packages`
class ProductPackageService {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('product_packages');

  /// Fetches a single package by id. Returns null if not found or deleted.
  Future<ProductPackage?> getProductPackage(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ProductPackage.fromFirestore(doc);
  }

  Stream<List<ProductPackage>> watchProductPackages() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProductPackage.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> createProductPackage({
    required String name,
    required String description,
    required String country,
    required bool isActive,
    required double price,
    required List<PackageItemEntry> packageItems,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _collection.add({
      'name': name,
      'description': description,
      'country': country,
      'isActive': isActive,
      'price': price,
      'packageItems': packageItems.map((e) => e.toMap()).toList(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateProductPackage(ProductPackage package) async {
    await _collection.doc(package.id).update({
      'name': package.name,
      'description': package.description,
      'country': package.country,
      'isActive': package.isActive,
      'price': package.price,
      'packageItems': package.packageItems.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProductPackage(String id) async {
    await _collection.doc(id).delete();
  }
}
