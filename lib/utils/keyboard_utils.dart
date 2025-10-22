import 'package:flutter/material.dart';

/// Utility class for keyboard management
class KeyboardUtils {
  /// Dismisses the keyboard by removing focus from any currently focused text field
  /// This is a clean, single-method approach that works reliably across platforms
  static void dismissKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }
  
  /// Creates a GestureDetector that dismisses the keyboard when tapped
  /// Note: Does NOT use onPanDown to avoid conflicts with scrolling gestures
  static Widget dismissibleWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => dismissKeyboard(context),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
  
  /// Wraps a scrollable widget with keyboard dismissal on scroll
  /// Use this for SingleChildScrollView, ListView, etc.
  /// Only dismisses on user-initiated scroll, not programmatic scroll (like auto-scroll to focused field)
  static Widget dismissOnScroll({
    required BuildContext context,
    required Widget child,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only dismiss on user-initiated scroll with actual movement
        // UserScrollNotification fires when user touches and drags, not on programmatic scroll
        if (notification is UserScrollNotification) {
          dismissKeyboard(context);
        }
        return false;
      },
      child: child,
    );
  }
}
