import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/hr/user_form.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/shell/main_tab_shell.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

/// Employee completes bank / statutory details (admin only sets profile + login).
class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  final _form = UserFormData();
  final _key = GlobalKey<FormState>();
  bool _busy = false;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = ref.read(authStateProvider).user;
      if (me == null) return;
      final user =
          await ref.read(payrollRepositoryProvider).fetchMyProfile();
      if (!mounted) return;
      _form.fillFrom(user);
      setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    if (!validateAndReveal(_key)) return;
    final me = ref.read(authStateProvider).user;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(payrollRepositoryProvider).updateMyProfile({
        'bankName': _form.bankName.text.trim(),
        'bankAccountNumber': _form.bankAccount.text.trim(),
        'bankIfsc': _form.bankIfsc.text.trim().toUpperCase(),
        'pan': _form.pan.text.trim().toUpperCase(),
        'uan': _form.uan.text.trim().isEmpty ? 'N/A' : _form.uan.text.trim(),
        'aadhaar': _form.aadhaar.text.trim().length == 12
            ? _form.aadhaar.text.trim()
            : 'N/A',
      });
      if (!mounted) return;
      ArkaSnack.success(context, 'Profile saved');
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = !_loaded && _error == null
        ? const FormWidth(child: ArkaSkeletonList(count: 3, itemHeight: 140))
        : _error != null
            ? ArkaErrorView(error: _error!, onRetry: _load)
            : FormWidth(
                child: Form(
                  key: _key,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    children: [
                      const ArkaInlineAlert(
                        tone: ArkaAlertTone.info,
                        title: 'Complete your details',
                        message:
                            'Bank and tax IDs are used on your payslip. Name and employee ID are managed by HR.',
                      ),
                      const SizedBox(height: 14),
                      BankSection(form: _form),
                      const SizedBox(height: 14),
                      StatutorySection(form: _form),
                    ],
                  ),
                ),
              );

    final scaffold = widget.embedded
        ? EmbeddedScaffold(
            title: 'My profile',
            subtitle: 'Bank & statutory details',
            bottomBar: ArkaBottomBar(
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: ArkaBusyLabel(
                    busy: _busy,
                    label: 'Save details',
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
            child: body,
          )
        : AppScaffold(
            title: 'My profile',
            showNav: false,
            bottomBar: ArkaBottomBar(
              children: [
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: ArkaBusyLabel(
                    busy: _busy,
                    label: 'Save details',
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
            child: body,
          );

    return scaffold;
  }
}
