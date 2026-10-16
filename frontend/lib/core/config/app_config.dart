import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'AIPS';
  static const String companyName = 'Arka Infotech Software Solutions';
  static const String companyAddress =
      'Office .no 512, Suchita Business Park, Patel chowk, opposite Hanuman temple, Shival Nagar, Saibaba Nagar, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400077';
  static const String appTagline = 'Payroll Portal';

  /// Light theme → `source_light.png` · Dark theme → `source_dark.png`
  static const String logoLight = 'assets/branding/source_light.png';
  static const String logoDark = 'assets/branding/source_dark.png';
  static const String appIcon = 'assets/branding/aips_icon.png';

  /// Override: `--dart-define=API_BASE_URL=http://192.168.0.153:3000/api/v1`
  static const String _apiFromEnv = String.fromEnvironment('API_BASE_URL');

  /// This Mac on the current Wi‑Fi (en1). Phone and computer must be on the same network.
  /// Update if DHCP assigns a new address (`ipconfig getifaddr en1`).
  static const String lanHost = '192.168.0.153';

  /// Phones cannot use localhost. Emulator can still reach this LAN address
  /// when the API listens on 0.0.0.0.
  static String get apiBaseUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return 'http://$lanHost:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }
}
