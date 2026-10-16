import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

enum _PeopleFilter { all, admins, employees, noPay }

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _query = '';
  _PeopleFilter _filter = _PeopleFilter.all;

  bool _matches(Map<String, dynamic> u, _PeopleFilter f) => switch (f) {
        _PeopleFilter.all => true,
        _PeopleFilter.admins => u['role'] == 'HR_ADMIN',
        _PeopleFilter.employees => u['role'] == 'EMPLOYEE',
        _PeopleFilter.noPay => u['salaryStructure'] == null,
      };

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> users) {
    final q = _query.trim().toLowerCase();
    return users.where((u) {
      if (!_matches(u, _filter)) return false;
      if (q.isEmpty) return true;
      final blob = '${u['firstName']} ${u['lastName']} ${u['email']} '
              '${u['designation'] ?? ''} ${u['employeeCode'] ?? ''}'
          .toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  Future<void> _openAdd() async {
    await context.push('/employees/add');
    if (mounted) invalidatePayrollData(ref);
  }

  Future<void> _openEdit(String id) async {
    final saved = await context.push<bool>('/employees/$id/edit');
    if (saved == true && mounted) invalidatePayrollData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final users = ref.watch(employeesProvider);

    return AppScaffold(
      title: 'People',
      subtitle: 'Everyone on payroll, their access and pay package',
      actions: wide
          ? [
              FilledButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: const Text('Add user'),
              ),
            ]
          : null,
      floatingActionButton:
          wide ? null : ArkaAddFab(label: 'Add user', onPressed: _openAdd),
      child: ArkaAsync<List<Map<String, dynamic>>>(
        value: users,
        onRetry: () => ref.invalidate(employeesProvider),
        data: (all) {
          final list = _visible(all);
          final online = all.where((u) => u['isOnline'] == true).length;
          final counts = {
            for (final f in _PeopleFilter.values)
              f: all.where((u) => _matches(u, f)).length,
          };

          return RefreshIndicator(
            onRefresh: () => ref.refresh(employeesProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      ArkaSearchField(
                        hint: 'Search name, email, ID or designation',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in _PeopleFilter.values) ...[
                              ChoiceChip(
                                label: Text('${_label(f)}  ${counts[f]}'),
                                selected: _filter == f,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${list.length} shown · $online online now',
                        style: context.tt.labelMedium,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ArkaEmptyState(
                      icon: all.isEmpty
                          ? Icons.group_add_outlined
                          : Icons.search_off_rounded,
                      title: all.isEmpty ? 'No people yet' : 'No matches',
                      message: all.isEmpty
                          ? 'Add an employee or an admin to start running payroll.'
                          : 'Try a different search or filter.',
                      action: all.isEmpty
                          ? FilledButton.icon(
                              onPressed: _openAdd,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Add first user'),
                            )
                          : null,
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: ArkaAdaptiveGrid(
                      minItemWidth: 340,
                      maxColumns: 3,
                      children: [
                        for (var i = 0; i < list.length; i++)
                          _PersonCard(
                            user: list[i],
                            onTap: () => _openEdit(list[i]['id'] as String),
                          ).animate().fadeIn(
                              delay: (20 * i.clamp(0, 10)).ms,
                              duration: 240.ms),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(_PeopleFilter f) => switch (f) {
        _PeopleFilter.all => 'All',
        _PeopleFilter.admins => 'Admins',
        _PeopleFilter.employees => 'Employees',
        _PeopleFilter.noPay => 'No pay package',
      };
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user, required this.onTap});

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    final online = u.containsKey('isOnline') ? u['isOnline'] == true : null;
    final isAdmin = u['role'] == 'HR_ADMIN';
    final status = '${u['status'] ?? 'ACTIVE'}';
    final code = '${u['employeeCode'] ?? ''}'.trim();
    final designation = '${u['designation'] ?? ''}'.trim();

    return ArkaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArkaAvatar(name.isEmpty ? '?' : name, size: 48, online: online),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Unnamed' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium,
                      ),
                    ),
                    if (code.isNotEmpty)
                      Text(code,
                          style: context.tt.labelMedium
                              ?.copyWith(letterSpacing: 0.4)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  designation.isEmpty
                      ? '${u['email']}'
                      : '$designation · ${u['email']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ArkaStatusChip(
                      RoleLabels.display(u['role'] as String?),
                      tone: isAdmin ? ArkaTone.primary : ArkaTone.neutral,
                      icon: isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.badge_outlined,
                    ),
                    if (u['salaryStructure'] == null)
                      const ArkaStatusChip('No pay package',
                          tone: ArkaTone.warning,
                          icon: Icons.warning_amber_rounded),
                    if (status != 'ACTIVE')
                      ArkaStatusChip(Fmt.titleCase(status),
                          tone: ArkaTone.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
