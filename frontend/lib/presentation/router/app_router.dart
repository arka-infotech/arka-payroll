import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/auth/login_screen.dart';
import 'package:arka_payroll/presentation/hr/hr_payroll_dashboard.dart';
import 'package:arka_payroll/presentation/employee/employee_slips_screen.dart';
import 'package:arka_payroll/presentation/payroll/pdf_viewer_screen.dart';

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';

      if (auth.status == AuthStatus.unknown) return null;

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) {
        return auth.user?.isHr == true ? '/hr' : '/my-slips';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/hr',
        builder: (_, __) => const HrPayrollDashboard(),
      ),
      GoRoute(
        path: '/my-slips',
        builder: (_, __) => const EmployeeSlipsScreen(),
      ),
      GoRoute(
        path: '/slip/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PdfViewerScreen(payrollId: id);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route error: ${state.error}')),
    ),
  );
}
