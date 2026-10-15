import 'package:flutter/material.dart';
import 'package:arka_payroll/core/config/app_config.dart';

/// AIPS logo — theme-matched artwork from official source PNGs.
class AipsLogo extends StatelessWidget {
  const AipsLogo({
    super.key,
    this.height = 120,
    this.width,
    /// Force the dark-theme logo (silver mark) on a dark/navy background.
    this.onDarkBackground,
  });

  final double height;
  final double? width;
  final bool? onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final darkTheme = Theme.of(context).brightness == Brightness.dark;
    final useDarkLogo = onDarkBackground ?? darkTheme;
    final asset = useDarkLogo ? AppConfig.logoDark : AppConfig.logoLight;

    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
