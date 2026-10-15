import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await context.read<PayrollRepository>().fetchStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isSuper = auth.user?.isSuperAdmin == true;
    final roleLabel = RoleLabels.display(auth.user?.role);

    return AppScaffold(
      title: 'Home',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  children: [
                    Text(
                      'Hi, ${auth.user?.firstName ?? 'there'}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ArkaColors.muted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ArkaStatStrip(
                      items: [
                        ArkaStatItem(
                          label: 'Active',
                          value: '${_stats?['activeEmployees'] ?? 0}',
                          icon: Icons.groups_outlined,
                          accent: ArkaColors.navy,
                        ),
                        ArkaStatItem(
                          label: 'Drafts',
                          value: '${_stats?['pendingSlips'] ?? 0}',
                          icon: Icons.pending_actions_outlined,
                          accent: ArkaColors.warning,
                        ),
                        ArkaStatItem(
                          label: 'This month',
                          value: '${_stats?['processedThisMonth'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          accent: ArkaColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const ArkaSectionTitle('Shortcuts'),
                    const SizedBox(height: 4),
                    ArkaQuickTile(
                      title: 'Punch salary',
                      subtitle: 'Process and lock this month',
                      icon: Icons.payments_outlined,
                      onTap: () => context.go('/punch'),
                    ),
                    const SizedBox(height: 10),
                    ArkaQuickTile(
                      title: 'Payslips & PDF',
                      subtitle: 'Download slips for any employee',
                      icon: Icons.picture_as_pdf_outlined,
                      onTap: () => context.go('/payslips'),
                    ),
                    if (isSuper) ...[
                      const SizedBox(height: 10),
                      ArkaQuickTile(
                        title: 'Root console',
                        subtitle: 'Audit, ban, presence',
                        icon: Icons.shield_outlined,
                        onTap: () => context.go('/admin'),
                      ),
                    ],
                    const SizedBox(height: 56),
                  ],
                ),
    );
  }
}
