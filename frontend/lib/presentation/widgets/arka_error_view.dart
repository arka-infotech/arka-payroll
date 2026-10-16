import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/providers/app_providers.dart';

IconData failureIcon(FailureKind kind) => switch (kind) {
      FailureKind.offline => Icons.wifi_off_rounded,
      FailureKind.unauthorized => Icons.lock_clock_rounded,
      FailureKind.forbidden => Icons.block_rounded,
      FailureKind.notFound => Icons.search_off_rounded,
      FailureKind.validation => Icons.edit_note_rounded,
      FailureKind.conflict => Icons.content_copy_rounded,
      FailureKind.server => Icons.cloud_off_rounded,
      FailureKind.unknown => Icons.error_outline_rounded,
    };

/// Full-page error with a clear title, explanation and the right next step.
class ArkaErrorView extends ConsumerWidget {
  const ArkaErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = describeError(error);
    final cs = context.cs;
    final signIn = f.kind == FailureKind.unauthorized;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(failureIcon(f.kind),
                    color: cs.onErrorContainer, size: 34),
              ),
              const SizedBox(height: 20),
              Text(f.title,
                  textAlign: TextAlign.center, style: context.tt.titleLarge),
              const SizedBox(height: 8),
              Text(
                f.message,
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 22),
              if (signIn)
                FilledButton.icon(
                  onPressed: () => ref.read(authStateProvider).logout(),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in again'),
                )
              else if (onRetry != null)
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 260.ms)
          .scale(begin: const Offset(0.97, 0.97)),
    );
  }
}

/// Inline, dismissible alert for forms and sections.
class ArkaInlineAlert extends StatelessWidget {
  const ArkaInlineAlert({
    super.key,
    required this.message,
    this.title,
    this.tone = ArkaAlertTone.error,
    this.onDismiss,
    this.action,
  });

  /// Builds an alert from any thrown error.
  factory ArkaInlineAlert.fromError(Object error,
      {Key? key, VoidCallback? onDismiss}) {
    final f = describeError(error);
    return ArkaInlineAlert(
        key: key, title: f.title, message: f.message, onDismiss: onDismiss);
  }

  final String message;
  final String? title;
  final ArkaAlertTone tone;
  final VoidCallback? onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final p = context.palette;
    final (bg, fg, accent, icon) = switch (tone) {
      ArkaAlertTone.error => (
          cs.errorContainer,
          cs.onErrorContainer,
          cs.error,
          Icons.error_outline_rounded
        ),
      ArkaAlertTone.warning => (
          p.warningContainer,
          p.onWarningContainer,
          p.warning,
          Icons.warning_amber_rounded
        ),
      ArkaAlertTone.info => (
          p.infoContainer,
          p.onInfoContainer,
          p.info,
          Icons.info_outline_rounded
        ),
      ArkaAlertTone.success => (
          p.successContainer,
          p.onSuccessContainer,
          p.success,
          Icons.check_circle_outline_rounded
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!,
                      style: context.tt.titleSmall?.copyWith(color: fg)),
                  const SizedBox(height: 2),
                ],
                Text(message,
                    style: context.tt.bodyMedium
                        ?.copyWith(color: fg, height: 1.4)),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, size: 18, color: fg),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.08, end: 0);
  }
}

enum ArkaAlertTone { error, warning, info, success }

/// Floating snackbars with an icon and a tone that matches the outcome.
class ArkaSnack {
  static void error(BuildContext context, Object error) {
    final f = describeError(error);
    _show(context, f.title, f.message, ArkaAlertTone.error);
  }

  static void success(BuildContext context, String message) =>
      _show(context, null, message, ArkaAlertTone.success);

  static void info(BuildContext context, String message) =>
      _show(context, null, message, ArkaAlertTone.info);

  static void warning(BuildContext context, String message) =>
      _show(context, null, message, ArkaAlertTone.warning);

  static void _show(
      BuildContext context, String? title, String message, ArkaAlertTone tone) {
    final cs = context.cs;
    final p = context.palette;
    final (bg, fg, icon) = switch (tone) {
      ArkaAlertTone.error => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.error_rounded
        ),
      ArkaAlertTone.warning => (
          p.warningContainer,
          p.onWarningContainer,
          Icons.warning_rounded
        ),
      ArkaAlertTone.info => (
          cs.inverseSurface,
          cs.onInverseSurface,
          Icons.info_rounded
        ),
      ArkaAlertTone.success => (
          p.successContainer,
          p.onSuccessContainer,
          Icons.check_circle_rounded
        ),
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: bg,
        duration: Duration(seconds: tone == ArkaAlertTone.error ? 6 : 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title,
                        style: context.tt.titleSmall?.copyWith(color: fg)),
                  Text(message,
                      style: context.tt.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(label: 'OK', textColor: fg, onPressed: () {}),
      ),
    );
  }
}
