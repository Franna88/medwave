import 'package:cloud_firestore/cloud_firestore.dart';

/// One item in a package with its quantity.
class PackageItemEntry {
  final String productId;
  final int quantity;

  const PackageItemEntry({required this.productId, required this.quantity});

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'quantity': quantity,
  };

  factory PackageItemEntry.fromMap(Map<String, dynamic> map) {
    return PackageItemEntry(
      productId: (map['productId'] ?? '').toString(),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toInt() : 1,
    );
  }
}

/// Data model for product packages stored in `product_packages`.
/// A package is sold as one unit at a single price and contains a selection of product items with quantities.
class ProductPackage {
  final String id;
  final String name;
  final String description;
  final String country;
  final bool isActive;
  final double price;
  final List<PackageItemEntry> packageItems;
  /// Optional labels for "added services" shown below package items on invoice (e.g. "1 x Professional Installation").
  final List<String>? includedServiceLabels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.country,
    required this.isActive,
    required this.price,
    required this.packageItems,
    this.includedServiceLabels,
    this.createdAt,
    this.updatedAt,
  });

  /// Product IDs (for backward compatibility and display).
  List<String> get productIds => packageItems.map((e) => e.productId).toList();

  /// Total number of units across all items in the package.
  int get totalQuantity => packageItems.fold(0, (sum, e) => sum + e.quantity);

  ProductPackage copyWith({
    String? id,
    String? name,
    String? description,
    String? country,
    bool? isActive,
    double? price,
    List<PackageItemEntry>? packageItems,
    List<String>? includedServiceLabels,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      country: country ?? this.country,
      isActive: isActive ?? this.isActive,
      price: price ?? this.price,
      packageItems: packageItems ?? this.packageItems,
      includedServiceLabels: includedServiceLabels ?? this.includedServiceLabels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductPackage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    List<PackageItemEntry> packageItems = [];
    final packageItemsRaw = data['packageItems'];
    if (packageItemsRaw is List && packageItemsRaw.isNotEmpty) {
      packageItems = packageItemsRaw
          .map(
            (e) =>
                PackageItemEntry.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .where((e) => e.productId.isNotEmpty)
          .toList();
    } else {
      // Backward compat: old docs had productIds only (quantity 1 each)
      final productIdsRaw = data['productIds'];
      if (productIdsRaw is List) {
        packageItems = productIdsRaw
            .map((e) => e?.toString())
            .where((s) => s != null && s.isNotEmpty)
            .map((id) => PackageItemEntry(productId: id!, quantity: 1))
            .toList();
      }
    }
    List<String>? includedServiceLabels;
    final raw = data['includedServiceLabels'];
    if (raw is List) {
      includedServiceLabels = raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return ProductPackage(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      country: (data['country'] ?? '').toString(),
      isActive: data['isActive'] == true,
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      packageItems: packageItems,
      includedServiceLabels: includedServiceLabels,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'country': country,
      'isActive': isActive,
      'price': price,
      'packageItems': packageItems.map((e) => e.toMap()).toList(),
      'includedServiceLabels': includedServiceLabels,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
