import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class _Line {
  _Line(this.label, this.amount);
  final TextEditingController label;
  final TextEditingController amount;
}

/// Edit any printed section of a generated payslip.
class EditSlipScreen extends StatefulWidget {
  const EditSlipScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  State<EditSlipScreen> createState() => _EditSlipScreenState();
}

class _EditSlipScreenState extends State<EditSlipScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _payDate = TextEditingController();
  final _paid = TextEditingController();
  final _lop = TextEditingController();
  final _notes = TextEditingController();
  final List<_Line> _earnings = [];
  final List<_Line> _deductions = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _payDate.dispose();
    _paid.dispose();
    _lop.dispose();
    _notes.dispose();
    for (final l in [..._earnings, ..._deductions]) {
      l.label.dispose();
      l.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final slip =
          await context.read<PayrollRepository>().fetchSlip(widget.payrollId);
      final user = slip['user'] as Map<String, dynamic>? ?? {};
      final doc = slip['slipDocument'] as Map<String, dynamic>?;
      _name.text = (doc?['employeeName'] ??
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}')
          .toString()
          .trim();
      _code.text = (doc?['employeeCode'] ?? user['employeeCode'] ?? '').toString();
      _payDate.text = _fmtDate(doc?['payDate'] ?? slip['payDate']);
      _paid.text = '${doc?['paidDays'] ?? slip['daysPayable'] ?? 0}';
      _lop.text = '${doc?['lopDays'] ?? slip['unpaidLeaveDays'] ?? 0}';
      _notes.text = (doc?['notes'] ?? slip['slipNotes'] ?? '').toString();
      final earnings = doc?['earnings'] as List<dynamic>?;
      final deductions = doc?['deductions'] as List<dynamic>?;
      if (earnings != null && earnings.isNotEmpty) {
        for (final row in earnings) {
          final m = row as Map<String, dynamic>;
          _earnings.add(_Line(
            TextEditingController(text: '${m['label'] ?? ''}'),
            TextEditingController(text: '${parseApiNum(m['amount'])}'),
          ));
        }
      } else {
        _addDefaultEarnings(slip);
      }
      if (deductions != null && deductions.isNotEmpty) {
        for (final row in deductions) {
          final m = row as Map<String, dynamic>;
          _deductions.add(_Line(
            TextEditingController(text: '${m['label'] ?? ''}'),
            TextEditingController(text: '${parseApiNum(m['amount'])}'),
          ));
        }
      } else {
        _addDefaultDeductions(slip);
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
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
    if (p.length == 3) return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
    return display.trim();
  }

  void _addDefaultEarnings(Map<String, dynamic> slip) {
    void add(String label, dynamic amount) {
      _earnings.add(_Line(
        TextEditingController(text: label),
        TextEditingController(text: '${parseApiNum(amount)}'),
      ));
    }

    add('Basic', slip['basicEarned']);
    add('House Rent Allowance', slip['hraEarned']);
    add('Travel allowance', slip['conveyanceEarned']);
  }

  void _addDefaultDeductions(Map<String, dynamic> slip) {
    void add(String label, dynamic amount) {
      _deductions.add(_Line(
        TextEditingController(text: label),
        TextEditingController(text: '${parseApiNum(amount)}'),
      ));
    }

    add('Income Tax', slip['tds']);
    add('Provident Fund', slip['epfEmployee']);
  }

  List<Map<String, dynamic>> _payload(List<_Line> lines) {
    return [
      for (final l in lines)
        if (l.label.text.trim().isNotEmpty)
          {
            'label': l.label.text.trim(),
            'amount': double.tryParse(l.amount.text.trim()) ?? 0,
          },
    ];
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<PayrollRepository>().saveSlipDocument(
        widget.payrollId,
        {
          'employeeName': _name.text.trim(),
          'employeeCode': _code.text.trim(),
          'payDate': _toIso(_payDate.text),
          'paidDays': int.tryParse(_paid.text) ?? 0,
          'lopDays': int.tryParse(_lop.text) ?? 0,
          'notes': _notes.text.trim(),
          'earnings': _payload(_earnings),
          'deductions': _payload(_deductions),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slip updated')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit slip',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  children: [
                    const Text(
                      'Change any section. Download the PDF again to see it.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Employee name'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _payDate,
                      decoration: const InputDecoration(
                        labelText: 'Pay date',
                        hintText: 'DD/MM/YYYY',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _paid,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Paid days'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lop,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'LOP days'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LineEditor(
                      title: 'Earnings',
                      lines: _earnings,
                      onAdd: () => setState(() {
                        _earnings.add(_Line(
                          TextEditingController(),
                          TextEditingController(text: '0'),
                        ));
                      }),
                      onRemove: (i) => setState(() {
                        final line = _earnings.removeAt(i);
                        line.label.dispose();
                        line.amount.dispose();
                      }),
                    ),
                    const SizedBox(height: 18),
                    _LineEditor(
                      title: 'Deductions',
                      lines: _deductions,
                      onAdd: () => setState(() {
                        _deductions.add(_Line(
                          TextEditingController(),
                          TextEditingController(text: '0'),
                        ));
                      }),
                      onRemove: (i) => setState(() {
                        final line = _deductions.removeAt(i);
                        line.label.dispose();
                        line.amount.dispose();
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Saving…' : 'Save slip'),
                    ),
                  ],
                ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.title,
    required this.lines,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<_Line> lines;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add line'),
            ),
          ],
        ),
        for (var i = 0; i < lines.length; i++) ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: lines[i].label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: lines[i].amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
              IconButton(
                onPressed: () => onRemove(i),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
