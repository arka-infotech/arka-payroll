import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/hr/user_form.dart' show FormWidth;
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class _Line {
  _Line(String label, String amount)
      : label = TextEditingController(text: label),
        amount = TextEditingController(text: amount);

  final TextEditingController label;
  final TextEditingController amount;

  double get value => double.tryParse(amount.text.trim()) ?? 0;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

/// Edit any printed section of a generated payslip.
class EditSlipScreen extends ConsumerStatefulWidget {
  const EditSlipScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  ConsumerState<EditSlipScreen> createState() => _EditSlipScreenState();
}

class _EditSlipScreenState extends ConsumerState<EditSlipScreen> {
  final _company = TextEditingController();
  final _location = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _payDate = TextEditingController();
  final _paid = TextEditingController();
  final _lop = TextEditingController();
  final _notes = TextEditingController();
  final List<_Line> _earnings = [];
  final List<_Line> _deductions = [];
  final _scroll = ScrollController();

  bool _loaded = false;
  bool _busy = false;
  Object? _loadError;
  Object? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _company,
      _location,
      _name,
      _code,
      _payDate,
      _paid,
      _lop,
      _notes
    ]) {
      c.dispose();
    }
    for (final l in [..._earnings, ..._deductions]) {
      l.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final slip =
          await ref.read(payrollRepositoryProvider).fetchSlip(widget.payrollId);
      if (!mounted) return;
      final user = slip['user'] as Map<String, dynamic>? ?? {};
      final doc = slip['slipDocument'] as Map<String, dynamic>?;
      _company.text =
          (doc?['companyName'] ?? AppConfig.companyName).toString().trim();
      _location.text =
          (doc?['location'] ?? AppConfig.companyAddress).toString().trim();
      _name.text = (doc?['employeeName'] ??
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}')
          .toString()
          .trim();
      _code.text =
          (doc?['employeeCode'] ?? user['employeeCode'] ?? '').toString();
      _payDate.text = _fmtDate(doc?['payDate'] ?? slip['payDate']);
      _paid.text = '${doc?['paidDays'] ?? slip['daysPayable'] ?? 0}';
      _lop.text = '${doc?['lopDays'] ?? slip['unpaidLeaveDays'] ?? 0}';
      _notes.text = (doc?['notes'] ?? slip['slipNotes'] ?? '').toString();

      void fill(List<_Line> into, List<dynamic>? rows,
          List<(String, dynamic)> defaults) {
        if (rows != null && rows.isNotEmpty) {
          for (final row in rows) {
            final m = row as Map<String, dynamic>;
            into.add(
                _Line('${m['label'] ?? ''}', '${parseApiNum(m['amount'])}'));
          }
        } else {
          for (final (label, amount) in defaults) {
            into.add(_Line(label, '${parseApiNum(amount)}'));
          }
        }
      }

      fill(_earnings, doc?['earnings'] as List<dynamic>?, [
        ('Basic', slip['basicEarned']),
        ('House Rent Allowance', slip['hraEarned']),
        ('Travel allowance', slip['conveyanceEarned']),
      ]);
      fill(_deductions, doc?['deductions'] as List<dynamic>?, [
        ('Income Tax', slip['tds']),
        ('Provident Fund', slip['epfEmployee']),
      ]);
      setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    if (raw.length >= 10) {
      final p = raw.substring(0, 10).split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    }
    return raw;
  }

  String _toIso(String display) {
    final p = display.trim().split('/');
    if (p.length == 3) {
      return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
    }
    return display.trim();
  }

  DateTime? get _payDateValue => DateTime.tryParse(_toIso(_payDate.text));

  Future<void> _pickPayDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _payDateValue ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Pay date',
    );
    if (picked == null) return;
    setState(() {
      _payDate.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  List<Map<String, dynamic>> _payload(List<_Line> lines) => [
        for (final l in lines)
          if (l.label.text.trim().isNotEmpty)
            {'label': l.label.text.trim(), 'amount': l.value},
      ];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      await ref
          .read(payrollRepositoryProvider)
          .saveSlipDocument(widget.payrollId, {
        'companyName': _company.text.trim(),
        'location': _location.text.trim(),
        'employeeName': _name.text.trim(),
        'employeeCode': _code.text.trim(),
        'payDate': _toIso(_payDate.text),
        'paidDays': int.tryParse(_paid.text) ?? 0,
        'lopDays': int.tryParse(_lop.text) ?? 0,
        'notes': _notes.text.trim(),
        'earnings': _payload(_earnings),
        'deductions': _payload(_deductions),
      });
      if (!mounted) return;
      invalidatePayrollData(ref);
      ArkaSnack.success(
          context, 'Slip updated — download the PDF again to see it');
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
    Widget body;
    if (_loadError != null) {
      body = ArkaErrorView(error: _loadError!, onRetry: _load);
    } else if (!_loaded) {
      body =
          const FormWidth(child: ArkaSkeletonList(count: 4, itemHeight: 160));
    } else {
      final gross = _earnings.fold<double>(0, (s, l) => s + l.value);
      final ded = _deductions.fold<double>(0, (s, l) => s + l.value);
      body = FormWidth(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            const ArkaInlineAlert(
              tone: ArkaAlertTone.info,
              message:
                  'Changes here only affect the printed slip. Download the PDF again to see them.',
            ),
            const SizedBox(height: 14),
            if (_saveError != null) ...[
              ArkaInlineAlert.fromError(_saveError!,
                  onDismiss: () => setState(() => _saveError = null)),
              const SizedBox(height: 14),
            ],
            ArkaFormSection(
              icon: Icons.apartment_rounded,
              title: 'Company',
              children: [
                TextField(
                    controller: _company,
                    decoration:
                        const InputDecoration(labelText: 'Company name')),
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Address', alignLabelWithHint: true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ArkaFormSection(
              icon: Icons.badge_outlined,
              title: 'Employee & attendance',
              children: [
                ArkaFieldRow(
                  children: [
                    TextField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Employee name')),
                    TextField(
                        controller: _code,
                        decoration:
                            const InputDecoration(labelText: 'Employee ID')),
                  ],
                ),
                const SizedBox(height: 12),
                ArkaFieldRow(
                  children: [
                    ArkaDateField(
                        label: 'Pay date',
                        value: _payDateValue,
                        onPick: _pickPayDate),
                    ArkaFieldRow(
                      breakpoint: 0,
                      children: [
                        TextField(
                          controller: _paid,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Paid days'),
                        ),
                        TextField(
                          controller: _lop,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'LOP days'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LineSection(
              title: 'Earnings',
              icon: Icons.trending_up_rounded,
              lines: _earnings,
              total: gross,
              onChanged: () => setState(() {}),
              onAdd: () => setState(() => _earnings.add(_Line('', '0'))),
              onRemove: (i) => setState(() => _earnings.removeAt(i).dispose()),
            ),
            const SizedBox(height: 14),
            _LineSection(
              title: 'Deductions',
              icon: Icons.trending_down_rounded,
              lines: _deductions,
              total: ded,
              onChanged: () => setState(() {}),
              onAdd: () => setState(() => _deductions.add(_Line('', '0'))),
              onRemove: (i) =>
                  setState(() => _deductions.removeAt(i).dispose()),
            ),
            const SizedBox(height: 14),
            _NetSummary(gross: gross, deductions: ded),
            const SizedBox(height: 14),
            ArkaFormSection(
              icon: Icons.sticky_note_2_outlined,
              title: 'Notes',
              children: [
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Printed at the bottom of the slip'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      title: 'Edit slip',
      subtitle: 'Adjust what prints on this payslip',
      showNav: false,
      bottomBar: !_loaded
          ? null
          : ArkaBottomBar(
              children: [
                OutlinedButton(
                    onPressed: _busy ? null : () => context.pop(),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: ArkaBusyLabel(
                      busy: _busy,
                      label: 'Save slip',
                      icon: Icons.check_rounded),
                ),
              ],
            ),
      child: body,
    );
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({
    required this.title,
    required this.icon,
    required this.lines,
    required this.total,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final List<_Line> lines;
  final double total;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return ArkaFormSection(
      icon: icon,
      title: title,
      subtitle: 'Total ${Fmt.inr(total)}',
      trailing: TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add line'),
      ),
      children: [
        if (lines.isEmpty)
          Text('No lines — add one above.', style: context.tt.bodySmall),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                    controller: lines[i].label,
                    decoration: const InputDecoration(labelText: 'Label')),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: lines[i].amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '₹ '),
                  onChanged: (_) => onChanged(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: IconButton(
                  tooltip: 'Remove line',
                  onPressed: () => onRemove(i),
                  icon: Icon(Icons.remove_circle_outline_rounded,
                      color: context.cs.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NetSummary extends StatelessWidget {
  const _NetSummary({required this.gross, required this.deductions});

  final double gross;
  final double deductions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [p.heroStart, p.heroEnd]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NET PAYABLE',
                    style: context.tt.labelSmall
                        ?.copyWith(color: Colors.white70, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.inr(gross)} − ${Fmt.inr(deductions)}',
                  style: context.tt.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(Fmt.inr(gross - deductions),
              style: context.tt.headlineSmall?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
