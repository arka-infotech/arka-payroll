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
  /// Payslip PDF header + footer mark (cyan C on black).
  static const String payslipLogo = 'assets/branding/payslip-logo.png';

  /// Production API (nginx → PM2 on port 3055).
  static const String productionApiBaseUrl =
      'https://72.60.220.10/arka-payroll/api/v1';

  /// Optional override, e.g. local API:
  /// `--dart-define=API_BASE_URL=http://192.168.0.154:3000/api/v1`
  static const String _apiFromEnv = String.fromEnvironment('API_BASE_URL');

  /// Default target is production. Override with `--dart-define=API_BASE_URL=...`
  /// when developing against a local backend.
  static String get apiBaseUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    return productionApiBaseUrl;
  }
}
