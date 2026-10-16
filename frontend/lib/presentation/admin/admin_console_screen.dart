import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ArkaSnack.success(context, done);
      invalidatePayrollData(ref);
      ref.invalidate(auditLogProvider);
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    }
  }

  Future<void> _ban(Map<String, dynamic> u) async {
    final name = '${u['firstName']} ${u['lastName']}';
    final ok = await confirmArka(
      context,
      title: 'Ban $name?',
      message: 'They will be signed out and blocked until you unban them.',
      confirmLabel: 'Ban',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok) return;
    final api = ref.read(authRepositoryProvider).api;
    await _run(
      () => api.post('/users/${u['id']}/ban',
          body: {'reason': 'Banned by an administrator'}),
      '$name has been banned',
    );
  }

  Future<void> _unban(Map<String, dynamic> u) async {
    final api = ref.read(authRepositoryProvider).api;
    await _run(() => api.post('/users/${u['id']}/unban'),
        '${u['firstName']} can sign in again');
  }

  Future<void> _remove(Map<String, dynamic> u) async {
    final name = '${u['firstName']} ${u['lastName']}';
    final ok = await confirmArka(
      context,
      title: 'Remove $name?',
      message: 'This permanently deletes the account. This can’t be undone.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok) return;
    final api = ref.read(authRepositoryProvider).api;
    await _run(() => api.delete('/users/${u['id']}'), '$name was removed');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Root console',
        subtitle: 'Live presence, access control and audit trail',
        floatingActionButton: ArkaAddFab(
          label: 'Add user',
          onPressed: () => context.push('/employees/add'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cs.outlineVariant),
              ),
              child: const TabBar(
                tabs: [
                  Tab(height: 42, icon: null, text: 'Users & presence'),
                  Tab(height: 42, text: 'Audit log'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _UsersTab(onBan: _ban, onUnban: _unban, onRemove: _remove),
                  const _AuditTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab(
      {required this.onBan, required this.onUnban, required this.onRemove});

  final ValueChanged<Map<String, dynamic>> onBan;
  final ValueChanged<Map<String, dynamic>> onUnban;
  final ValueChanged<Map<String, dynamic>> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return ArkaAsync<List<Map<String, dynamic>>>(
      value: users,
      onRetry: () => ref.invalidate(adminUsersProvider),
      loading: const ArkaSkeletonList(count: 4, header: false),
      data: (list) {
        if (list.isEmpty) {
          return const ArkaEmptyState(
            icon: Icons.group_outlined,
            title: 'No users',
            message: 'Add someone with the button below.',
          );
        }
        final online = list.where((u) => u['isOnline'] == true).length;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(adminUsersProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  ArkaStatusChip('$online online',
                      tone: ArkaTone.success, dot: true),
                  const SizedBox(width: 8),
                  ArkaStatusChip('${list.length - online} offline', dot: true),
                ],
              ),
              const SizedBox(height: 12),
              ArkaAdaptiveGrid(
                minItemWidth: 360,
                maxColumns: 2,
                gap: 10,
                children: [
                  for (final u in list)
                    _UserCard(
                      user: u,
                      onBan: () => onBan(u),
                      onUnban: () => onUnban(u),
                      onRemove: () => onRemove(u),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard(
      {required this.user,
      required this.onBan,
      required this.onUnban,
      required this.onRemove});

  final Map<String, dynamic> user;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    final online = u['isOnline'] == true;
    final banned = u['status'] == 'BANNED';

    return ArkaCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        children: [
          ArkaAvatar(name.isEmpty ? '?' : name, size: 46, online: online),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall),
                const SizedBox(height: 2),
                Text('${u['email']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ArkaStatusChip(RoleLabels.display(u['role'] as String?),
                        tone: u['role'] == 'HR_ADMIN'
                            ? ArkaTone.primary
                            : ArkaTone.neutral),
                    if (banned)
                      const ArkaStatusChip('Banned',
                          tone: ArkaTone.danger, icon: Icons.block_rounded)
                    else
                      ArkaStatusChip(online ? 'Online' : 'Offline',
                          tone: online ? ArkaTone.success : ArkaTone.neutral,
                          dot: true),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) => switch (v) {
              'ban' => onBan(),
              'unban' => onUnban(),
              _ => onRemove(),
            },
            itemBuilder: (ctx) => [
              if (banned)
                const PopupMenuItem(
                  value: 'unban',
                  child: ListTile(
                      leading: Icon(Icons.lock_open_rounded),
                      title: Text('Unban')),
                )
              else
                const PopupMenuItem(
                  value: 'ban',
                  child: ListTile(
                      leading: Icon(Icons.block_rounded), title: Text('Ban')),
                ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading:
                      Icon(Icons.delete_outline_rounded, color: ctx.cs.error),
                  title: Text('Remove', style: TextStyle(color: ctx.cs.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(auditLogProvider);
    final fmt = DateFormat('dd MMM, HH:mm');
    return ArkaAsync<List<Map<String, dynamic>>>(
      value: audit,
      onRetry: () => ref.invalidate(auditLogProvider),
      loading: const ArkaSkeletonList(count: 6, itemHeight: 56, header: false),
      data: (list) {
        if (list.isEmpty) {
          return const ArkaEmptyState(
            icon: Icons.history_rounded,
            title: 'Nothing logged yet',
            message:
                'Sign-ins, payroll locks and profile changes will show up here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(auditLogProvider.future),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(indent: 64),
              itemBuilder: (context, i) {
                final a = list[i];
                final when = DateTime.tryParse('${a['createdAt']}');
                return ListTile(
                  leading: ArkaIconBadge(_auditIcon('${a['action']}'),
                      tone: ArkaTone.info, size: 36),
                  title: Text('${a['summary']}', style: context.tt.bodyMedium),
                  subtitle: Text(
                    [
                      '${a['actorEmail'] ?? 'system'}',
                      if (when != null) fmt.format(when.toLocal()),
                    ].join(' · '),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  IconData _auditIcon(String action) {
    final a = action.toUpperCase();
    if (a.contains('LOGIN')) return Icons.login_rounded;
    if (a.contains('LOCK') || a.contains('PROCESS')) return Icons.lock_rounded;
    if (a.contains('BAN')) return Icons.block_rounded;
    if (a.contains('DELETE') || a.contains('REMOVE')) {
      return Icons.delete_outline_rounded;
    }
    if (a.contains('CREATE')) return Icons.person_add_alt_1_rounded;
    return Icons.edit_note_rounded;
  }
}
