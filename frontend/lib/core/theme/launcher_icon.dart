import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Syncs the Android home-screen icon with the in-app [ThemeMode].
class LauncherIcon {
  LauncherIcon._();

  static const _channel = MethodChannel('com.example.arka_payroll/launcher_icon');

  static Future<void> sync(ThemeMode mode) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final arg = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      await _channel.invokeMethod<void>('setLauncherIcon', {'mode': arg});
    } catch (_) {
      // Icon switch is best-effort (some launchers cache aggressively).
    }
  }
}
