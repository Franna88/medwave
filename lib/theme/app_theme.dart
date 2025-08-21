import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // MedWave Brand Colors
  static const Color primaryColor = Color(0xFF162694); // Main blue color
  static const Color redColor = Color(0xFFF83D3D); // Red accent
  static const Color greenColor = Color(0xFF5CA301); // Green accent
  static const Color pinkColor = Color(0xFFF4448E); // Pink accent
  static const Color backgroundColor = Color(0xFFFFFFFF); // Background color
  static const Color textColor = Color(0xFF1A1A1A); // Text color
  static const Color secondaryColor = Color(0xFF353535); // Secondary color
  
  // Additional colors for UI
  static const Color cardColor = Color(0xFFF8F8F8);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color successColor = greenColor; // Using brand green
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = redColor; // Using brand red
  static const Color infoColor = primaryColor; // Using brand blue
  
  // Tablet/Desktop specific colors
  static const Color sidebarColor = Color(0xFFFAFAFA);
  static const Color sidebarBorderColor = Color(0xFFF0F0F0);
  static const Color desktopBackgroundColor = Color(0xFFF5F5F5);
  static const Color shadowColor = Color(0x0A000000);
  
  // Header section colors for better visual separation
  static const Color headerBackgroundColor = Color(0xFF1E40AF); // Darker blue
  static const Color headerAccentColor = Color(0xFF1D4ED8); // Rich blue accent
  static const Color headerGradientStart = Color(0xFF162694); // Primary color (darker)
  static const Color headerGradientEnd = Color(0xFF1E40AF); // Slightly lighter dark blue

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        background: backgroundColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onBackground: textColor,
        onSurface: textColor,
        secondary: secondaryColor,
        onSecondary: Colors.white,
      ),
      
      // Typography using Poppins font
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: GoogleFonts.poppins(color: secondaryColor),
        hintStyle: GoogleFonts.poppins(color: secondaryColor.withOpacity(0.6)),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryColor.withOpacity(0.6),
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
