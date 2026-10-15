import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/network/api_client.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class PunchSalaryScreen extends StatefulWidget {
  const PunchSalaryScreen({super.key, this.initialUserId, this.initialYear, this.initialMonth});

  final String? initialUserId;
  final int? initialYear;
  final int? initialMonth;

  @override
  State<PunchSalaryScreen> createState() => _PunchSalaryScreenState();
}

class _PunchSalaryScreenState extends State<PunchSalaryScreen> {
  late int _year;
  late int _month;
  List<PayrollGridRow> _employees = [];
  PayrollGridRow? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _daysWarning;
  double? _liveLopEstimate;

  final _daysCtrl = TextEditingController();
  final _lopCtrl = TextEditingController(text: '0');
  final _bonusCtrl = TextEditingController(text: '0');
  final _arrearsCtrl = TextEditingController(text: '0');
  final _slipNotesCtrl = TextEditingController();
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = widget.initialYear ?? now.year;
    _month = widget.initialMonth ?? now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _lopCtrl.dispose();
    _bonusCtrl.dispose();
    _arrearsCtrl.dispose();
    _slipNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await context.read<PayrollRepository>().fetchGrid(_year, _month);
      setState(() {
        _employees = rows;
        final deepLink = widget.initialUserId;
        _selected = rows.isEmpty
            ? null
            : rows.firstWhere(
                (e) =>
                    e.userId ==
                    (deepLink ?? _selected?.userId ?? rows.first.userId),
                orElse: () => rows.first,
              );
        _syncFieldsFromSelected();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _syncFieldsFromSelected() {
    final s = _selected;
    if (s == null) return;
    _daysCtrl.text = '${s.workingDaysInMonth}';
    _lopCtrl.text = '${s.unpaidLeaveDays}';
    _bonusCtrl.text = s.bonus == 0 ? '0' : s.bonus.toStringAsFixed(0);
    _arrearsCtrl.text =
        s.otherEarnings == 0 ? '0' : s.otherEarnings.toStringAsFixed(0);
    _slipNotesCtrl.text = s.slipNotes ?? '';
    _validateDays();
    _recalcLop();
  }

  void _validateDays() {
    final s = _selected;
    if (s == null) return;
    final days = int.tryParse(_daysCtrl.text) ?? 0;
    setState(() {
      if (days > s.calendarDaysInMonth) {
        _daysWarning =
            'Exceeds ${_monthName(_month)} $_year capacity (${s.calendarDaysInMonth} days)';
      } else {
        _daysWarning = null;
      }
    });
  }

  void _recalcLop() {
    final s = _selected;
    if (s == null || s.monthlyCtc == null) {
      setState(() => _liveLopEstimate = null);
      return;
    }
    final days = int.tryParse(_daysCtrl.text) ?? 0;
    final lop = int.tryParse(_lopCtrl.text) ?? 0;
    if (days <= 0) {
      setState(() => _liveLopEstimate = 0);
      return;
    }
    setState(() {
      _liveLopEstimate = (s.monthlyCtc!.toDouble() * lop) / days;
    });
  }

  int? _workingDays() {
    final d = int.tryParse(_daysCtrl.text.trim());
    if (d == null || d <= 0) return null;
    return d;
  }

  Future<void> _saveDraftOnly() async {
    final s = _selected;
    if (s == null) return;
    final days = _workingDays();
    if (days == null) {
      _toast('Enter valid days worked');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<PayrollRepository>().saveDraft(
            userId: s.userId,
            year: _year,
            month: _month,
            workingDaysInMonth: days,
            unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
            bonus: double.tryParse(_bonusCtrl.text) ?? 0,
            specialAdjustment: 0,
            otherEarnings: double.tryParse(_arrearsCtrl.text) ?? 0,
            slipNotes: _slipNotesCtrl.text,
          );
      _toast('Draft slip saved — editable until you lock');
      await _load();
    } catch (e) {
      _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final s = _selected;
    if (s == null) return;
    if (!s.hasStructure) {
      _toast('Pay package missing — add salary on People → user profile flow');
      return;
    }
    final days = _workingDays();
    if (days == null) {
      _toast('Enter valid days worked');
      return;
    }
    if (_daysWarning != null) {
      _toast(_daysWarning!);
      return;
    }

    setState(() => _busy = true);
    try {
      final preview = await context.read<PayrollRepository>().preview(
            userId: s.userId,
            year: _year,
            month: _month,
            workingDaysInMonth: days,
            unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
            bonus: double.tryParse(_bonusCtrl.text) ?? 0,
            specialAdjustment: 0,
            otherEarnings: double.tryParse(_arrearsCtrl.text) ?? 0,
            slipNotes: _slipNotesCtrl.text,
          );
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _PreviewSheet(
            preview: preview,
            locked: s.isLocked,
            inr: _inr,
          ),
        ),
      );
      if (confirmed == true) {
        await _submit(unlock: false);
      }
    } catch (e) {
      _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit({required bool unlock}) async {
    final s = _selected;
    if (s == null) return;
    final days = _workingDays();
    if (days == null) {
      _toast('Enter valid days worked');
      return;
    }
    final repo = context.read<PayrollRepository>();
    final slipNotes = _slipNotesCtrl.text.trim();
    final payload = (
      userId: s.userId,
      year: _year,
      month: _month,
      workingDaysInMonth: days,
      unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
      bonus: double.tryParse(_bonusCtrl.text) ?? 0,
      specialAdjustment: 0.0,
      otherEarnings: double.tryParse(_arrearsCtrl.text) ?? 0,
      slipNotes: slipNotes.isEmpty ? null : slipNotes,
    );

    try {
      if (unlock) {
        final pwd = await _askSuperAdminPassword();
        if (pwd == null) return;
        await repo.unlockAndReprocess(
          userId: payload.userId,
          year: payload.year,
          month: payload.month,
          workingDaysInMonth: payload.workingDaysInMonth,
          unpaidLeaveDays: payload.unpaidLeaveDays,
          bonus: payload.bonus,
          specialAdjustment: payload.specialAdjustment,
          otherEarnings: payload.otherEarnings,
          superAdminPassword: pwd,
          slipNotes: payload.slipNotes,
        );
      } else {
        await repo.processOne(
          userId: payload.userId,
          year: payload.year,
          month: payload.month,
          workingDaysInMonth: payload.workingDaysInMonth,
          unpaidLeaveDays: payload.unpaidLeaveDays,
          bonus: payload.bonus,
          specialAdjustment: payload.specialAdjustment,
          otherEarnings: payload.otherEarnings,
          slipNotes: payload.slipNotes,
        );
      }
      _toast('Salary locked for ${s.name}');
      await _load();
    } on ApiException catch (e) {
      if (e.message.contains('PAYROLL_LOCKED') ||
          e.message.contains('LOCKED')) {
        final pwd = await _askSuperAdminPassword();
        if (pwd == null) return;
        await repo.unlockAndReprocess(
          userId: payload.userId,
          year: payload.year,
          month: payload.month,
          workingDaysInMonth: payload.workingDaysInMonth,
          unpaidLeaveDays: payload.unpaidLeaveDays,
          bonus: payload.bonus,
          specialAdjustment: payload.specialAdjustment,
          otherEarnings: payload.otherEarnings,
          superAdminPassword: pwd,
          slipNotes: payload.slipNotes,
        );
        _toast('Unlocked & reprocessed with Super Admin approval');
        await _load();
      } else {
        _toast(e.message);
      }
    } catch (e) {
      _toast(apiErrorMessage(e));
    }
  }

  Future<String?> _askSuperAdminPassword() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Super Admin approval required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This month is locked for tax reporting. Enter Super Admin password to overwrite.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Super Admin password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Approve overwrite'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _downloadPdf(String payrollId, String ref) async {
    try {
      final bundle =
          await context.read<PayrollRepository>().fetchPdfBundle(payrollId);
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bundle.bytes),
        filename: bundle.filename,
      );
    } catch (e) {
      _toast(apiErrorMessage(e));
    }
  }

