import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/hr/user_form.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _form = UserFormData();
  final _profileKey = GlobalKey<FormState>();
  final _payKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  int _step = 0;
  bool _busy = false;
  Object? _error;
  String? _createdUserId;
  String? _createdName;

  @override
  void dispose() {
    _form.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    setState(() => _error = e);
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _createUser() async {
    setState(() => _error = null);
    if (!validateAndReveal(_profileKey)) return;
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(payrollRepositoryProvider)
          .createUser(_form.profilePayload(includePassword: true));
      if (!mounted) return;
      _createdUserId = created['id'] as String?;
      _createdName = '${created['firstName']} ${created['lastName']}';
      _form.password.clear();
      invalidatePayrollData(ref);
      setState(() => _step = 1);
      _scroll.jumpTo(0);
      ArkaSnack.success(
          context, '$_createdName added — now set their pay package');
    } catch (e) {
      final msg = apiErrorMessage(e).toLowerCase();
      if (msg.contains('password')) _form.password.clear();
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePackage() async {
    if (_createdUserId == null) {
      context.go('/employees');
      return;
    }
    setState(() => _error = null);
    if (!validateAndReveal(_payKey)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(payrollRepositoryProvider)
          .upsertSalaryStructure(_createdUserId!, _form.salaryPayload());
      if (!mounted) return;
      invalidatePayrollData(ref);
      ArkaSnack.success(context, 'Pay package saved for $_createdName');
      context.go('/employees');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _step == 0;

    return AppScaffold(
      title: first ? 'Add user' : 'Pay package',
      subtitle: first
          ? 'Create a sign-in and payroll profile'
          : 'Fixed monthly salary for $_createdName',
      showNav: false,
      bottomBar: ArkaBottomBar(
        children: [
          OutlinedButton(
            onPressed: _busy
                ? null
                : first
                    ? () => context.pop()
                    : () => context.go('/employees'),
            child: Text(first ? 'Cancel' : 'Set up later'),
          ),
          FilledButton(
            onPressed: _busy ? null : (first ? _createUser : _savePackage),
            child: ArkaBusyLabel(
              busy: _busy,
              label: first ? 'Create user' : 'Save pay package',
              icon: first ? Icons.arrow_forward_rounded : Icons.check_rounded,
            ),
          ),
        ],
      ),
      child: FormWidth(
        child: Form(
          key: first ? _profileKey : _payKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              _Steps(step: _step),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ArkaInlineAlert.fromError(_error!,
                    onDismiss: () => setState(() => _error = null)),
                const SizedBox(height: 16),
              ],
              if (first) ...[
                AccountSection(
                    form: _form, isNew: true, onChanged: () => setState(() {})),
                const SizedBox(height: 14),
                ProfileSection(form: _form, onChanged: () => setState(() {})),
                const SizedBox(height: 14),
                BankSection(form: _form),
                const SizedBox(height: 14),
                StatutorySection(form: _form),
              ] else
                PayPackageSection(
                    form: _form, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _Step(index: 0, label: 'Profile & bank', current: step)),
        const SizedBox(width: 10),
        Expanded(child: _Step(index: 1, label: 'Pay package', current: step)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.index, required this.label, required this.current});

  final int index;
  final String label;
  final int current;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final done = current > index;
    final active = current == index;
    final color = done
        ? context.palette.success
        : active
            ? cs.secondary
            : cs.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 5,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_checked_rounded,
              size: 18,
              color: done || active ? color : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Step ${index + 1} · $label',
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelMedium?.copyWith(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
