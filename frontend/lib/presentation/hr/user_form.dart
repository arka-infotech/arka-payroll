import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';

/// Controllers + state shared by Add user and Edit profile.
class UserFormData {
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final employeeCode = TextEditingController(text: 'AISS');
  final designation = TextEditingController();
  final pan = TextEditingController();
  final uan = TextEditingController();
  final aadhaar = TextEditingController();
  final bankName = TextEditingController();
  final bankAccount = TextEditingController();
  final bankIfsc = TextEditingController();
  final monthlyBase = TextEditingController();
  final travel = TextEditingController();
  final otherFixed = TextEditingController();
  final hra = TextEditingController(text: '0');
  final payDay = TextEditingController(text: '1');

  String role = 'EMPLOYEE';
  DateTime? doj;
  bool showAdvanced = false;
  bool enablePt = false;
  bool enableTds = false;

  List<TextEditingController> get _all => [
        email,
        password,
        firstName,
        lastName,
        employeeCode,
        designation,
        pan,
        uan,
        aadhaar,
        bankName,
        bankAccount,
        bankIfsc,
        monthlyBase,
        travel,
        otherFixed,
        hra,
        payDay,
      ];

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get monthlyGross =>
      _num(monthlyBase) +
      _num(travel) +
      _num(otherFixed) +
      (showAdvanced ? _num(hra) : 0);

  /// Loads an existing user from `GET /users/:id`.
  void fillFrom(Map<String, dynamic> user) {
    email.text = '${user['email'] ?? ''}';
    firstName.text = '${user['firstName'] ?? ''}';
    lastName.text = '${user['lastName'] ?? ''}';
    final code = '${user['employeeCode'] ?? ''}'.trim();
    employeeCode.text = code.isEmpty ? 'AISS' : code;
    designation.text = '${user['designation'] ?? ''}';
    role = user['role'] == 'HR_ADMIN' ? 'HR_ADMIN' : 'EMPLOYEE';
    final rawDoj = user['dateOfJoining']?.toString();
    if (rawDoj != null && rawDoj.length >= 10) {
      doj = DateTime.tryParse(rawDoj.substring(0, 10));
    }
    pan.text = '${user['pan'] ?? ''}';
    final u = '${user['uan'] ?? ''}';
    uan.text = u == 'N/A' ? '' : u;
    final a = '${user['aadhaar'] ?? ''}';
    aadhaar.text = a == 'N/A' ? '' : a;
    bankName.text = '${user['bankName'] ?? ''}';
    bankAccount.text = '${user['bankAccountNumber'] ?? ''}';
    bankIfsc.text = '${user['bankIfsc'] ?? ''}';

    final s = user['salaryStructure'] as Map<String, dynamic>?;
    if (s != null) {
      monthlyBase.text = _plain(parseApiNum(s['basicMonthly']));
      travel.text = _plain(parseApiNum(s['conveyanceMonthly']));
      otherFixed.text = _plain(parseApiNum(s['specialAllowanceMonthly']));
      final h = parseApiNum(s['hraMonthly']);
      hra.text = _plain(h);
      showAdvanced = h > 0;
      enablePt = s['professionalTaxApplicable'] == true;
      enableTds = s['tdsApplicable'] == true;
      payDay.text = '${parseApiNum(s['salaryCreditDay'], fallback: 1).toInt()}';
    }
  }

  static String _plain(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  Map<String, dynamic> profilePayload({required bool includePassword}) {
    final u = uan.text.trim();
    return {
      'email': email.text.trim(),
      if (includePassword && password.text.isNotEmpty)
        'password': password.text,
      'firstName': firstName.text.trim(),
      'lastName': lastName.text.trim(),
      'role': role,
      'employeeCode': employeeCode.text.trim().toUpperCase(),
      'designation': designation.text.trim(),
      'dateOfJoining': DateFormat('yyyy-MM-dd').format(doj!),
      'pan': pan.text.trim().toUpperCase(),
      'uan': u.isEmpty || u == 'N/A' ? 'N/A' : u,
      'aadhaar': aadhaar.text.trim().length == 12 ? aadhaar.text.trim() : 'N/A',
      'bankName': bankName.text.trim(),
      'bankAccountNumber': bankAccount.text.trim(),
      'bankIfsc': bankIfsc.text.trim().toUpperCase(),
    };
  }

  Map<String, dynamic> salaryPayload() {
    final h = showAdvanced ? _num(hra) : 0;
    return {
      'annualCtc': monthlyGross * 12,
      'basicMonthly': _num(monthlyBase),
      'hraMonthly': h,
      'specialAllowanceMonthly': _num(otherFixed),
      'conveyanceMonthly': _num(travel),
      'medicalMonthly': 0,
      'epfApplicable': false,
      'esicApplicable': false,
      'flexBreakup': true,
      'professionalTaxApplicable': enablePt,
      'tdsApplicable': enableTds,
      'taxRegime': 'NEW',
      'salaryCreditDay': int.tryParse(payDay.text.trim())?.clamp(1, 28) ?? 1,
      'effectiveFrom': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };
  }
}

// ── Validators ──────────────────────────────────────────────────────────────

class UserValidators {
  static String? required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  static String? email(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? pan(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return 'Required';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(t)) {
      return 'Format: ABCDE1234F';
    }
    return null;
  }

