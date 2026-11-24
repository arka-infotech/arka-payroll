import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arka_payroll/core/layout/arka_layout.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/admin/admin_console_screen.dart';
import 'package:arka_payroll/presentation/employee/employee_calendar_screen.dart';
import 'package:arka_payroll/presentation/employee/employee_leave_screen.dart';
import 'package:arka_payroll/presentation/employee/employee_profile_screen.dart';
import 'package:arka_payroll/presentation/employee/employee_slips_screen.dart';
import 'package:arka_payroll/presentation/hr/dashboard_screen.dart';
import 'package:arka_payroll/presentation/hr/employees_screen.dart';
import 'package:arka_payroll/presentation/hr/hr_leave_screen.dart';
import 'package:arka_payroll/presentation/hr/hr_payslips_screen.dart';
import 'package:arka_payroll/presentation/hr/punch_salary_screen.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/aips_logo.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';
import 'package:arka_payroll/providers/shell_providers.dart';

class _TabDef {
  const _TabDef(this.label, this.icon, this.selectedIcon, this.builder);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
}

/// Single shell: Riverpod tab index + swipeable [PageView] (keeps state).
class MainTabShell extends ConsumerStatefulWidget {
  const MainTabShell({super.key});

  @override
  ConsumerState<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends ConsumerState<MainTabShell> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_TabDef> _tabsForRole(bool employee, bool superAdmin) {
    if (employee) {
      return [
        _TabDef('Slips', Icons.receipt_long_outlined, Icons.receipt_long_rounded,
            () => const EmployeeSlipsScreen(embedded: true)),
        _TabDef('Leave', Icons.beach_access_outlined, Icons.beach_access_rounded,
            () => const EmployeeLeaveScreen(embedded: true)),
        _TabDef(
            'Calendar',
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
            () => const EmployeeCalendarScreen(embedded: true)),
        _TabDef('Profile', Icons.person_outline_rounded, Icons.person_rounded,
            () => const EmployeeProfileScreen(embedded: true)),
      ];
    }
    final hr = [
      _TabDef('Home', Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded, () => const DashboardScreen(embedded: true)),
      _TabDef('People', Icons.people_alt_outlined, Icons.people_alt_rounded,
          () => const EmployeesScreen(embedded: true)),
      _TabDef('Punch', Icons.payments_outlined, Icons.payments_rounded,
          () => const PunchSalaryScreen(embedded: true)),
      _TabDef('Payslips', Icons.receipt_long_outlined, Icons.receipt_long_rounded,
          () => const HrPayslipsScreen(embedded: true)),
      _TabDef('Leave', Icons.event_available_outlined,
          Icons.event_available_rounded, () => const HrLeaveScreen(embedded: true)),
      _TabDef(
          'Calendar',
          Icons.calendar_month_outlined,
          Icons.calendar_month_rounded,
          () => const EmployeeCalendarScreen(embedded: true, teamView: true)),
    ];
    if (superAdmin) {
      hr.add(_TabDef('Root', Icons.shield_outlined, Icons.shield_rounded,
          () => const AdminConsoleScreen(embedded: true)));
    }
    return hr;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final employee = auth.user?.isEmployee == true;
    final superAdmin = auth.user?.isSuperAdmin == true;
    final tabs = _tabsForRole(employee, superAdmin);

    final index = ref.watch(shellTabProvider).clamp(0, tabs.length - 1);

    void syncPage(int i) {
      if (!_pageController.hasClients) return;
      final page = _pageController.page?.round() ?? 0;
      if (page != i) {
        _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }

    void goToTab(int i) {
      ref.read(shellTabProvider.notifier).setIndex(i);
      syncPage(i);
    }

    // Sync when tab index changes from outside (e.g. dashboard shortcuts).
    ref.listen<int>(shellTabProvider, (prev, next) {
      final i = next.clamp(0, tabs.length - 1);
      syncPage(i);
    });

    final wide = context.isDesktop;
    final dense = context.isDense;
    final manyTabs = tabs.length >= 5;

    final body = PageView.builder(
      controller: _pageController,
      itemCount: tabs.length,
      onPageChanged: (i) {
        if (ref.read(shellTabProvider) != i) {
          ref.read(shellTabProvider.notifier).setIndex(i);
        }
      },
      itemBuilder: (_, i) => KeyedSubtree(
        key: ValueKey('tab-${tabs[i].label}'),
        child: tabs[i].builder(),
      ),
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _Rail(
                tabs: tabs,
                selected: index,
                extended: context.arkaWidth >= ArkaBreakpoints.desktopWide,
                onSelect: goToTab,
              ),
              VerticalDivider(width: 1, color: context.cs.outlineVariant),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.cs.outlineVariant)),
        ),
        child: NavigationBar(
          height: dense || manyTabs ? 64 : 72,
          labelBehavior: manyTabs || dense || context.isCompact
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: index,
          onDestinationSelected: goToTab,
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.tabs,
    required this.selected,
    required this.extended,
    required this.onSelect,
  });

  final List<_TabDef> tabs;
  final int selected;
  final bool extended;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    return Container(
      width: extended ? 248 : 88,
      color: context.cs.surface,
      padding:
          EdgeInsets.symmetric(horizontal: extended ? 16 : 12, vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(left: extended ? 8 : 0, bottom: 28),
            child: AipsLogo(height: extended ? 44 : 36),
          ),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                selected: i == selected,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                leading: Icon(i == selected ? tabs[i].selectedIcon : tabs[i].icon),
                title: extended ? Text(tabs[i].label) : null,
                onTap: () => onSelect(i),
              ),
            ),
          const Spacer(),
          if (user != null && extended)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${user.fullName}\n${RoleLabels.display(user.role)}',
                textAlign: TextAlign.center,
                style: context.tt.bodySmall,
              ),
            ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ArkaThemeToggle(), ArkaLogoutButton()],
          ),
        ],
      ),
    );
  }
}

/// Content chrome for screens inside [MainTabShell] (no bottom nav).
class EmbeddedScaffold extends StatelessWidget {
  const EmbeddedScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.titleWidget,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      subtitle: subtitle,
      titleWidget: titleWidget,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottomBar: bottomBar,
      showNav: false,
      child: child,
    );
  }
}
