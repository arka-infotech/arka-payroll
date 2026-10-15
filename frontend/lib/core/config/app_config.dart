class AppConfig {
  static const String appName = 'Arka Payroll';
  static const String companyName = 'Arka Infotech Software Solutions LLP';

  /// Override at run time:
  /// `flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
}
