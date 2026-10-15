import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(
              AppConfig.companyName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          ...?actions,
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${user.fullName} · ${user.role}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (user?.isHr == true)
            TextButton(
              onPressed: () => context.go('/hr'),
              child: const Text('HR', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: () => context.go('/my-slips'),
            child: const Text('My Slips', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
    );
  }
}