  static String? ifsc(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return 'Required';
    if (t.length != 11) return 'IFSC must be 11 characters';
    return null;
  }

  static String? employeeCode(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return 'Required';
    if (!t.startsWith('AISS') || t.length <= 4) {
      return 'Must start with AISS (e.g. AISS001)';
    }
    return null;
  }

  static String? positiveAmount(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null || n <= 0) return 'Enter an amount above 0';
    return null;
  }

  static String? payDay(String? v) {
    final d = int.tryParse(v ?? '');
    if (d == null || d < 1 || d > 28) return 'Enter a day from 1 to 28';
    return null;
  }
}

/// Validates [form]; on failure scrolls the first invalid field into view.
bool validateAndReveal(GlobalKey<FormState> form) {
  final invalid = form.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  Scrollable.ensureVisible(
    invalid.first.context,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
    alignment: 0.2,
  );
  return false;
}

// ── Sections ────────────────────────────────────────────────────────────────

class AccountSection extends StatefulWidget {
  const AccountSection(
      {super.key,
      required this.form,
      required this.isNew,
      required this.onChanged});

  final UserFormData form;
  final bool isNew;
  final VoidCallback onChanged;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return ArkaFormSection(
      icon: Icons.key_rounded,
      title: 'Account & access',
      subtitle: widget.isNew
          ? 'How they sign in to AIPS'
          : 'Leave password blank to keep the current one',
      children: [
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Work email *',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: UserValidators.email,
            ),
            TextFormField(
              controller: f.password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: widget.isNew
                    ? 'Temporary password *'
                    : 'New password (optional)',
                helperText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show' : 'Hide',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) {
                if (!widget.isNew && (v == null || v.isEmpty)) return null;
                return v == null || v.length < 8
                    ? 'At least 8 characters'
                    : null;
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Access level', style: context.tt.labelMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'EMPLOYEE',
                icon: Icon(Icons.badge_outlined),
                label: Text('Employee')),
            ButtonSegment(
                value: 'HR_ADMIN',
                icon: Icon(Icons.admin_panel_settings_outlined),
                label: Text('Admin')),
          ],
          selected: {f.role},
          onSelectionChanged: (s) {
            f.role = s.first;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 6),
        Text(
          f.role == 'HR_ADMIN'
              ? 'Admins can manage people, punch salary and download any payslip.'
              : 'Employees only see their own payslips.',
          style: context.tt.bodySmall,
        ),
      ],
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection(
      {super.key, required this.form, required this.onChanged});

  final UserFormData form;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: form.doj ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'Date of joining',
    );
    if (picked != null) {
      form.doj = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = form;
    return ArkaFormSection(
      icon: Icons.person_outline_rounded,
      title: 'Profile',
      subtitle: 'Printed on every payslip',
      children: [
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.firstName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'First name *'),
              validator: UserValidators.required,
            ),
            TextFormField(
              controller: f.lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Last name *'),
              validator: UserValidators.required,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.designation,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Designation *'),
              validator: UserValidators.required,
            ),
            TextFormField(
              controller: f.employeeCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Employee ID *',
                helperText: 'Starts with AISS, e.g. AISS001',
              ),
              validator: UserValidators.employeeCode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ArkaDateField(
          label: 'Date of joining *',
          value: f.doj,
          required: true,
          onPick: () => _pick(context),
        ),
      ],
    );
  }
}

