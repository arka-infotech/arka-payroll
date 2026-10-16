import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/network/api_client.dart';

/// Parses NestJS / validation error payloads into a single readable string.
String apiErrorMessage(Object error) {
  if (error is ApiException) {
    return _flattenMessage(error.message);
  }
  if (error is http.ClientException) {
    return 'Cannot reach the payroll server at ${AppConfig.apiBaseUrl}. '
        'Keep the phone and computer on the same Wi-Fi, with the API running.';
  }
  if (error is TimeoutException) {
    return 'The server took too long to respond. Please try again.';
  }
  return error.toString();
}

enum FailureKind {
  offline,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  server,
  unknown,
}

/// A user-facing description of an error: short title + helpful message.
class Failure {
  const Failure(this.kind, this.title, this.message);

  final FailureKind kind;
  final String title;
  final String message;

  bool get isRetryable =>
      kind == FailureKind.offline ||
      kind == FailureKind.server ||
      kind == FailureKind.unknown;
}

Failure describeError(Object error) {
  if (error is http.ClientException || error is TimeoutException) {
    return Failure(
      FailureKind.offline,
      'Can’t reach the server',
      apiErrorMessage(error),
    );
  }
  if (error is ApiException) {
    final msg = _flattenMessage(error.message);
    switch (error.statusCode) {
      case 400:
      case 422:
        return Failure(FailureKind.validation, 'Please check the details', msg);
      case 401:
        return const Failure(
          FailureKind.unauthorized,
          'Session expired',
          'Please sign in again to continue.',
        );
      case 403:
        return Failure(
          FailureKind.forbidden,
          'You don’t have access',
          msg.isEmpty ? 'Ask an admin to grant you access.' : msg,
        );
      case 404:
        return Failure(FailureKind.notFound, 'Not found', msg);
      case 409:
        return Failure(FailureKind.conflict, 'Already exists', msg);
      default:
        if (error.statusCode >= 500) {
          return const Failure(
            FailureKind.server,
            'Server hiccup',
            'Something went wrong on our side. Please try again in a moment.',
          );
        }
        return Failure(FailureKind.unknown, 'Something went wrong', msg);
    }
  }
  return Failure(
    FailureKind.unknown,
    'Something went wrong',
    apiErrorMessage(error),
  );
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
