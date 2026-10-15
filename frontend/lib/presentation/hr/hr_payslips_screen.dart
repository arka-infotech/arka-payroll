import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';

enum _SlipFilter { all, mine }

class HrPayslipsScreen extends StatefulWidget {
  const HrPayslipsScreen({super.key});

  @override
  State<HrPayslipsScreen> createState() => _HrPayslipsScreenState();
}

class _HrPayslipsScreenState extends State<HrPayslipsScreen> {
  late int _year;
  late int _month;
  List<PeriodSlipRow> _rows = [];
  bool _loading = true;
  String? _error;
  _SlipFilter _filter = _SlipFilter.all;
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
      final rows =
          await context.read<PayrollRepository>().fetchPeriodSlips(_year, _month);
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  List<PeriodSlipRow> _visible(AuthState auth) {
    if (_filter == _SlipFilter.mine && auth.user != null) {
      return _rows.where((r) => r.userId == auth.user!.id).toList();
    }
    return _rows;
  }

  Future<void> _download(PeriodSlipRow row) async {
    try {
      final bundle =
          await context.read<PayrollRepository>().fetchPdfBundle(row.id);
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bundle.bytes),
        filename: bundle.filename,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final visible = _visible(auth);

    return AppScaffold(
      title: 'Payslips',
      actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [
                    for (var y = DateTime.now().year - 2;
                        y <= DateTime.now().year + 1;
                        y++)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _year = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat.MMMM().format(DateTime(2020, m))),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _month = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_SlipFilter>(
            segments: const [
              ButtonSegment(value: _SlipFilter.all, label: Text('Team')),
              ButtonSegment(value: _SlipFilter.mine, label: Text('My slip')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            'Draft slips auto-appear on each employee’s pay day if not punched yet. Edit drafts in Punch or here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ArkaColors.muted,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : visible.isEmpty
                        ? const ArkaEmptyState(
                            title: 'No slips this period',
                            message:
                                'Set a pay package on Add user — a draft slip is created for this month. After the pay day, open Slips again if you have not punched yet.',
                            icon: Icons.receipt_long_outlined,
                          )
                        : ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = visible[i];
                              return Material(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white10
                                          : const Color(0xFFE6ECF1),
                                    ),
                                  ),
                                  title: Text(
                                    r.employeeName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${r.trackingReference} · ${r.status}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: r.isDraft
                                          ? ArkaColors.warning
                                          : ArkaColors.muted,
                                      fontWeight:
                                          r.isDraft ? FontWeight.w600 : null,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _inr.format(r.netPay),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ArkaColors.navy,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit slip',
                                        onPressed: () async {
                                          final saved = await context.push<bool>(
                                            '/slip/${r.id}/edit',
                                          );
                                          if (saved == true && mounted) _load();
                                        },
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Open PDF',
                                        onPressed: () => context.push('/slip/${r.id}'),
                                        icon: const Icon(Icons.visibility_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Download',
                                        onPressed: () => _download(r),
                                        icon: const Icon(Icons.download_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
