import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode get themeMode => ThemeMode.light;
  bool get isDarkMode => false;

  ThemeProvider();

  Future<void> setThemeMode(ThemeMode mode) async {}
  void toggleTheme() {}
}
