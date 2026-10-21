import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

String _fyLabel(int year, int month) {
  final start = month >= 4 ? year : year - 1;
  return 'FY $start–${((start + 1) % 100).toString().padLeft(2, '0')}';
}

String _monthLabel(SlipSummary s) =>
    DateFormat('MMMM yyyy').format(DateTime(s.year, s.month));

class EmployeeSlipsScreen extends ConsumerStatefulWidget {
  const EmployeeSlipsScreen({super.key});

  @override
  ConsumerState<EmployeeSlipsScreen> createState() =>
      _EmployeeSlipsScreenState();
}

class _EmployeeSlipsScreenState extends ConsumerState<EmployeeSlipsScreen> {
  String? _downloading;

  Future<void> _download(SlipSummary s) async {
    setState(() => _downloading = s.id);
    try {
      final bundle =
          await ref.read(payrollRepositoryProvider).fetchPdfBundle(s.id);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(bundle.bytes), filename: bundle.filename);
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  void _details(SlipSummary s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _SlipBreakdown(summary: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slips = ref.watch(mySlipsProvider);
    final user = ref.watch(authStateProvider).user;

    return AppScaffold(
      title: 'Pay history',
      subtitle: user == null ? null : 'Payslips for ${user.fullName}',
      child: ArkaAsync<List<SlipSummary>>(
        value: slips,
        onRetry: () => ref.invalidate(mySlipsProvider),
        data: (all) {
          if (all.isEmpty) {
            return const ArkaEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payslips yet',
              message:
                  'Your salary slips appear here as soon as payroll is locked each month.',
            );
          }
          final sorted = [...all]..sort((a, b) =>
              (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));
          final grouped = <String, List<SlipSummary>>{};
          for (final s in sorted) {
            grouped.putIfAbsent(_fyLabel(s.year, s.month), () => []).add(s);
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(mySlipsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                _LatestHero(
                  slip: sorted.first,
                  downloading: _downloading == sorted.first.id,
                  onView: () => context.push('/slip/${sorted.first.id}'),
                  onDownload: () => _download(sorted.first),
                ),
                const SizedBox(height: 24),
                for (final entry in grouped.entries) ...[
                  ArkaSectionTitle(
                    entry.key,
                    subtitle:
                        '${entry.value.length} slip${entry.value.length == 1 ? '' : 's'} · '
                        '${Fmt.inr0(entry.value.fold<num>(0, (s, e) => s + e.netPay))} net',
                  ),
                  for (final s in entry.value) ...[
                    _SlipRow(
                      slip: s,
                      downloading: _downloading == s.id,
                      onTap: () => _details(s),
                      onView: () => context.push('/slip/${s.id}'),
                      onDownload: () => _download(s),
                    ).animate().fadeIn(duration: 220.ms),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LatestHero extends StatelessWidget {
  const _LatestHero(
      {required this.slip,
      required this.downloading,
      required this.onView,
      required this.onDownload});

  final SlipSummary slip;
  final bool downloading;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.heroStart, p.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST PAY · ${_monthLabel(slip).toUpperCase()}',
            style: context.tt.labelSmall
                ?.copyWith(color: Colors.white70, letterSpacing: 1.2),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.inr(slip.netPay),
              style: context.tt.headlineMedium
                  ?.copyWith(color: Colors.white, fontSize: 34),
            ),
          ),
          const SizedBox(height: 2),
          Text('Net pay · ${slip.trackingReference}',
              style: context.tt.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ArkaColors.navy),
                onPressed: onView,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text('View payslip'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                ),
                onPressed: downloading ? null : onDownload,
                icon: downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
  }
}

class _SlipRow extends StatelessWidget {
  const _SlipRow({
    required this.slip,
    required this.downloading,
    required this.onTap,
    required this.onView,
    required this.onDownload,
  });

  final SlipSummary slip;
  final bool downloading;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = slipStatusTone(slip.status);
    return ArkaCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.cs.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.MMM()
                      .format(DateTime(slip.year, slip.month))
                      .toUpperCase(),
                  style: context.tt.labelSmall
                      ?.copyWith(color: context.cs.onSecondaryContainer),
                ),
                Text(
                  '${slip.year % 100}'.padLeft(2, '0'),
                  style: context.tt.titleSmall
                      ?.copyWith(color: context.cs.onSecondaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_monthLabel(slip), style: context.tt.titleSmall),
                const SizedBox(height: 4),
                Row(children: [ArkaStatusChip(label, tone: tone, dot: true)]),
              ],
            ),
          ),
          Flexible(
            child: Text(Fmt.inr(slip.netPay),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: context.tt.titleSmall),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: downloading ? null : onDownload,
            icon: downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SlipBreakdown extends ConsumerStatefulWidget {
  const _SlipBreakdown({required this.summary});

  final SlipSummary summary;

  @override
  ConsumerState<_SlipBreakdown> createState() => _SlipBreakdownState();
}

class _SlipBreakdownState extends ConsumerState<_SlipBreakdown> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(payrollRepositoryProvider).fetchSlip(widget.summary.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ArkaInlineAlert.fromError(snap.error!),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _future =
                        ref.read(payrollRepositoryProvider).fetchSlip(s.id);
                  }),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final slip = snap.data!;
          Widget line(String k, dynamic v, {bool bold = false}) {
            final style = bold ? context.tt.titleMedium : context.tt.bodyMedium;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                      child: Text(k,
                          style: style?.copyWith(
                              color:
                                  bold ? null : context.cs.onSurfaceVariant))),
                  Text(Fmt.inr(parseApiNum(v)), style: style),
                ],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_monthLabel(s), style: context.tt.titleLarge),
              Text(s.trackingReference, style: context.tt.bodySmall),
              const SizedBox(height: 16),
              line('Gross earnings', slip['grossEarnings']),
              line('Provident fund', slip['epfEmployee']),
              line('ESIC', slip['esicEmployee'] ?? 0),
              line('Professional tax', slip['professionalTax']),
              line('Income tax (TDS)', slip['tds']),
              const Divider(height: 24),
              line('Net pay', slip['netPay'], bold: true),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/slip/${s.id}');
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Open PDF'),
              ),
            ],
          );
        },
      ),
    );
  }
}
