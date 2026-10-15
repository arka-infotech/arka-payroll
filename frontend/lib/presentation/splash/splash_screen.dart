import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/router/splash_gate.dart';
import 'package:arka_payroll/presentation/widgets/aips_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.splashGate});

  final SplashGate splashGate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  Future<void> _finish() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.splashGate.complete();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? Colors.black : const Color(0xFFF6F4F1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AipsLogo(height: 168)
                .animate()
                .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 20),
            Text(
              AppConfig.appTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
                color: dark
                    ? Colors.white.withValues(alpha: 0.75)
                    : ArkaColors.muted,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
