import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final stats = ref.watch(dashboardProvider);
    final firstName = user?.firstName ?? 'there';

    return AppScaffold(
      title: 'Dashboard',
      subtitle:
          '${_greeting()}, $firstName · ${RoleLabels.display(user?.role)}',
      titleWidget: Row(
        children: [
          ArkaAvatar(user?.fullName ?? firstName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: context.tt.bodySmall),
                Text(firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleLarge),
              ],
            ),
          ),
        ],
      ),
      child: ArkaAsync<DashboardData>(
        value: stats,
        onRetry: () => ref.invalidate(dashboardProvider),
        loading: const _DashboardSkeleton(),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: _DashboardBody(data: d, isSuper: user?.isSuperAdmin == true),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.isSuper});

  final DashboardData data;
  final bool isSuper;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final actions = _QuickActions(isSuper: isSuper);
    final recent = _RecentSlips(slips: d.slips);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      children: [
        _PayrollHero(data: d),
        const SizedBox(height: 16),
        ArkaAdaptiveGrid(
          minItemWidth: 150,
          children: [
            ArkaStatTile(
              label: 'Active people',
              caption: 'On payroll',
              value: '${d.activeEmployees}',
              icon: Icons.people_alt_rounded,
              tone: ArkaTone.primary,
              onTap: () => context.go('/employees'),
            ),
            ArkaStatTile(
              label: 'Processed',
              caption: 'This month',
              value: '${d.processedThisMonth}',
              icon: Icons.verified_rounded,
              tone: ArkaTone.success,
            ),
            ArkaStatTile(
              label: 'Drafts pending',
              caption: 'Awaiting lock',
              value: '${d.pendingDrafts}',
              icon: Icons.edit_note_rounded,
              tone: ArkaTone.warning,
              onTap: () => context.go('/payslips'),
            ),
            ArkaStatTile(
              label: 'Left to punch',
              caption: 'This month',
              value: '${d.toPunch}',
              icon: Icons.pending_actions_rounded,
              tone: ArkaTone.info,
              onTap: () => context.go('/punch'),
            ),
          ],
        ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 860) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: actions),
                  const SizedBox(width: 20),
                  Expanded(flex: 7, child: recent),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [actions, const SizedBox(height: 28), recent],
            );
          },
        ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
      ],
    );
  }
}

class _PayrollHero extends StatelessWidget {
  const _PayrollHero({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final period = PayPeriod.now();
    final pct = (data.progress * 100).round();
    const white70 = Color(0xB3FFFFFF);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.heroStart, p.heroEnd],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -60,
            top: -60,
            child: _Ring(size: 220, alpha: 0.07),
          ),
          const Positioned(
            right: 40,
            bottom: -90,
            child: _Ring(size: 180, alpha: 0.05),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        period.label.toUpperCase(),
                        style: context.tt.labelSmall
                            ?.copyWith(color: white70, letterSpacing: 1.2),
                      ),
                    ),
                    ArkaLiveIndicator(updatedAt: data.fetchedAt, onDark: true),
                  ],
                ),
                const SizedBox(height: 18),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.inr0(data.totalNet),
                    style: context.tt.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Net payout across ${data.slips.length} slip${data.slips.length == 1 ? '' : 's'} this month',
                  style: context.tt.bodyMedium?.copyWith(color: white70),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data.processedThisMonth} of ${data.activeEmployees} employees processed',
                        style: context.tt.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    Text('$pct%',
                        style: context.tt.labelLarge
                            ?.copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: data.progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: const Color(0xFF6EE7B7),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 480;
                    final punch = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ArkaColors.navy,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => context.go('/punch'),
                      icon: const Icon(Icons.payments_rounded, size: 20),
                      label: const Text('Punch salary'),
                    );
                    final slips = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      onPressed: () => context.go('/payslips'),
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: Text(narrow ? 'Payslips' : 'View payslips'),
                    );
                    if (narrow) {
                      return Row(
                        children: [
                          Expanded(child: punch),
                          const SizedBox(width: 10),
                          Expanded(child: slips),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [punch, slips],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04, end: 0);
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: alpha), width: 28),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isSuper});

  final bool isSuper;

  @override
  Widget build(BuildContext context) {
    final items = [
      ArkaQuickAction(
        title: 'Add employee',
        subtitle: 'Profile, bank and pay package',
        icon: Icons.person_add_alt_1_rounded,
        tone: ArkaTone.primary,
        onTap: () => context.push('/employees/add'),
      ),
      ArkaQuickAction(
        title: 'Punch salary',
        subtitle: 'Attendance, bonus and lock',
        icon: Icons.payments_rounded,
        tone: ArkaTone.success,
        onTap: () => context.go('/punch'),
      ),
      ArkaQuickAction(
        title: 'Payslips & PDF',
        subtitle: 'Review, edit and download',
        icon: Icons.receipt_long_rounded,
        tone: ArkaTone.info,
        onTap: () => context.go('/payslips'),
      ),
      if (isSuper)
        ArkaQuickAction(
          title: 'Root console',
          subtitle: 'Presence, bans and audit log',
          icon: Icons.shield_rounded,
          tone: ArkaTone.warning,
          onTap: () => context.go('/admin'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArkaSectionTitle('Quick actions'),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          items[i],
        ],
      ],
    );
  }
}

class _RecentSlips extends StatelessWidget {
  const _RecentSlips({required this.slips});

  final List<PeriodSlipRow> slips;

  @override
  Widget build(BuildContext context) {
    final shown = slips.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArkaSectionTitle(
          'This month’s payslips',
          subtitle: '${slips.length} total',
          action: TextButton(
            onPressed: () => context.go('/payslips'),
            child: const Text('See all'),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: shown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: ArkaEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No slips yet',
                    message:
                        'Punch salary for an employee and their slip appears here.',
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(indent: 72),
                      _RecentRow(slip: shown[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.slip});

  final PeriodSlipRow slip;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = slipStatusTone(slip.status);
    return InkWell(
      onTap: () => context.push('/slip/${slip.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ArkaAvatar(slip.employeeName, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slip.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(slip.trackingReference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.inr0(slip.netPay), style: context.tt.titleSmall),
                const SizedBox(height: 4),
                ArkaStatusChip(label, tone: tone, dot: true),
                if (slipEmailTone(slip.emailStatus) case final email?) ...[
                  const SizedBox(height: 4),
                  ArkaStatusChip(email.$2, tone: email.$1, dot: true),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      children: [
        const ArkaSkeleton(height: 250, radius: 24),
        const SizedBox(height: 16),
        ArkaAdaptiveGrid(
          minItemWidth: 150,
          children: [
            for (var i = 0; i < 4; i++)
              const ArkaSkeleton(height: 132, radius: 18)
          ],
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < 3; i++) ...[
          const ArkaSkeleton(height: 72, radius: 18),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
