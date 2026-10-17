import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'aips_theme_mode';

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeKey);
    mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode next) async {
    if (mode == next) return;
    mode = next;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (next) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kThemeKey, value);
    notifyListeners();
  }

  void toggle() {
    setMode(mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
