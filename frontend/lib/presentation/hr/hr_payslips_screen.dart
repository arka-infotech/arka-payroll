import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class HrPayslipsScreen extends ConsumerStatefulWidget {
  const HrPayslipsScreen({super.key});

  @override
  ConsumerState<HrPayslipsScreen> createState() => _HrPayslipsScreenState();
}

class _HrPayslipsScreenState extends ConsumerState<HrPayslipsScreen> {
  String _query = '';
  String? _downloading;

  /// Logged-in user's slip first, then the rest (search still applies).
  List<PeriodSlipRow> _visible(List<PeriodSlipRow> rows) {
    final me = ref.read(authStateProvider).user?.id;
    final q = _query.trim().toLowerCase();
    final filtered = rows.where((r) {
      if (q.isEmpty) return true;
      return '${r.employeeName} ${r.trackingReference}'
          .toLowerCase()
          .contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aMe = a.userId == me;
      final bMe = b.userId == me;
      if (aMe && !bMe) return -1;
      if (!aMe && bMe) return 1;
      return a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase());
    });
    return filtered;
  }

  Future<void> _download(PeriodSlipRow row) async {
    setState(() => _downloading = row.id);
    try {
      final bundle =
          await ref.read(payrollRepositoryProvider).fetchPdfBundle(row.id);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(bundle.bytes), filename: bundle.filename);
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  Future<void> _edit(PeriodSlipRow row) async {
    final saved = await context.push<bool>('/slip/${row.id}/edit');
    if (saved == true && mounted) invalidatePayrollData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(payslipPeriodProvider);
    final slips = ref.watch(periodSlipsProvider);
    final me = ref.watch(authStateProvider).user?.id;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return AppScaffold(
      title: 'Payslips',
      subtitle:
          'Drafts appear automatically on each pay day until you punch them',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          if (wide)
            Row(
              children: [
                SizedBox(
                  width: 320,
                  child: ArkaMonthSwitcher(
                    period: period,
                    onChanged: (p) =>
                        ref.read(payslipPeriodProvider.notifier).set(p),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ArkaSearchField(
                    hint: 'Search name or reference',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            )
          else ...[
            ArkaMonthSwitcher(
              period: period,
              onChanged: (p) => ref.read(payslipPeriodProvider.notifier).set(p),
            ),
            const SizedBox(height: 10),
            ArkaSearchField(
              hint: 'Search name or reference',
              onChanged: (v) => setState(() => _query = v),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ArkaAsync<List<PeriodSlipRow>>(
              value: slips,
              onRetry: () => ref.invalidate(periodSlipsProvider),
              loading: const ArkaSkeletonList(count: 4, header: true),
              data: (rows) {
                final list = _visible(rows);
                final total = list.fold<num>(0, (s, r) => s + r.netPay);
                final drafts = list.where((r) => r.isDraft).length;

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(periodSlipsProvider.future),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: ArkaAdaptiveGrid(
                          minItemWidth: 100,
                          gap: 10,
                          maxColumns: 3,
                          children: [
                            _MiniStat(
                                label: 'Net payout',
                                value: Fmt.inr0(total),
                                icon: Icons.account_balance_wallet_rounded,
                                tone: ArkaTone.primary),
                            _MiniStat(
                                label: 'Slips',
                                value: '${list.length}',
                                icon: Icons.receipt_long_rounded,
                                tone: ArkaTone.info),
                            _MiniStat(
                                label: 'Drafts',
                                value: '$drafts',
                                icon: Icons.edit_note_rounded,
                                tone: drafts > 0
                                    ? ArkaTone.warning
                                    : ArkaTone.success),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      if (list.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: ArkaEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: rows.isEmpty
                                ? 'No slips for ${period.label}'
                                : 'No matches',
                            message: rows.isEmpty
                                ? 'Punch salary for this month, or wait for draft slips to appear on each pay day.'
                                : 'Try a different search.',
                            action: rows.isEmpty
                                ? FilledButton.icon(
                                    onPressed: () => context.go('/punch'),
                                    icon: const Icon(Icons.payments_rounded),
                                    label: const Text('Punch salary'),
                                  )
                                : null,
                          ),
                        )
                      else
                        SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _SlipCard(
                            row: list[i],
                            isMine: list[i].userId == me,
                            wide: wide,
                            downloading: _downloading == list[i].id,
                            onOpen: () => context.push('/slip/${list[i].id}'),
                            onEdit: () => _edit(list[i]),
                            onDownload: () => _download(list[i]),
                          ).animate().fadeIn(
                              delay: (25 * i.clamp(0, 10)).ms,
                              duration: 220.ms),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final ArkaTone tone;

  @override
  Widget build(BuildContext context) {
    final figure = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(value, style: context.tt.titleLarge),
    );
    return ArkaCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 170) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArkaIconBadge(icon, tone: tone, size: 32),
                const SizedBox(height: 10),
                figure,
                Text(label, style: context.tt.labelMedium),
              ],
            );
          }
          return Row(
            children: [
              ArkaIconBadge(icon, tone: tone, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.tt.labelMedium),
                    figure,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlipCard extends StatelessWidget {
  const _SlipCard({
    required this.row,
    required this.isMine,
    required this.wide,
    required this.downloading,
    required this.onOpen,
    required this.onEdit,
    required this.onDownload,
  });

  final PeriodSlipRow row;
  final bool isMine;
  final bool wide;
  final bool downloading;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = slipStatusTone(row.status);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            tooltip: 'Edit slip',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20)),
        IconButton(
            tooltip: 'Open PDF',
            onPressed: onOpen,
            icon: const Icon(Icons.visibility_outlined, size: 20)),
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
    );
    final identity = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(row.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium),
              ),
              if (isMine) ...[
                const SizedBox(width: 8),
                const ArkaStatusChip('You', tone: ArkaTone.info, dot: false),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(row.trackingReference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.bodySmall),
        ],
      ),
    );
    final amount = Text(Fmt.inr(row.netPay), style: context.tt.titleMedium);
    final chip = ArkaStatusChip(label, tone: tone, dot: true);
    final expectEmail = row.status == 'LOCKED' ||
        row.status == 'PROCESSED' ||
        row.status == 'PAID';
    final email = slipEmailTone(row.emailStatus, expectEmail: expectEmail);
    final emailTooltip = row.emailError?.trim().isNotEmpty == true
        ? row.emailError!
        : (row.emailSentAt != null
            ? 'Sent ${row.emailSentAt!.toLocal()}'
            : null);
    final statusRow = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        chip,
        if (email != null)
          Tooltip(
            message: emailTooltip ?? email.$2,
            child: ArkaStatusChip(
              email.$2,
              tone: email.$1,
              dot: true,
            ),
          ),
      ],
    );

    return ArkaCard(
      onTap: onOpen,
      padding: EdgeInsets.fromLTRB(16, 12, wide ? 8 : 6, wide ? 12 : 6),
      child: wide
          ? Row(
              children: [
                ArkaAvatar(row.employeeName, size: 44),
                const SizedBox(width: 14),
                identity,
                SizedBox(
                    width: 200,
                    child:
                        Align(alignment: Alignment.centerLeft, child: statusRow)),
                SizedBox(
                    width: 150,
                    child:
                        Align(alignment: Alignment.centerRight, child: amount)),
                const SizedBox(width: 12),
                actions,
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    ArkaAvatar(row.employeeName, size: 42),
                    const SizedBox(width: 12),
                    identity,
                    const SizedBox(width: 8),
                    Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: amount),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 54),
                    Expanded(child: statusRow),
                    actions,
                  ],
                ),
              ],
            ),
    );
  }
}