  String _monthName(int m) => DateFormat.MMMM().format(DateTime(2020, m));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return AppScaffold(
      title: 'Punch Salary',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    _PeriodRow(
                      year: _year,
                      month: _month,
                      onYear: (y) {
                        setState(() => _year = y);
                        _load();
                      },
                      onMonth: (m) {
                        setState(() => _month = m);
                        _load();
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 280, child: _employeeList()),
                                const SizedBox(width: 16),
                                Expanded(child: _formPane()),
                              ],
                            )
                          : ListView(
                              children: [
                                SizedBox(height: 220, child: _employeeList()),
                                const SizedBox(height: 12),
                                _formPane(),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _employeeList() {
    return Card(
      child: ListView.builder(
        itemCount: _employees.length,
        itemBuilder: (context, i) {
          final e = _employees[i];
          final selected = e.userId == _selected?.userId;
          return ListTile(
            selected: selected,
            leading: CircleAvatar(
              child: Text(e.name.isEmpty ? '?' : e.name[0]),
            ),
            title: Text(e.name),
            subtitle: Text(
              e.isLocked ? 'LOCKED' : (e.hasStructure ? 'Ready' : 'No structure'),
              style: TextStyle(
                color: e.isLocked
                    ? ArkaColors.warning
                    : e.hasStructure
                        ? ArkaColors.success
                        : Colors.redAccent,
                fontSize: 12,
              ),
            ),
            onTap: () {
              setState(() {
                _selected = e;
                _syncFieldsFromSelected();
              });
            },
          );
        },
      ),
    );
  }

  Widget _formPane() {
    final s = _selected;
    if (s == null) {
      return const Card(
        child: Center(child: Text('Select an employee to punch salary')),
      );
    }

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              s.designation ?? 'No designation',
              style: const TextStyle(color: ArkaColors.muted),
            ),
            if (s.existingPayrollId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/slip/${s.existingPayrollId}'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('View PDF'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _downloadPdf(
                      s.existingPayrollId!,
                      'slip-${s.employeeCode ?? s.userId}',
                    ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('Monthly variables', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Days worked',
                helperText: 'Calendar capacity: ${s.calendarDaysInMonth}',
                errorText: _daysWarning,
              ),
              onChanged: (_) {
                _validateDays();
                _recalcLop();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lopCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Unpaid leave days (LOP)',
                helperText: _liveLopEstimate == null
                    ? null
                    : 'Estimated LOP deduction: ${_inr.format(_liveLopEstimate)}',
              ),
              onChanged: (_) => _recalcLop(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bonusCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Performance bonus / arrears',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _arrearsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Other earnings'),
            ),
            const SizedBox(height: 16),
            Text('Slip details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _slipNotesCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notes on PDF slip (optional)',
                hintText: 'e.g. Reimbursement, leave balance, custom line…',
                alignLabelWithHint: true,
              ),
            ),
            if (s.isLocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArkaColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ArkaColors.warning.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'This month is already locked for ${s.name}. Saving or locking again updates the slip.',
                  style: const TextStyle(color: ArkaColors.warning),
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _saveDraftOnly,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save draft slip'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _preview,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: const Text('Calculate & lock slip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.year,
    required this.month,
    required this.onYear,
    required this.onMonth,
  });

