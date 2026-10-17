import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Production nginx currently serves a self-signed cert for this IP.
/// Android/iOS reject it → HandshakeException on login. Allow only this host.
/// When you move the API to a real domain with Let's Encrypt, remove this set.
const _allowSelfSignedHosts = {
  '72.60.220.10',
};

/// Shared HTTP client used by [ApiClient].
http.Client createApiHttpClient() {
  if (kIsWeb) {
    return http.Client();
  }
  final io = HttpClient();
  io.badCertificateCallback = (X509Certificate cert, String host, int port) {
    return _allowSelfSignedHosts.contains(host);
  };
  return IOClient(io);
}
