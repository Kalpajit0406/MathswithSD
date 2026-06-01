import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';


class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0051D5),
        primary: const Color(0xFF0051D5),
        secondary: const Color(0xFF0F172A),
        surface: const Color(0xFFF7F9FB),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        displayMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        bodyLarge: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF75859D)),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFECEEF0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFECEEF0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0051D5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0051D5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFECEEF0), width: 1),
        ),
        elevation: 0,
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0051D5),
        primary: const Color(0xFF5D9BFF),
        secondary: const Color(0xFFDAE2FD),
        surface: const Color(0xFF080C14),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF020205),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDAE2FD)),
        displayMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDAE2FD)),
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDAE2FD)),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDAE2FD)),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDAE2FD)),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDAE2FD)),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDAE2FD)),
        bodyLarge: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFDAE2FD)),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF5D9BFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFF080C14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D9BFF),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        elevation: 0,
        color: const Color(0xFF080C14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF020205),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
}
