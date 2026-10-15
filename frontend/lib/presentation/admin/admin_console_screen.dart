import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _users = [];
  List<dynamic> _audit = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthRepository>().api;
      final users = await api.get('/users') as List<dynamic>;
      final audit =
          await api.get('/audit', query: {'limit': '100'}) as List<dynamic>;
      setState(() {
        _users = users;
        _audit = audit;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ban(String id) async {
    final api = context.read<AuthRepository>().api;
    await api.post('/users/$id/ban', body: {'reason': 'Banned by Super Admin'});
    await _load();
  }

  Future<void> _unban(String id) async {
    final api = context.read<AuthRepository>().api;
    await api.post('/users/$id/unban');
    await _load();
  }

  Future<void> _remove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove user?'),
        content: const Text('This permanently deletes the account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<AuthRepository>().api;
    await api.delete('/users/$id');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Root console',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employees/add'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Users & presence'),
              Tab(text: 'Audit log'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : TabBarView(
                        controller: _tabs,
                        children: [_usersTab(), _auditTab()],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _usersTab() {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = _users[i] as Map<String, dynamic>;
        final online = u['isOnline'] == true;
        final banned = u['status'] == 'BANNED';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: online ? Colors.green : Colors.grey,
              radius: 8,
            ),
            title: Text('${u['firstName']} ${u['lastName']}'),
            subtitle: Text(
              '${u['email']} · ${u['role']} · ${online ? 'Online' : 'Offline'}'
              '${banned ? ' · BANNED' : ''}',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (!banned)
                  TextButton(
                    onPressed: () => _ban(u['id'] as String),
                    child: const Text('Ban'),
                  ),
                if (banned)
                  TextButton(
                    onPressed: () => _unban(u['id'] as String),
                    child: const Text('Unban'),
                  ),
                TextButton(
                  onPressed: () => _remove(u['id'] as String),
                  child: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _auditTab() {
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12),
      itemCount: _audit.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = _audit[i] as Map<String, dynamic>;
        final when = DateTime.tryParse('${a['createdAt']}');
        return ListTile(
          dense: true,
          title: Text('${a['summary']}'),
          subtitle: Text(
            '${a['actorEmail'] ?? 'system'} · ${a['action']} · ${a['entity']}'
            '${when != null ? ' · ${fmt.format(when.toLocal())}' : ''}',
          ),
        );
      },
    );
  }
}
