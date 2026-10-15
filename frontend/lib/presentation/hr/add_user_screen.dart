import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/network/api_client.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _scroll = ScrollController();
  final _profileFormKey = GlobalKey<FormState>();
  final _salaryFormKey = GlobalKey<FormState>();

  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _firstNameKey = GlobalKey();
  final _monthlyBaseKey = GlobalKey();

  int _step = 0;
  bool _busy = false;
  String? _bannerError;
  String? _createdUserId;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _employeeCode = TextEditingController();
  final _designation = TextEditingController();
  String _role = 'EMPLOYEE';
  DateTime? _doj;

  final _pan = TextEditingController();
  final _uan = TextEditingController();
  final _aadhaar = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _bankIfsc = TextEditingController();

  final _monthlyBase = TextEditingController();
  final _travel = TextEditingController();
  final _otherFixed = TextEditingController();
  final _hraOptional = TextEditingController(text: '0');
  bool _showAdvanced = false;
  bool _enablePt = false;
  bool _enableTds = false;
  bool _skipStructure = false;
  final _payDay = TextEditingController(text: '1');

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [
      _email, _password, _firstName, _lastName, _employeeCode, _designation,
      _pan, _uan, _aadhaar, _bankName, _bankAccount, _bankIfsc,
      _monthlyBase, _travel, _otherFixed, _hraOptional, _payDay,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  Map<String, dynamic> _salaryPayload() {
    final base = _num(_monthlyBase);
    final travel = _num(_travel);
    final other = _num(_otherFixed);
    final hra = _showAdvanced ? _num(_hraOptional) : 0;
    final monthly = base + travel + other + hra;
    return {
      'annualCtc': monthly * 12,
      'basicMonthly': base,
      'hraMonthly': hra,
      'specialAllowanceMonthly': other,
      'conveyanceMonthly': travel,
      'medicalMonthly': 0,
      'epfApplicable': false,
      'esicApplicable': false,
      'flexBreakup': true,
      'professionalTaxApplicable': _enablePt,
      'tdsApplicable': _enableTds,
      'taxRegime': 'NEW',
      'salaryCreditDay':
          int.tryParse(_payDay.text.trim())?.clamp(1, 28) ?? 1,
      'effectiveFrom': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
  }

  String? _optionalPan(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(t)) {
      return 'PAN format: ABCDE1234F';
    }
    return null;
  }

  String? _optionalIfsc(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return null;
    if (t.length != 11) return 'IFSC must be 11 characters';
    return null;
  }

  Future<void> _pickDoj() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _doj ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) setState(() => _doj = picked);
  }

  Future<void> _createUser() async {
    setState(() {
      _bannerError = null;
      _autoValidate = AutovalidateMode.always;
    });
    if (!_profileFormKey.currentState!.validate()) {
      _scrollTo(_emailKey);
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'email': _email.text.trim(),
        'password': _password.text,
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'role': _role,
        if (_employeeCode.text.trim().isNotEmpty)
          'employeeCode': _employeeCode.text.trim(),
        if (_designation.text.trim().isNotEmpty)
          'designation': _designation.text.trim(),
        if (_doj != null)
          'dateOfJoining': DateFormat('yyyy-MM-dd').format(_doj!),
        if (_pan.text.trim().isNotEmpty) 'pan': _pan.text.trim().toUpperCase(),
        if (_uan.text.trim().isNotEmpty) 'uan': _uan.text.trim(),
        if (_aadhaar.text.trim().length == 12) 'aadhaar': _aadhaar.text.trim(),
        if (_bankName.text.trim().isNotEmpty) 'bankName': _bankName.text.trim(),
        if (_bankAccount.text.trim().isNotEmpty)
          'bankAccountNumber': _bankAccount.text.trim(),
        if (_bankIfsc.text.trim().length == 11)
          'bankIfsc': _bankIfsc.text.trim().toUpperCase(),
      };

      final created =
          await context.read<PayrollRepository>().createUser(body);
      _createdUserId = created['id'] as String?;
      if (!mounted) return;
      _password.clear();
      setState(() => _step = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${created['firstName']} ${created['lastName']}',
          ),
        ),
      );
    } on ApiException catch (e) {
      _handleCreateError(apiErrorMessage(e));
    } catch (e) {
      _handleCreateError(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleCreateError(String msg) {
    setState(() {
      _bannerError = msg;
      _password.clear();
    });
    final lower = msg.toLowerCase();
    if (lower.contains('email')) {
      setState(() => _step = 0);
      _scrollTo(_emailKey);
    } else if (lower.contains('password')) {
      setState(() => _step = 0);
      _scrollTo(_passwordKey);
    } else if (lower.contains('pan')) {
      setState(() => _step = 0);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveStructure() async {
    if (_skipStructure || _createdUserId == null) {
      if (mounted) context.go('/employees');
      return;
    }
    setState(() {
      _bannerError = null;
      _autoValidate = AutovalidateMode.always;
    });
    if (!_salaryFormKey.currentState!.validate()) {
      _scrollTo(_monthlyBaseKey);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<PayrollRepository>().upsertSalaryStructure(
            _createdUserId!,
            _salaryPayload(),
          );
      if (!mounted) return;
      context.go('/employees');
    } on ApiException catch (e) {
      final msg = apiErrorMessage(e);
      setState(() => _bannerError = msg);
      _scrollTo(_monthlyBaseKey);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      final msg = apiErrorMessage(e);
      setState(() => _bannerError = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _step == 0 ? 'Add user' : 'Pay package',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bannerError != null) ...[
            ArkaErrorBanner(
              message: _bannerError!,
              onDismiss: () => setState(() => _bannerError = null),
            ),
            const SizedBox(height: 12),
          ],
          _StepHeader(step: _step),
          const SizedBox(height: 16),
          Expanded(
            child: Form(
              key: _step == 0 ? _profileFormKey : _salaryFormKey,
              autovalidateMode: _autoValidate,
              child: ListView(
                controller: _scroll,
                children: [
                  if (_step == 0) ..._identityStep(),
                  if (_step == 1) ..._structureStep(),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : (_step == 0 ? _createUser : _saveStructure),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step == 0 ? 'Create user' : 'Save pay package'),
                  ),
                  if (_step == 1)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _skipStructure = true);
                              context.go('/employees');
                            },
                      child: const Text('Skip — set pay later'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _identityStep() {
    return [
      _SectionCard(
        title: 'Account',
        children: [
          KeyedSubtree(
            key: _emailKey,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Work email *'),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Valid email required' : null,
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _passwordKey,
            child: TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary password *',
                helperText: 'Min 8 characters',
              ),
              validator: (v) =>
                  v == null || v.length < 8 ? 'Min 8 characters' : null,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Access *'),
            items: const [
              DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee')),
              DropdownMenuItem(value: 'HR_ADMIN', child: Text('Admin access')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Profile',
        children: [
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: _firstNameKey,
                  child: TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _designation,
            decoration: const InputDecoration(labelText: 'Designation'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeCode,
            decoration: const InputDecoration(labelText: 'Employee code'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of joining'),
            subtitle: Text(
              _doj == null
                  ? 'Optional'
                  : DateFormat('dd MMM yyyy').format(_doj!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDoj,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Bank (optional)',
        children: [
          TextFormField(
            controller: _bankName,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankAccount,
            decoration: const InputDecoration(labelText: 'Account number'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankIfsc,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'IFSC'),
            validator: _optionalIfsc,
            inputFormatters: [LengthLimitingTextInputFormatter(11)],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Statutory IDs (optional — leave blank for small teams)',
        children: [
          TextFormField(
            controller: _pan,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'PAN'),
            validator: _optionalPan,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _uan,
            decoration: const InputDecoration(labelText: 'UAN'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _aadhaar,
            decoration: const InputDecoration(labelText: 'Aadhaar'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _structureStep() {
    final preview = _salaryPayload();
    final monthly = (preview['annualCtc'] as num) / 12;

    return [
      Text(
        'Simple monthly package — no forced HRA or statutory deductions for small teams. '
        'Net pay on punch will match gross unless you enable PT/TDS below.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ArkaColors.muted,
              height: 1.35,
            ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Monthly components',
        children: [
          KeyedSubtree(
            key: _monthlyBaseKey,
            child: TextFormField(
              controller: _monthlyBase,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Base / in-hand salary (₹) *',
                helperText: 'Fixed monthly amount before variable punch',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive amount';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _travel,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Travel / conveyance (₹)',
              helperText: 'Optional fixed travel allowance',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherFixed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Other fixed (₹)',
              helperText: 'Phone, internet, etc.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _payDay,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Salary credit day (1–28)',
              helperText: 'Auto draft slip from this day each month if not punched',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final d = int.tryParse(v ?? '');
              if (d == null || d < 1 || d > 28) return 'Enter 1–28';
              return null;
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show advanced breakup'),
            subtitle: const Text('HRA, professional tax, TDS'),
            value: _showAdvanced,
            onChanged: (v) => setState(() => _showAdvanced = v),
          ),
          if (_showAdvanced) ...[
            TextFormField(
              controller: _hraOptional,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'HRA (₹) — optional'),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Maharashtra professional tax'),
              value: _enablePt,
              onChanged: (v) => setState(() => _enablePt = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Income tax (TDS) estimate'),
              value: _enableTds,
              onChanged: (v) => setState(() => _enableTds = v),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ArkaColors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Monthly gross: ₹${monthly.toStringAsFixed(2)} · Annual: ₹${(preview['annualCtc'] as num).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ];
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(active: step == 0, done: step > 0, label: 'Profile'),
        Expanded(child: Divider(color: Colors.grey.shade400)),
        _Dot(active: step == 1, done: false, label: 'Pay'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.active,
    required this.done,
    required this.label,
  });

  final bool active;
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? ArkaColors.success
        : active
            ? ArkaColors.teal
            : Colors.grey.shade300;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: bg,
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: 14,
            color: active || done ? Colors.white : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms);
  }
}
