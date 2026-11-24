import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/auth/login_screen.dart';
import 'package:arka_payroll/presentation/hr/add_user_screen.dart';
import 'package:arka_payroll/presentation/hr/edit_slip_screen.dart';
import 'package:arka_payroll/presentation/hr/edit_user_screen.dart';
import 'package:arka_payroll/presentation/hr/punch_salary_screen.dart';
import 'package:arka_payroll/presentation/hr/reports_screen.dart';
import 'package:arka_payroll/presentation/payroll/pdf_viewer_screen.dart';
import 'package:arka_payroll/presentation/router/splash_gate.dart';
import 'package:arka_payroll/presentation/shell/main_tab_shell.dart';
import 'package:arka_payroll/presentation/splash/splash_screen.dart';

String homeFor(AuthState auth) => '/home';

bool _isEmployeeOnlyRoute(String loc) =>
    loc == '/my-slips' ||
    loc == '/my-leave' ||
    loc.startsWith('/my-leave') ||
    loc == '/my-calendar' ||
    loc.startsWith('/my-calendar');

bool _isHrRoute(String loc) =>
    loc == '/dashboard' ||
    loc.startsWith('/employees') ||
    loc.startsWith('/punch') ||
    loc.startsWith('/payslips') ||
    loc.startsWith('/reports') ||
    loc.startsWith('/admin') ||
    loc.startsWith('/hr-leave') ||
    loc.startsWith('/slip/');

/// Legacy standalone tab paths → shell home.
String? _legacyTabRedirect(String loc, GoRouterState state) {
  switch (loc) {
    case '/dashboard':
    case '/payslips':
    case '/hr-leave':
    case '/admin':
    case '/my-slips':
    case '/my-leave':
    case '/my-calendar':
    case '/employees':
      return '/home';
    case '/punch':
      if (state.uri.queryParameters.isEmpty) return '/home';
      return null;
    default:
      return null;
  }
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
      final employee = auth.user?.isEmployee == true;

      if (onSplash) {
        if (splash.done) {
          return loggedIn ? homeFor(auth) : '/login';
        }
        return null;
      }

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return homeFor(auth);

      if (loggedIn) {
        final legacy = _legacyTabRedirect(loc, state);
        if (legacy != null) return legacy;

        if (employee && _isHrRoute(loc)) {
          // Employees may open /slip/:id for PDF view (not edit).
          if (loc.startsWith('/slip/') && !loc.endsWith('/edit')) {
            return null;
          }
          return '/home';
        }
        if (!employee && _isEmployeeOnlyRoute(loc)) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => SplashScreen(splashGate: splash),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const MainTabShell()),
      GoRoute(
        path: '/dashboard',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/employees',
        redirect: (context, state) {
          if (state.matchedLocation == '/employees') return '/home';
          return null;
        },
        routes: [
          GoRoute(
              path: 'add', builder: (_, __) => const AddUserScreen()),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) =>
                EditUserScreen(userId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/punch',
        redirect: (context, state) {
          if (state.uri.queryParameters.isEmpty) return '/home';
          return null;
        },
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return PunchSalaryScreen(
            initialUserId: q['userId'],
            initialYear: int.tryParse(q['year'] ?? ''),
            initialMonth: int.tryParse(q['month'] ?? ''),
            showNav: false,
          );
        },
      ),
      GoRoute(
        path: '/payslips',
        redirect: (_, __) => '/home',
      ),
      GoRoute(path: '/hr-leave', redirect: (_, __) => '/home'),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/admin', redirect: (_, __) => '/home'),
      GoRoute(path: '/my-slips', redirect: (_, __) => '/home'),
      GoRoute(path: '/my-leave', redirect: (_, __) => '/home'),
      GoRoute(path: '/my-calendar', redirect: (_, __) => '/home'),
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
      GoRoute(path: '/hr', redirect: (_, __) => '/home'),
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