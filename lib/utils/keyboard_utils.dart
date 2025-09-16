import 'package:flutter/material.dart';

/// Utility class for keyboard management
class KeyboardUtils {
  /// Dismisses the keyboard by removing focus from any currently focused text field
  static void dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
  
  /// Creates a GestureDetector that dismisses the keyboard when tapped
  static Widget dismissibleWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => dismissKeyboard(context),
      child: child,
    );
  }
}
