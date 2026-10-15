import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/core/theme/theme_controller.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/presentation/widgets/aips_logo.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';

/// Responsive shell:
/// - Phone: AppBar + BottomNavigationBar (no double header)
/// - Desktop: NavigationRail + content top bar
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const _hrDestinations = [
    _NavItem('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    _NavItem('/employees', Icons.groups_outlined, Icons.groups, 'People'),
    _NavItem('/punch', Icons.payments_outlined, Icons.payments, 'Punch'),
    _NavItem('/payslips', Icons.picture_as_pdf_outlined, Icons.picture_as_pdf, 'Slips'),
  ];

  static const _employeeDestinations = [
    _NavItem('/my-slips', Icons.receipt_long_outlined, Icons.receipt_long, 'Pay'),
  ];

  static const _superDestinations = [
    _NavItem('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    _NavItem('/employees', Icons.groups_outlined, Icons.groups, 'People'),
    _NavItem('/punch', Icons.payments_outlined, Icons.payments, 'Punch'),
    _NavItem('/payslips', Icons.picture_as_pdf_outlined, Icons.picture_as_pdf, 'Slips'),
    _NavItem('/admin', Icons.shield_outlined, Icons.shield, 'Root'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final theme = context.watch<ThemeController>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final loc = GoRouterState.of(context).matchedLocation;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final destinations = auth.user?.isSuperAdmin == true
        ? _superDestinations
        : auth.user?.isHr == true
            ? _hrDestinations
            : _employeeDestinations;

    var selected = destinations.indexWhere((d) => loc.startsWith(d.path));
    if (selected < 0) selected = 0;

    final content = SafeArea(
      child: ArkaPagePadding(child: child),
    );

    if (wide) {
      return Scaffold(
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(destinations[i].path),
              labelType: MediaQuery.sizeOf(context).width < 1180
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(12, 20, 12, 20),
                child: AipsLogo(height: 48),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Theme',
                          onPressed: theme.toggle,
                          icon: Icon(
                            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Logout',
                          onPressed: () async {
                            await auth.logout();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DesktopHeader(
                    title: title,
                    subtitle: auth.user == null
                        ? AppConfig.appName
                        : '${auth.user!.fullName} · ${RoleLabels.display(auth.user!.role)}',
                    actions: actions,
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile ──────────────────────────────────────────────────────────────
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const Text(
              AppConfig.appName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Theme',
            onPressed: theme.toggle,
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await auth.logout();
                if (context.mounted) context.go('/login');
              } else if (v == 'reports') {
                context.go('/reports');
              }
            },
            itemBuilder: (_) => [
              if (auth.user?.isHr == true)
                const PopupMenuItem(value: 'reports', child: Text('Reports')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: content,
      bottomNavigationBar: destinations.length <= 1
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(destinations[i].path),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.title,
    required this.subtitle,
    this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ArkaColors.muted,
                      ),
                ),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
