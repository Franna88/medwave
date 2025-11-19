import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for app-wide feature flags and settings
class AppFeatureSettings {
  final bool showFormsInNavbar;
  final bool showLeadsInNavbar;

  AppFeatureSettings({
    this.showFormsInNavbar = true,
    this.showLeadsInNavbar = true,
  });

  factory AppFeatureSettings.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return AppFeatureSettings();
    }
    
    final data = doc.data() as Map<String, dynamic>;
    return AppFeatureSettings.fromMap(data);
  }

  factory AppFeatureSettings.fromMap(Map<String, dynamic> map) {
    return AppFeatureSettings(
      showFormsInNavbar: map['showFormsInNavbar'] as bool? ?? true,
      showLeadsInNavbar: map['showLeadsInNavbar'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showFormsInNavbar': showFormsInNavbar,
      'showLeadsInNavbar': showLeadsInNavbar,
    };
  }

  AppFeatureSettings copyWith({
    bool? showFormsInNavbar,
    bool? showLeadsInNavbar,
  }) {
    return AppFeatureSettings(
      showFormsInNavbar: showFormsInNavbar ?? this.showFormsInNavbar,
      showLeadsInNavbar: showLeadsInNavbar ?? this.showLeadsInNavbar,
    );
  }
}

