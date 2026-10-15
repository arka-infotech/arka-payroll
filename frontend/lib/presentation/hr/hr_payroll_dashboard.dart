import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/widgets/app_shell.dart';

/// HR Payroll Dashboard — grid to punch LOP, bonus, special adjustments.
class HrPayrollDashboard extends StatefulWidget {
  const HrPayrollDashboard({super.key});

  @override
  State<HrPayrollDashboard> createState() => _HrPayrollDashboardState();
}

class _HrPayrollDashboardState extends State<HrPayrollDashboard> {
  late int _year;
  late int _month;
  List<PayrollGridRow> _rows = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<PayrollRepository>();
      final rows = await repo.fetchGrid(_year, _month);
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _processRow(PayrollGridRow row) async {
    if (!row.hasStructure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${row.name}: salary structure missing')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final repo = context.read<PayrollRepository>();
      final result = await repo.processOne(
        userId: row.userId,
        year: _year,
        month: _month,
        workingDaysInMonth: row.workingDaysInMonth,
        unpaidLeaveDays: row.unpaidLeaveDays,
        bonus: row.bonus,
        specialAdjustment: row.specialAdjustment,
        otherEarnings: row.otherEarnings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed ${row.name} · Net ${_inr.format(result['netPay'])}'),
          action: SnackBarAction(
            label: 'View PDF',
            onPressed: () => context.push('/slip/${result['id']}'),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processAll() async {
    setState(() => _processing = true);
    final repo = context.read<PayrollRepository>();
    var ok = 0;
    for (final row in _rows.where((r) => r.hasStructure)) {
      try {
        await repo.processOne(
          userId: row.userId,
          year: _year,
          month: _month,
          workingDaysInMonth: row.workingDaysInMonth,
          unpaidLeaveDays: row.unpaidLeaveDays,
          bonus: row.bonus,
          specialAdjustment: row.specialAdjustment,
          otherEarnings: row.otherEarnings,
        );
        ok++;
      } catch (_) {
        // continue remaining rows
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Processed $ok employee(s)')),
    );
    await _load();
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'HR Payroll Dashboard',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodBar(
              year: _year,
              month: _month,
              processing: _processing,
              onYearChanged: (y) {
                setState(() => _year = y);
                _load();
              },
              onMonthChanged: (m) {
                setState(() => _month = m);
                _load();
              },
              onProcessAll: _processAll,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!)))
            else
              Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              ArkaColors.navy.withOpacity(0.08),
            ),
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Working Days')),
              DataColumn(label: Text('Unpaid Leaves')),
              DataColumn(label: Text('Bonus')),
              DataColumn(label: Text('Special Adj.')),
              DataColumn(label: Text('Other')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          row.designation ?? '',
                          style: const TextStyle(fontSize: 11, color: ArkaColors.muted),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(row.employeeCode ?? '—')),
                  DataCell(_IntField(
                    value: row.workingDaysInMonth,
                    onChanged: (v) => setState(() => row.workingDaysInMonth = v),
                  )),
                  DataCell(_IntField(
                    value: row.unpaidLeaveDays,
                    onChanged: (v) => setState(() => row.unpaidLeaveDays = v),
                  )),
                  DataCell(_NumField(
                    value: row.bonus,
                    onChanged: (v) => setState(() => row.bonus = v),
                  )),
                  DataCell(_NumField(
                    value: row.specialAdjustment,
                    onChanged: (v) => setState(() => row.specialAdjustment = v),
                  )),
                  DataCell(_NumField(
                    value: row.otherEarnings,
                    onChanged: (v) => setState(() => row.otherEarnings = v),
                  )),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          onPressed: _processing ? null : () => _processRow(row),
                          child: const Text('Process'),
                        ),
                        if (row.existingPayrollId != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'View / Print slip',
                            onPressed: () =>
                                context.push('/slip/${row.existingPayrollId}'),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.year,
    required this.month,
    required this.processing,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onProcessAll,
  });

  final int year;
  final int month;
  final bool processing;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onProcessAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Punch monthly variables, then process',
          style: TextStyle(color: ArkaColors.muted),
        ),
        const Spacer(),
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<int>(
            value: year,
            decoration: const InputDecoration(labelText: 'Year', isDense: true),
            items: List.generate(5, (i) {
              final y = DateTime.now().year - 2 + i;
              return DropdownMenuItem(value: y, child: Text('$y'));
            }),
            onChanged: (v) {
              if (v != null) onYearChanged(v);
            },
          ),
        ),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<int>(
            value: month,
            decoration: const InputDecoration(labelText: 'Month', isDense: true),
            items: List.generate(12, (i) {
              final m = i + 1;
              final name = DateFormat.MMMM().format(DateTime(2020, m));
              return DropdownMenuItem(value: m, child: Text(name));
            }),
            onChanged: (v) {
              if (v != null) onMonthChanged(v);
            },
          ),
        ),
        ElevatedButton.icon(
          onPressed: processing ? null : onProcessAll,
          icon: processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_arrow),
          label: const Text('Process all'),
        ),
      ],
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(isDense: true),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: value == 0 ? '' : value.toStringAsFixed(0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(isDense: true, hintText: '0'),
        onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
      ),
    );
  }
}
