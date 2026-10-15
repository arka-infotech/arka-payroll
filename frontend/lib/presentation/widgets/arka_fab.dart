import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';

/// Primary floating action — consistent placement and styling.
class ArkaAddFab extends StatelessWidget {
  const ArkaAddFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.person_add_alt_1_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: FloatingActionButton.extended(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: scheme.secondary,
        foregroundColor: Colors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Standard page padding for scrollable content inside [AppScaffold].
class ArkaPagePadding extends StatelessWidget {
  const ArkaPagePadding({super.key, required this.child});

  final Widget child;

  static EdgeInsets of(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return EdgeInsets.fromLTRB(
      wide ? 20 : 16,
      wide ? 16 : 12,
      wide ? 20 : 16,
      wide ? 28 : 96,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: of(context), child: child);
  }
}

/// Error banner for inline form / screen errors.
class ArkaErrorBanner extends StatelessWidget {
  const ArkaErrorBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ArkaColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: ArkaColors.warning, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(height: 1.35, fontWeight: FontWeight.w500),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.05, end: 0);
  }
}
