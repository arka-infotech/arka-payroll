import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';

class EmployeeSlipsScreen extends StatefulWidget {
  const EmployeeSlipsScreen({super.key});

  @override
  State<EmployeeSlipsScreen> createState() => _EmployeeSlipsScreenState();
}

class _EmployeeSlipsScreenState extends State<EmployeeSlipsScreen> {
  List<SlipSummary> _slips = [];
  bool _loading = true;
  String? _error;
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slips = await context.read<PayrollRepository>().fetchMySlips();
      setState(() {
        _slips = slips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fyLabel(SlipSummary s) {
    final fyStart = s.month >= 4 ? s.year : s.year - 1;
    final yy = (fyStart + 1) % 100;
    return 'FY $fyStart-${yy.toString().padLeft(2, '0')}';
  }

  Map<String, List<SlipSummary>> _groupByFy() {
    final map = <String, List<SlipSummary>>{};
    for (final s in _slips) {
      map.putIfAbsent(_fyLabel(s), () => []).add(s);
    }
    return map;
  }

  Future<void> _download(SlipSummary s) async {
    final bundle =
        await context.read<PayrollRepository>().fetchPdfBundle(s.id);
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bundle.bytes),
      filename: bundle.filename,
    );
  }

  Future<void> _view(SlipSummary s) async {
    final slip = await context.read<PayrollRepository>().fetchSlip(s.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${DateFormat.MMMM().format(DateTime(s.year, s.month))} ${s.year}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(s.trackingReference, style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _kv('Gross', slip['grossEarnings']),
                      _kv('EPF', slip['epfEmployee']),
                      _kv('ESIC', slip['esicEmployee'] ?? 0),
                      _kv('Professional Tax', slip['professionalTax']),
                      _kv('TDS', slip['tds']),
                      _kv('Net Pay', slip['netPay'], bold: true),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/slip/${s.id}');
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Open PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, dynamic v, {bool bold = false}) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null)),
          ),
          Text(
            _inr.format(n),
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByFy();

    return AppScaffold(
      title: 'Pay History',
      actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _slips.isEmpty
                  ? const ArkaEmptyState(
                      title: 'No payslips yet',
                      message: 'Locked salary slips will appear here each month.',
                      icon: Icons.receipt_long_outlined,
                    )
                  : ListView(
                      children: [
                        for (final entry in grouped.entries)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              title: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('${entry.value.length} slip(s)'),
                              children: [
                                for (final s in entry.value)
                                  ListTile(
                                    title: Text(
                                      DateFormat.MMMM()
                                          .format(DateTime(s.year, s.month)),
                                    ),
                                    subtitle: Text(s.trackingReference),
                                    trailing: Wrap(
                                      spacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          _inr.format(s.netPay),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: ArkaColors.navy,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'View',
                                          onPressed: () => _view(s),
                                          icon: const Icon(Icons.visibility_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Download PDF',
                                          onPressed: () => _download(s),
                                          icon: const Icon(Icons.download_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
    );
  }
}
