import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/providers/app_providers.dart';
import 'package:arka_payroll/presentation/widgets/aips_logo.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';

/// Responsive shell:
/// - Phone: flat app bar (theme + sign out) and a bottom navigation bar.
/// - Desktop: sidebar navigation and a page header aligned with content.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.titleWidget,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.showNav = true,
  });

  final String title;
  final Widget child;

  /// Desktop header subtitle; defaults to the signed-in user.
  final String? subtitle;

  /// Replaces the phone app bar title (e.g. the dashboard greeting).
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Sticky actions under the content (forms).
  final Widget? bottomBar;

  /// Hide the phone bottom navigation on focused, pushed screens.
  final bool showNav;

  /// Desktop content stops growing past this so lists and forms stay readable.
  static const double maxContentWidth = 1240;

  static const _hrDestinations = [
    _NavItem('/dashboard', Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded, 'Home'),
    _NavItem('/employees', Icons.people_alt_outlined, Icons.people_alt_rounded,
        'People'),
    _NavItem(
        '/punch', Icons.payments_outlined, Icons.payments_rounded, 'Punch'),
    _NavItem('/payslips', Icons.receipt_long_outlined,
        Icons.receipt_long_rounded, 'Payslips'),
  ];

  static const _superDestinations = [
    ..._hrDestinations,
    _NavItem('/admin', Icons.shield_outlined, Icons.shield_rounded, 'Root'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final loc = GoRouterState.of(context).matchedLocation;

    // Admin-only app — Super Admin gets Root; everyone else with access is HR.
    final destinations = auth.user?.isSuperAdmin == true
        ? _superDestinations
        : _hrDestinations;

    var selected = destinations.indexWhere((d) => loc.startsWith(d.path));
    if (selected < 0) selected = 0;

    final content = ArkaPagePadding(
      hasFab: floatingActionButton != null,
      child: child,
    );

    if (wide) {
      final user = auth.user;
      return Scaffold(
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          child: Row(
            children: [
              _Sidebar(
                destinations: destinations,
                selected: selected,
                extended: width >= 1180,
              ),
              VerticalDivider(width: 1, color: context.cs.outlineVariant),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: maxContentWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DesktopHeader(
                                title: title,
                                subtitle: subtitle ??
                                    (user == null
                                        ? null
                                        : '${user.fullName} · ${RoleLabels.display(user.role)}'),
                                actions: actions,
                              ),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (bottomBar != null) bottomBar!,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Phone ───────────────────────────────────────────────────────────────
    final showBottomNav = showNav && destinations.length > 1;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: titleWidget ?? Text(title),
        actions: [
          ...?actions,
          const ArkaThemeToggle(),
          const ArkaLogoutButton(),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        bottom: !showBottomNav && bottomBar == null,
        child: Column(
          children: [
            Expanded(child: content),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? DecoratedBox(
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: context.cs.outlineVariant)),
              ),
              child: NavigationBar(
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
            )
          : null,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.destinations,
    required this.selected,
    required this.extended,
  });

  final List<_NavItem> destinations;
  final int selected;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final cs = context.cs;

    return Container(
      width: extended ? 248 : 88,
      color: cs.surface,
      padding:
          EdgeInsets.symmetric(horizontal: extended ? 16 : 12, vertical: 20),
      child: Column(
        crossAxisAlignment:
            extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: extended ? 8 : 0, bottom: 28),
            child: AipsLogo(height: extended ? 44 : 36),
          ),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SidebarItem(
                item: destinations[i],
                selected: i == selected,
                extended: extended,
              ),
            ),
          const Spacer(),
          if (user != null && extended)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  ArkaAvatar(user.fullName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleSmall),
                        Text(RoleLabels.display(user.role),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                  message: user.fullName,
                  child: ArkaAvatar(user.fullName, size: 40)),
            ),
          Row(
            mainAxisAlignment: extended
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: extended
                ? const [ArkaThemeToggle(), ArkaLogoutButton()]
                : const [ArkaThemeToggle()],
          ),
          if (!extended) const ArkaLogoutButton(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(
      {required this.item, required this.selected, required this.extended});

  final _NavItem item;
  final bool selected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    final tile = Material(
      color: selected ? cs.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(item.path),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 12),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon,
                  color: fg, size: 22),
              if (extended) ...[
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: context.tt.labelLarge?.copyWith(
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return extended
        ? tile
        : Tooltip(message: item.label, child: SizedBox(width: 56, child: tile));
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.title, this.subtitle, this.actions});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final h = ArkaPagePadding.horizontal(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(h, 28, h, 20),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            IconButton.outlined(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tt.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: context.tt.bodyMedium
                          ?.copyWith(color: context.cs.onSurfaceVariant)),
                ],
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
