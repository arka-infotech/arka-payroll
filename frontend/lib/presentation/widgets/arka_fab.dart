import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:arka_payroll/core/layout/arka_layout.dart';

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
    final fab = context.isCompact
        ? FloatingActionButton(
            heroTag: label,
            tooltip: label,
            onPressed: onPressed,
            child: Icon(icon, size: 22),
          )
        : FloatingActionButton.extended(
            heroTag: label,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
            onPressed: onPressed,
            icon: Icon(icon, size: 22),
            label: Text(label),
          );

    return fab.animate().fadeIn(duration: 320.ms).scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Standard page padding for content inside [AppScaffold].
///
/// Horizontal values match the desktop page header so titles and content
/// share one left edge. Extra bottom space is only reserved when a FAB
/// floats over the content.
class ArkaPagePadding extends StatelessWidget {
  const ArkaPagePadding({super.key, required this.child, this.hasFab = false});

  final Widget child;
  final bool hasFab;

  static double horizontal(BuildContext context) => context.pagePadH;

  static EdgeInsets of(BuildContext context, {bool hasFab = false}) =>
      context.pagePadding(hasFab: hasFab);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: of(context, hasFab: hasFab), child: child);
  }
}
