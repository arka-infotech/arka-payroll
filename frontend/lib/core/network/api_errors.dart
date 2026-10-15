import 'package:arka_payroll/core/network/api_client.dart';

/// Parses NestJS / validation error payloads into a single readable string.
String apiErrorMessage(Object error) {
  if (error is ApiException) {
    return _flattenMessage(error.message);
  }
  return error.toString();
}

String _flattenMessage(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    try {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return inner
          .split(',')
          .map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
          .where((s) => s.isNotEmpty)
          .join('\n');
    } catch (_) {
      return trimmed;
    }
  }
  return trimmed;
}
