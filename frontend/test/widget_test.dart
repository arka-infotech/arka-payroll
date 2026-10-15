import 'package:flutter_test/flutter_test.dart';
import 'package:arka_payroll/core/config/app_config.dart';

void main() {
  test('app config exposes company branding', () {
    expect(AppConfig.companyName, contains('Arka'));
    expect(AppConfig.apiBaseUrl, contains('api'));
  });
}
