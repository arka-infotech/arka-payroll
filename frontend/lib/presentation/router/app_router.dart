import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/auth/login_screen.dart';
import 'package:arka_payroll/presentation/admin/admin_console_screen.dart';
import 'package:arka_payroll/presentation/employee/employee_slips_screen.dart';
import 'package:arka_payroll/presentation/hr/add_user_screen.dart';
import 'package:arka_payroll/presentation/hr/dashboard_screen.dart';
import 'package:arka_payroll/presentation/hr/edit_slip_screen.dart';
import 'package:arka_payroll/presentation/hr/employees_screen.dart';
import 'package:arka_payroll/presentation/hr/punch_salary_screen.dart';
import 'package:arka_payroll/presentation/hr/hr_payslips_screen.dart';
import 'package:arka_payroll/presentation/hr/reports_screen.dart';
import 'package:arka_payroll/presentation/payroll/pdf_viewer_screen.dart';
import 'package:arka_payroll/presentation/router/splash_gate.dart';
import 'package:arka_payroll/presentation/splash/splash_screen.dart';

String homeFor(AuthState auth) {
  if (auth.user?.role == 'SUPER_ADMIN') return '/dashboard';
  if (auth.user?.isHr == true) return '/dashboard';
  return '/my-slips';
}

String _initialLocation(AuthState auth, SplashGate splash) {
  if (!splash.done) return '/splash';
  if (auth.status == AuthStatus.authenticated) return homeFor(auth);
  return '/login';
}

GoRouter createRouter(AuthState auth, SplashGate splash) {
  return GoRouter(
    initialLocation: _initialLocation(auth, splash),
    refreshListenable: Listenable.merge([auth, splash]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final onLogin = loc == '/login';
      final loggedIn = auth.status == AuthStatus.authenticated;

      // Leave splash only via redirect after SplashGate.complete()
      if (onSplash) {
        if (splash.done) {
          return loggedIn ? homeFor(auth) : '/login';
        }
        return null;
      }

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return homeFor(auth);

      if (loggedIn &&
          auth.user?.role == 'EMPLOYEE' &&
          (loc.startsWith('/dashboard') ||
              loc.startsWith('/employees') ||
              loc.startsWith('/punch') ||
              loc.startsWith('/reports') ||
              loc.startsWith('/payslips') ||
              loc.startsWith('/admin'))) {
        return '/my-slips';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => SplashScreen(splashGate: splash),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
      GoRoute(path: '/employees/add', builder: (_, __) => const AddUserScreen()),
      GoRoute(
        path: '/punch',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return PunchSalaryScreen(
            initialUserId: q['userId'],
            initialYear: int.tryParse(q['year'] ?? ''),
            initialMonth: int.tryParse(q['month'] ?? ''),
          );
        },
      ),
      GoRoute(path: '/payslips', builder: (_, __) => const HrPayslipsScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminConsoleScreen()),
      GoRoute(path: '/my-slips', builder: (_, __) => const EmployeeSlipsScreen()),
      GoRoute(
        path: '/slip/:id/edit',
        builder: (context, state) =>
            EditSlipScreen(payrollId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/slip/:id',
        builder: (context, state) =>
            PdfViewerScreen(payrollId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/hr', redirect: (_, __) => '/dashboard'),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Route error: ${state.error}'),
        ),
      ),
    ),
  );
}
