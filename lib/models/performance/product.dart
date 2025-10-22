import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a product with deposit and expense costs
/// Used for calculating profitability in ad performance tracking
class Product {
  final String id;
  final String name;
  final double depositAmount;
  final double expenseCost;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  Product({
    required this.id,
    required this.name,
    required this.depositAmount,
    required this.expenseCost,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Create Product from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      expenseCost: (data['expenseCost'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  /// Create Product from JSON map
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      depositAmount: (json['depositAmount'] ?? 0).toDouble(),
      expenseCost: (json['expenseCost'] ?? 0).toDouble(),
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      createdBy: json['createdBy'],
    );
  }

  /// Convert Product to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'depositAmount': depositAmount,
      'expenseCost': expenseCost,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'depositAmount': depositAmount,
      'expenseCost': expenseCost,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Create a copy with updated fields
  Product copyWith({
    String? id,
    String? name,
    double? depositAmount,
    double? expenseCost,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      depositAmount: depositAmount ?? this.depositAmount,
      expenseCost: expenseCost ?? this.expenseCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, deposit: R$depositAmount, expense: R$expenseCost)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