class BankSection extends StatelessWidget {
  const BankSection({super.key, required this.form});

  final UserFormData form;

  @override
  Widget build(BuildContext context) {
    final f = form;
    return ArkaFormSection(
      icon: Icons.account_balance_outlined,
      title: 'Bank details',
      subtitle: 'Where salary is credited',
      children: [
        TextFormField(
          controller: f.bankName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Bank name *'),
          validator: UserValidators.required,
        ),
        const SizedBox(height: 12),
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.bankAccount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Account number *'),
              validator: UserValidators.required,
            ),
            TextFormField(
              controller: f.bankIfsc,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(labelText: 'IFSC *'),
              validator: UserValidators.ifsc,
            ),
          ],
        ),
      ],
    );
  }
}

class StatutorySection extends StatelessWidget {
  const StatutorySection({super.key, required this.form});

  final UserFormData form;

  @override
  Widget build(BuildContext context) {
    final f = form;
    return ArkaFormSection(
      icon: Icons.verified_user_outlined,
      title: 'Statutory IDs',
      subtitle: 'Blank UAN / Aadhaar are saved as N/A',
      children: [
        TextFormField(
          controller: f.pan,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(labelText: 'PAN *'),
          validator: UserValidators.pan,
        ),
        const SizedBox(height: 12),
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.uan,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: const InputDecoration(labelText: 'UAN'),
            ),
            TextFormField(
              controller: f.aadhaar,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: const InputDecoration(labelText: 'Aadhaar'),
            ),
          ],
        ),
      ],
    );
  }
}

class PayPackageSection extends StatelessWidget {
  const PayPackageSection(
      {super.key, required this.form, required this.onChanged});

  final UserFormData form;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final f = form;
    final amount = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ];
    final gross = f.monthlyGross;

    return ArkaFormSection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Pay package',
      subtitle:
          'Fixed monthly amounts — variables are added when you punch salary',
      children: [
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.monthlyBase,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amount,
              decoration: const InputDecoration(
                  labelText: 'Base / in-hand salary *', prefixText: '₹ '),
              validator: UserValidators.positiveAmount,
              onChanged: (_) => onChanged(),
            ),
            TextFormField(
              controller: f.travel,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amount,
              decoration: const InputDecoration(
                  labelText: 'Travel allowance', prefixText: '₹ '),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ArkaFieldRow(
          children: [
            TextFormField(
              controller: f.otherFixed,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amount,
              decoration: const InputDecoration(
                labelText: 'Other fixed',
                helperText: 'Phone, internet, etc.',
                prefixText: '₹ ',
              ),
              onChanged: (_) => onChanged(),
            ),
            TextFormField(
              controller: f.payDay,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2)
              ],
              decoration: const InputDecoration(
                labelText: 'Salary credit day *',
                helperText: 'Draft slip auto-creates on this day (1–28)',
              ),
              validator: UserValidators.payDay,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Advanced breakup', style: context.tt.titleSmall),
          subtitle:
              Text('HRA, professional tax, TDS', style: context.tt.bodySmall),
          value: f.showAdvanced,
          onChanged: (v) {
            f.showAdvanced = v;
            onChanged();
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: f.showAdvanced
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: f.hra,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: amount,
                      decoration: const InputDecoration(
                          labelText: 'HRA', prefixText: '₹ '),
                      onChanged: (_) => onChanged(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Maharashtra professional tax',
                          style: context.tt.bodyMedium),
                      value: f.enablePt,
                      onChanged: (v) {
                        f.enablePt = v;
                        onChanged();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Income tax (TDS) estimate',
                          style: context.tt.bodyMedium),
                      value: f.enableTds,
                      onChanged: (v) {
                        f.enableTds = v;
                        onChanged();
                      },
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cs.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Figure(label: 'Monthly gross', value: Fmt.inr(gross)),
              ),
              Container(width: 1, height: 36, color: context.cs.outlineVariant),
              const SizedBox(width: 16),
              Expanded(
                child:
                    _Figure(label: 'Annual CTC', value: Fmt.inr0(gross * 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fg = context.cs.onSecondaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.labelMedium?.copyWith(color: fg)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: context.tt.titleLarge?.copyWith(color: fg)),
        ),
      ],
    );
  }
}

/// Centers forms at a comfortable reading width on desktop.
class FormWidth extends StatelessWidget {
  const FormWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880), child: child),
    );
  }
}
