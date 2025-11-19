import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/app_settings.dart';

/// Service for managing app-wide feature flags and settings
class AppSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _settingsDocId = 'feature_flags';

  /// Get app feature settings
  Future<AppFeatureSettings> getFeatureSettings() async {
    try {
      final doc = await _firestore
          .collection('app_settings')
          .doc(_settingsDocId)
          .get();

      return AppFeatureSettings.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting feature settings: $e');
      }
      // Return defaults on error
      return AppFeatureSettings();
    }
  }

  /// Stream of feature settings for real-time updates
  Stream<AppFeatureSettings> watchFeatureSettings() {
    return _firestore
        .collection('app_settings')
        .doc(_settingsDocId)
        .snapshots()
        .map((doc) => AppFeatureSettings.fromFirestore(doc));
  }

  /// Update feature settings (admin only)
  Future<void> updateFeatureSettings(AppFeatureSettings settings) async {
    try {
      await _firestore
          .collection('app_settings')
          .doc(_settingsDocId)
          .set(settings.toMap(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('Error updating feature settings: $e');
      }
      rethrow;
    }
  }

  /// Initialize default settings if they don't exist
  Future<void> initializeDefaultSettings() async {
    try {
      final doc = await _firestore
          .collection('app_settings')
          .doc(_settingsDocId)
          .get();

      if (!doc.exists) {
        await _firestore
            .collection('app_settings')
            .doc(_settingsDocId)
            .set(AppFeatureSettings().toMap());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing default settings: $e');
      }
    }
  }
}

