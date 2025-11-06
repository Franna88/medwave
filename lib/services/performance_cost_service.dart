import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/performance/product.dart';
import '../models/performance/ad_performance_cost.dart';

/// Service for managing performance cost data in Firestore
class PerformanceCostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static const String _productsCollection = 'products';
  static const String _adPerformanceCostsCollection = 'adPerformanceCosts';

  // ========== PRODUCT OPERATIONS ==========

  /// Get all products
  static Future<List<Product>> getProducts() async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching all products...');
      }

      final snapshot = await _firestore
          .collection(_productsCollection)
          .orderBy('name')
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      if (kDebugMode) {
        print('✅ Fetched ${products.length} products');
      }

      return products;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching products: $e');
      }
      rethrow;
    }
  }

  /// Get a single product by ID
  static Future<Product?> getProduct(String productId) async {
    try {
      final doc = await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .get();

      if (!doc.exists) return null;

      return Product.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching product $productId: $e');
      }
      rethrow;
    }
  }

  /// Create a new product
  static Future<Product> createProduct(Product product) async {
    try {
      if (kDebugMode) {
        print('📝 Creating product: ${product.name}');
      }

      final docRef = await _firestore
          .collection(_productsCollection)
          .add(product.toFirestore());

      if (kDebugMode) {
        print('✅ Product created with ID: ${docRef.id}');
      }

      return product.copyWith(id: docRef.id);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating product: $e');
      }
      rethrow;
    }
  }

  /// Update an existing product
  static Future<void> updateProduct(Product product) async {
    try {
      if (kDebugMode) {
        print('📝 Updating product: ${product.id}');
      }

      final updatedProduct = product.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_productsCollection)
          .doc(product.id)
          .update(updatedProduct.toFirestore());

      if (kDebugMode) {
        print('✅ Product updated: ${product.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating product: $e');
      }
      rethrow;
    }
  }

  /// Delete a product
  static Future<void> deleteProduct(String productId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting product: $productId');
      }

      await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .delete();

      if (kDebugMode) {
        print('✅ Product deleted: $productId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting product: $e');
      }
      rethrow;
    }
  }

  /// Stream all products in real-time
  static Stream<List<Product>> streamProducts() {
    return _firestore
        .collection(_productsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList());
  }

  // ========== AD PERFORMANCE COST OPERATIONS ==========

  /// Get all ad performance costs
  static Future<List<AdPerformanceCost>> getAdPerformanceCosts() async {
    try {
      if (kDebugMode) {
        print('🔍 Fetching all ad performance costs...');
      }

      final snapshot = await _firestore
          .collection(_adPerformanceCostsCollection)
          .orderBy('campaignName')
          .get();

      final costs = snapshot.docs
          .map((doc) => AdPerformanceCost.fromFirestore(doc))
          .toList();

      if (kDebugMode) {
        print('✅ Fetched ${costs.length} ad performance costs');
      }

      return costs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance costs: $e');
      }
      rethrow;
    }
  }

  /// Get a single ad performance cost by ID
  static Future<AdPerformanceCost?> getAdPerformanceCost(String costId) async {
    try {
      final doc = await _firestore
          .collection(_adPerformanceCostsCollection)
          .doc(costId)
          .get();

      if (!doc.exists) return null;

      return AdPerformanceCost.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance cost $costId: $e');
      }
      rethrow;
    }
  }

  /// Create a new ad performance cost
  static Future<AdPerformanceCost> createAdPerformanceCost(AdPerformanceCost cost) async {
    try {
      if (kDebugMode) {
        print('📝 Creating ad performance cost: ${cost.adName}');
      }

      final docRef = await _firestore
          .collection(_adPerformanceCostsCollection)
          .add(cost.toFirestore());

      if (kDebugMode) {
        print('✅ Ad performance cost created with ID: ${docRef.id}');
      }

      return cost.copyWith(id: docRef.id);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating ad performance cost: $e');
      }
      rethrow;
    }
  }

  /// Update an existing ad performance cost
  static Future<void> updateAdPerformanceCost(AdPerformanceCost cost) async {
    try {
      if (kDebugMode) {
        print('📝 Updating ad performance cost: ${cost.id}');
      }

      final updatedCost = cost.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_adPerformanceCostsCollection)
          .doc(cost.id)
          .update(updatedCost.toFirestore());

      if (kDebugMode) {
        print('✅ Ad performance cost updated: ${cost.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating ad performance cost: $e');
      }
      rethrow;
    }
  }

  /// Delete an ad performance cost
  static Future<void> deleteAdPerformanceCost(String costId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting ad performance cost: $costId');
      }

      await _firestore
          .collection(_adPerformanceCostsCollection)
          .doc(costId)
          .delete();

      if (kDebugMode) {
        print('✅ Ad performance cost deleted: $costId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting ad performance cost: $e');
      }
      rethrow;
    }
  }

  /// Stream all ad performance costs in real-time
  static Stream<List<AdPerformanceCost>> streamAdPerformanceCosts() {
    return _firestore
        .collection(_adPerformanceCostsCollection)
        .orderBy('campaignName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdPerformanceCost.fromFirestore(doc))
            .toList());
  }

  /// Get ad performance costs for a specific campaign
  static Future<List<AdPerformanceCost>> getAdPerformanceCostsByCampaign(String campaignName) async {
    try {
      final snapshot = await _firestore
          .collection(_adPerformanceCostsCollection)
          .where('campaignName', isEqualTo: campaignName)
          .get();

      return snapshot.docs
          .map((doc) => AdPerformanceCost.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching ad performance costs for campaign $campaignName: $e');
      }
      rethrow;
    }
  }

  // ========== MERGE OPERATIONS ==========

  /// Merge ad performance costs with cumulative campaign data
  static Future<List<AdPerformanceCostWithMetrics>> getMergedPerformanceData({
    required List<AdPerformanceCost> adCosts,
    required List<dynamic> cumulativeCampaigns,
    required List<Product> products,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Merging ${adCosts.length} ad costs with ${cumulativeCampaigns.length} campaigns');
      }

      final List<AdPerformanceCostWithMetrics> mergedData = [];

      // Create a map of products for quick lookup
      final productMap = {for (var p in products) p.id: p};

      // Process each ad cost entry
      for (final adCost in adCosts) {
        // Find matching campaign and ad data from cumulative data
        Map<String, dynamic>? matchingAd;
        
        for (final campaign in cumulativeCampaigns) {
          final campaignName = campaign['campaignName'] ?? '';
          
          // Check if campaign name matches
          if (campaignName == adCost.campaignName) {
            final adsList = campaign['adsList'] as List<dynamic>? ?? [];
            
            // Find matching ad by adId
            for (final ad in adsList) {
              final adId = ad['adId'] ?? '';
              if (adId == adCost.adId) {
                matchingAd = ad as Map<String, dynamic>;
                break;
              }
            }
          }
          
          if (matchingAd != null) break;
        }

        // Extract metrics from matching ad or use zeros
        final int leads = matchingAd?['totalOpportunities'] ?? 0;
        final int bookings = matchingAd?['bookedAppointments'] ?? 0;
        final int deposits = matchingAd?['deposits'] ?? 0;
        final double cashAmount = (matchingAd?['totalMonetaryValue'] ?? 0).toDouble();
        
        if (kDebugMode) {
          print('📊 Ad: ${adCost.adName} | Leads: $leads | Bookings: $bookings | Deposits: $deposits | Cash: R$cashAmount | FB Spend: R${adCost.facebookSpend?.toStringAsFixed(2) ?? "null"} | Budget: R${adCost.budget}');
        }

        // Get linked product if exists
        Product? linkedProduct;
        if (adCost.linkedProductId != null) {
          linkedProduct = productMap[adCost.linkedProductId];
        }

        // Create merged data entry
        final mergedEntry = AdPerformanceCostWithMetrics(
          cost: adCost,
          leads: leads,
          bookings: bookings,
          deposits: deposits,
          cashDepositAmount: cashAmount,
          linkedProduct: linkedProduct,
        );
        
        if (kDebugMode) {
          print('   ➜ CPL: R${mergedEntry.cpl.toStringAsFixed(2)} | CPB: R${mergedEntry.cpb.toStringAsFixed(2)} | CPA: R${mergedEntry.cpa.toStringAsFixed(2)} | Profit: R${mergedEntry.actualProfit.toStringAsFixed(2)}');
        }
        
        mergedData.add(mergedEntry);
      }

      if (kDebugMode) {
        print('✅ Merged ${mergedData.length} ad performance entries');
      }

      return mergedData;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error merging performance data: $e');
      }
      rethrow;
    }
  }
}

