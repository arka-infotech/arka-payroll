import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/core/update/app_update_service.dart';

/// Checks for Android APK updates after the first frame and prompts to install.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  final _service = AppUpdateService();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheck());
  }

  Future<void> _maybeCheck() async {
    if (_checked || kIsWeb) return;
    _checked = true;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final info = await _service.check();
    if (!mounted || info == null || !info.updateAvailable) return;
    await _showUpdateDialog(info);
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    var downloading = false;
    var progress = 0.0;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(info.forceUpdate
                  ? 'Update required'
                  : 'Update available'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'AIPS ${info.versionName} (build ${info.versionCode}) is ready.\n'
                    'You have ${info.currentVersionName} (build ${info.currentVersionCode}).',
                    style: ctx.tt.bodyMedium,
                  ),
                  if (info.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(info.notes.trim(), style: ctx.tt.bodySmall),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress <= 0 ? null : progress),
                    const SizedBox(height: 8),
                    Text(
                      progress <= 0
                          ? 'Starting download…'
                          : 'Downloading ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: ctx.tt.labelMedium,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: ctx.tt.bodySmall
                            ?.copyWith(color: ctx.cs.error)),
                  ],
                ],
              ),
              actions: [
                if (!info.forceUpdate && !downloading)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setLocal(() {
                            downloading = true;
                            error = null;
                            progress = 0;
                          });
                          try {
                            await _service.downloadAndInstall(
                              info,
                              onProgress: (p) =>
                                  setLocal(() => progress = p),
                            );
                            // Android system installer takes over from here.
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setLocal(() {
                              downloading = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: Text(
                      downloading ? 'Downloading…' : 'Download & install'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
