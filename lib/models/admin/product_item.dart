import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for product management items stored in `product_items`
class ProductItem {
  final String id;
  final String name;
  final String description;
  final String country;
  final bool isActive;
  final double price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductItem({
    required this.id,
    required this.name,
    required this.description,
    required this.country,
    required this.isActive,
    required this.price,
    this.createdAt,
    this.updatedAt,
  });

  ProductItem copyWith({
    String? id,
    String? name,
    String? description,
    String? country,
    bool? isActive,
    double? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      country: country ?? this.country,
      isActive: isActive ?? this.isActive,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ProductItem(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      country: (data['country'] ?? '').toString(),
      isActive: data['isActive'] == true,
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
