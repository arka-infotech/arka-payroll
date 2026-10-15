import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepo = AuthRepository();
  await authRepo.hydrate();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepo),
        Provider<PayrollRepository>(
          create: (_) => PayrollRepository(authRepo),
        ),
        ChangeNotifierProvider<AuthState>(
          create: (_) => AuthState(authRepo)..bootstrap(),
        ),
      ],
      child: const ArkaPayrollApp(),
    ),
  );
}

class ArkaPayrollApp extends StatelessWidget {
  const ArkaPayrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final router = createRouter(auth);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ArkaTheme.light,
      routerConfig: router,
    );
  }
}
