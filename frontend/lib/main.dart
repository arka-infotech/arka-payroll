import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/core/theme/theme_controller.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/router/app_router.dart';
import 'package:arka_payroll/presentation/router/splash_gate.dart';
import 'package:arka_payroll/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepo = AuthRepository();
  await authRepo.hydrate();
  final theme = ThemeController();
  await theme.hydrate();

  final authState = AuthState(authRepo);
  await authState.bootstrap();

  final splashGate = SplashGate();
  final router = createRouter(authState, splashGate);

  runApp(
    ProviderScope(
      retry: arkaRetry,
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        authStateProvider.overrideWith((ref) => authState),
        themeControllerProvider.overrideWith((ref) => theme),
      ],
      child: AipsApp(router: router),
    ),
  );
}

class AipsApp extends ConsumerWidget {
  const AipsApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ArkaTheme.light,
      darkTheme: ArkaTheme.dark,
      themeMode: theme.mode,
      routerConfig: router,
    );
  }
}
