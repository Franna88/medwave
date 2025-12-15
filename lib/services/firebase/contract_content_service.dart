import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/admin/contract_content.dart';

/// Service for managing contract content in Firebase
class ContractContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'app_settings';
  static const String _documentId = 'contract_content';

  /// Get contract content
  Future<ContractContent> getContractContent() async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .get();

      if (!doc.exists) {
        return ContractContent.empty();
      }

      return ContractContent.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractContentService: Error getting contract content: $e');
      }
      return ContractContent.empty();
    }
  }

  /// Stream of contract content for real-time updates
  Stream<ContractContent> watchContractContent() {
    return _firestore
        .collection(_collectionPath)
        .doc(_documentId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return ContractContent.empty();
          }
          return ContractContent.fromFirestore(doc);
        });
  }

  /// Save contract content
  Future<void> saveContractContent({
    required List<dynamic> content,
    required String plainText,
    required String modifiedBy,
  }) async {
    try {
      // Get current version
      final currentDoc = await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .get();
      
      int currentVersion = 0;
      if (currentDoc.exists) {
        final data = currentDoc.data();
        currentVersion = data?['version'] as int? ?? 0;
      }

      final contractContent = ContractContent(
        id: _documentId,
        content: content,
        plainText: plainText,
        lastModified: DateTime.now(),
        modifiedBy: modifiedBy,
        version: currentVersion + 1,
      );

      await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .set(contractContent.toMap(), SetOptions(merge: false));

      if (kDebugMode) {
        print('✅ ContractContentService: Contract content saved (version ${contractContent.version})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractContentService: Error saving contract content: $e');
      }
      rethrow;
    }
  }

  /// Delete contract content (reset to empty)
  Future<void> deleteContractContent() async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .delete();

      if (kDebugMode) {
        print('✅ ContractContentService: Contract content deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractContentService: Error deleting contract content: $e');
      }
      rethrow;
    }
  }

  /// Check if contract content exists
  Future<bool> hasContractContent() async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(_documentId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data();
      final content = data?['content'] as List<dynamic>?;
      
      return content != null && content.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ContractContentService: Error checking contract content: $e');
      }
      return false;
    }
  }
}

