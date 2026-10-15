import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final users = await context.read<PayrollRepository>().fetchUsers();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final blob =
          '${u['firstName']} ${u['lastName']} ${u['email']} ${u['designation']} ${u['role']}'
              .toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  int get _adminCount => _users
      .where((u) => u['role'] == 'HR_ADMIN' && u['status'] == 'ACTIVE')
      .length;

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return AppScaffold(
      title: 'People',
      floatingActionButton: ArkaAddFab(
        label: 'Add user',
        onPressed: () async {
          await context.push('/employees/add');
          if (mounted) _load();
        },
      ),
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search name, email, designation…',
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.groups_outlined,
                          label: '${_users.length} people',
                        ),
                        _InfoPill(
                          icon: Icons.admin_panel_settings_outlined,
                          label: '$_adminCount admin',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _users.isEmpty
                                      ? 'No users yet'
                                      : 'No matches',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _users.isEmpty
                                      ? 'Add an employee or someone with admin access (payroll & people).'
                                      : 'Try a different search.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: ArkaColors.muted),
                                ),
                                if (_users.isEmpty) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () => context.push('/employees/add'),
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Add first user'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final u = list[i];
                            final name = '${u['firstName']} ${u['lastName']}';
                            final hasStructure = u['salaryStructure'] != null;
                            final online = u['isOnline'] == true;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: ArkaColors.navy.withValues(alpha: 0.12),
                                      foregroundColor: ArkaColors.navy,
                                      child: Text(
                                        name.isEmpty ? '?' : name[0].toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              if (u.containsKey('isOnline'))
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: online
                                                        ? ArkaColors.success
                                                        : Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${u['email']}',
                                            style: const TextStyle(
                                              color: ArkaColors.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              ArkaRoleChip(
                                                RoleLabels.display(u['role'] as String?),
                                                tone: u['role'] == 'HR_ADMIN'
                                                    ? ArkaColors.teal
                                                    : null,
                                              ),
                                              ArkaRoleChip(
                                                u['designation'] as String? ??
                                                    'No designation',
                                              ),
                                              if (!hasStructure)
                                                const ArkaRoleChip(
                                                  'No salary',
                                                  tone: ArkaColors.warning,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const c = ArkaColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
