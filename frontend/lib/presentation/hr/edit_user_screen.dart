import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/role_labels.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/hr/user_form.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

/// Edit a person's profile, optional password, and pay package.
class EditUserScreen extends ConsumerStatefulWidget {
  const EditUserScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _form = UserFormData();
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  Map<String, dynamic>? _user;
  Object? _loadError;
  Object? _saveError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _form.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final user =
          await ref.read(payrollRepositoryProvider).fetchUser(widget.userId);
      if (!mounted) return;
      _form.fillFrom(user);
      setState(() => _user = user);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    if (!validateAndReveal(_formKey)) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(payrollRepositoryProvider);
      await repo.updateUser(
          widget.userId, _form.profilePayload(includePassword: true));
      await repo.upsertSalaryStructure(widget.userId, _form.salaryPayload());
      if (!mounted) return;
      invalidatePayrollData(ref);
      ArkaSnack.success(context, 'Profile updated');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = e);
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    Widget body;
    if (_loadError != null) {
      body = ArkaErrorView(error: _loadError!, onRetry: _load);
    } else if (user == null) {
      body = const FormWidth(
          child: ArkaSkeletonList(count: 4, itemHeight: 180, header: true));
    } else {
      body = FormWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 16),
              if (_saveError != null) ...[
                ArkaInlineAlert.fromError(_saveError!,
                    onDismiss: () => setState(() => _saveError = null)),
                const SizedBox(height: 16),
              ],
              AccountSection(
                  form: _form, isNew: false, onChanged: () => setState(() {})),
              const SizedBox(height: 14),
              ProfileSection(form: _form, onChanged: () => setState(() {})),
              const SizedBox(height: 14),
              BankSection(form: _form),
              const SizedBox(height: 14),
              StatutorySection(form: _form),
              const SizedBox(height: 14),
              PayPackageSection(form: _form, onChanged: () => setState(() {})),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Edit profile',
      subtitle: 'Update details, access and pay package',
      showNav: false,
      bottomBar: user == null
          ? null
          : ArkaBottomBar(
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: ArkaBusyLabel(
                      busy: _busy,
                      label: 'Save changes',
                      icon: Icons.check_rounded),
                ),
              ],
            ),
      child: body,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final isAdmin = user['role'] == 'HR_ADMIN';
    final doj = DateTime.tryParse('${user['dateOfJoining'] ?? ''}');
    final hasPay = user['salaryStructure'] != null;

    return ArkaCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ArkaAvatar(name.isEmpty ? '?' : name, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unnamed' : name,
                    style: context.tt.titleLarge),
                const SizedBox(height: 2),
                Text('${user['email'] ?? ''}', style: context.tt.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ArkaStatusChip(
                      RoleLabels.display(user['role'] as String?),
                      tone: isAdmin ? ArkaTone.primary : ArkaTone.neutral,
                    ),
                    if ('${user['employeeCode'] ?? ''}'.isNotEmpty)
                      ArkaStatusChip('${user['employeeCode']}',
                          icon: Icons.tag_rounded),
                    if (doj != null)
                      ArkaStatusChip(
                        'Joined ${DateFormat('MMM yyyy').format(doj)}',
                        icon: Icons.event_rounded,
                      ),
                    ArkaStatusChip(
                      hasPay ? 'Pay package set' : 'No pay package',
                      tone: hasPay ? ArkaTone.success : ArkaTone.warning,
                      dot: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
