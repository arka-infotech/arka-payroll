import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/network/api_http.dart';

class AppUpdateInfo {
  AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.forceUpdate,
    required this.notes,
    required this.downloadUrl,
    required this.apkAvailable,
    required this.currentVersionCode,
    required this.currentVersionName,
  });

  final int versionCode;
  final String versionName;
  final bool forceUpdate;
  final String notes;
  final String downloadUrl;
  final bool apkAvailable;
  final int currentVersionCode;
  final String currentVersionName;

  bool get updateAvailable =>
      apkAvailable && versionCode > currentVersionCode;
}

/// Reads `/updates/mobile/latest.json` and installs via Android’s system installer.
class AppUpdateService {
  AppUpdateService({http.Client? client})
      : _http = client ?? createApiHttpClient();

  final http.Client _http;

  Uri get _latestJsonUri =>
      Uri.parse('${AppConfig.mobileUpdatesBaseUrl}latest.json');

  Uri _apkUri(String apkField) {
    final trimmed = apkField.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    final base = AppConfig.mobileUpdatesBaseUrl;
    final file = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$base$file');
  }

  Future<AppUpdateInfo?> check() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      final res = await _http
          .get(_latestJsonUri)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteCode = (json['versionCode'] as num?)?.toInt() ?? 0;
      final apkField = (json['apk'] as String?)?.trim() ?? '';
      final downloadUrl =
          apkField.isEmpty ? '' : _apkUri(apkField).toString();

      return AppUpdateInfo(
        versionCode: remoteCode,
        versionName: json['versionName'] as String? ?? '',
        forceUpdate: json['forceUpdate'] as bool? ?? false,
        notes: json['notes'] as String? ?? '',
        downloadUrl: downloadUrl,
        apkAvailable: downloadUrl.isNotEmpty,
        currentVersionCode: currentCode,
        currentVersionName: info.version,
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK, then opens Android’s built-in package installer.
  Future<void> downloadAndInstall(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw StateError('Updates are only supported on Android');
    }
    if (update.downloadUrl.isEmpty) {
      throw StateError('No APK URL in latest.json');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/aips-${update.versionName}-${update.versionCode}.apk',
    );
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', Uri.parse(update.downloadUrl));
    final response =
        await _http.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode >= 400) {
      throw HttpException(
        'Download failed (${response.statusCode})',
        uri: Uri.parse(update.downloadUrl),
      );
    }

    final total = response.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();
    onProgress?.call(1);

    // Hand off to Android’s system package installer (not Play Store).
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }
}