  final int year;
  final int month;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: year,
            decoration: const InputDecoration(labelText: 'Year'),
            items: [
              for (var y = DateTime.now().year - 2; y <= DateTime.now().year + 1; y++)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: (v) {
              if (v != null) onYear(v);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(
                  value: m,
                  child: Text(DateFormat.MMMM().format(DateTime(2020, m))),
                ),
            ],
            onChanged: (v) {
              if (v != null) onMonth(v);
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    required this.preview,
    required this.locked,
    required this.inr,
  });

  final Map<String, dynamic> preview;
  final bool locked;
  final NumberFormat inr;

  @override
  Widget build(BuildContext context) {
    final emp = preview['employee'] as Map<String, dynamic>? ?? {};
    final lop = parseApiNum(preview['lopDeductionEstimate']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text(
            'Payroll preview — ${emp['name'] ?? ''}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final dual = c.maxWidth > 640;
              final earnings = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700)),
                  _line('Basic', preview['basicEarned']),
                  _line('HRA', preview['hraEarned']),
                  _line('Special Allowance', preview['specialAllowanceEarned']),
                  _line('Travel / conveyance', preview['conveyanceEarned']),
                  _line('Other fixed', preview['medicalEarned']),
                  _line('Bonus', preview['bonus']),
                  _line('Other', preview['otherEarnings']),
                  const Divider(),
                  _line('Gross', preview['grossEarnings'], bold: true),
                ],
              );
              final deductions = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Deductions', style: TextStyle(fontWeight: FontWeight.w700)),
                  _line('EPF', preview['epfEmployee']),
                  _line('ESIC', preview['esicEmployee']),
                  _line('Professional Tax (MH)', preview['professionalTax']),
                  _line('TDS', preview['tds']),
                  const Divider(),
                  _line('Total deductions', preview['totalDeductions'], bold: true),
                  _line('Net Pay', preview['netPay'], bold: true),
                ],
              );
              if (dual) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: earnings),
                    const SizedBox(width: 24),
                    Expanded(child: deductions),
                  ],
                );
              }
              return Column(children: [earnings, const SizedBox(height: 16), deductions]);
            },
          ),
          if (lop > 0) ...[
            const SizedBox(height: 8),
            Text(
              'LOP impact: ${inr.format(lop)}',
              style: const TextStyle(color: ArkaColors.muted),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(locked ? 'Update locked slip' : 'Confirm & lock slip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back to edit'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, dynamic value, {bool bold = false}) {
    final n = parseApiNum(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
          Text(
            inr.format(n),
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
