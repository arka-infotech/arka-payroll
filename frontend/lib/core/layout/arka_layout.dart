import 'package:flutter/material.dart';

/// Shared width breakpoints for Arka.
///
/// Tuned for Material phone/tablet bands so layouts work from ~320dp
/// (small Androids / SE) through large phones and into desktop shell.
class ArkaBreakpoints {
  ArkaBreakpoints._();

  /// Very small phones (SE-class, some budget Androids).
  static const double compact = 360;

  /// Phone vs tablet content (Material medium).
  static const double phone = 600;

  /// Phone chrome (bottom nav) vs desktop sidebar.
  static const double desktop = 900;

  /// Sidebar labels expand.
  static const double desktopWide = 1180;
}

/// Convenient layout queries from [BuildContext].
extension ArkaLayoutX on BuildContext {
  double get arkaWidth => MediaQuery.sizeOf(this).width;

  double get arkaTextScale => MediaQuery.textScalerOf(this).scale(1);

  /// Width below [ArkaBreakpoints.compact], or large accessibility text.
  bool get isCompact =>
      arkaWidth < ArkaBreakpoints.compact || arkaTextScale > 1.2;

  /// Phone-width viewport (includes large phones / fold outer).
  bool get isPhone => arkaWidth < ArkaBreakpoints.phone;

  /// Desktop shell (≥ sidebar layout).
  bool get isDesktop => arkaWidth >= ArkaBreakpoints.desktop;

  /// Dense chrome: compact phones, or any phone with bumped text size.
  bool get isDense =>
      arkaWidth < ArkaBreakpoints.phone &&
      (arkaWidth < 420 || arkaTextScale > 1.1);

  /// Prefer short action labels (bottom bars, hero CTAs).
  bool get useShortLabels => !isDesktop || isDense;

  double get pagePadH {
    if (isDesktop) return 28;
    if (isCompact) return 12;
    if (isPhone) return 14;
    return 20;
  }

  EdgeInsets pagePadding({bool hasFab = false}) {
    final h = pagePadH;
    return EdgeInsets.fromLTRB(
      h,
      isDesktop ? 4 : 6,
      h,
      (isDesktop ? 24 : 12) + (hasFab ? 72 : 0),
    );
  }
}
