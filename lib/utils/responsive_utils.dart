import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ResponsiveUtils {
  // Breakpoints for different screen sizes
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1200;
  static const double desktopMinWidth = 1200;

  // Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  // Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width < desktopMinWidth;
  }

  // Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMinWidth;
  }

  // Check if should use horizontal tablet layout
  static bool shouldUseHorizontalLayout(BuildContext context) {
    return isTablet(context) || isDesktop(context);
  }

  // Get appropriate padding for current screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  // Get appropriate content width for current screen
  static double getContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth;
    } else if (isTablet(context)) {
      return screenWidth * 0.85; // Leave some margin
    } else {
      return 1200; // Max content width for desktop
    }
  }

  // Get grid column count based on screen size
  static int getGridColumnCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }

  // Get sidebar width for tablet/desktop (minimal icon-only sidebar)
  static double getSidebarWidth(BuildContext context) {
    if (isTablet(context)) {
      return 80;
    } else {
      return 90;
    }
  }

  // Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Get appropriate font size scaling
  static double getFontScale(BuildContext context) {
    if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }

  // Platform detection methods
  static bool isWeb() {
    return kIsWeb;
  }

  static bool isMobileDevice(BuildContext context) {
    if (!kIsWeb) return true; // Native mobile app
    
    // On web, check if accessing from mobile browser
    final userAgent = _getUserAgent();
    return _isMobileUserAgent(userAgent) || MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  static bool shouldRestrictSessions() {
    return kIsWeb; // Restrict sessions on web platform
  }

  static bool shouldShowMobileWarning(BuildContext context) {
    if (!kIsWeb) return false;
    
    // Show warning if accessing web from mobile device
    final userAgent = _getUserAgent();
    return _isMobileUserAgent(userAgent);
  }

  // Helper methods for user agent detection
  static String _getUserAgent() {
    // This will need to be implemented with a web-specific approach
    if (kIsWeb) {
      // For now, return empty string - we'll detect mobile primarily by screen size
      return '';
    }
    return '';
  }

  static bool _isMobileUserAgent(String userAgent) {
    final mobilePatterns = [
      'android', 'iphone', 'ipad', 'ipod', 'windows phone', 'mobile'
    ];
    return mobilePatterns.any((pattern) => 
      userAgent.toLowerCase().contains(pattern));
  }
}
