import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/leave/leave_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_fab.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class EmployeeLeaveScreen extends ConsumerStatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  ConsumerState<EmployeeLeaveScreen> createState() =>
      _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends ConsumerState<EmployeeLeaveScreen> {
  bool _applying = false;

  Future<void> _apply() async {
    var leaveType = 'CASUAL';
    final reason = TextEditingController();
    DateTimeRange? range;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Apply for leave', style: ctx.tt.titleLarge),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: leaveType,
                    decoration: const InputDecoration(labelText: 'Leave type'),
                    items: const [
                      DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
                      DropdownMenuItem(value: 'SICK', child: Text('Sick')),
                      DropdownMenuItem(value: 'EARNED', child: Text('Earned')),
                      DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      leaveType = v;
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 1, 12, 31),
                        initialDateRange:
                            range ?? DateTimeRange(start: now, end: now),
                      );
                      if (picked != null) {
                        range = picked;
                        setLocal(() {});
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      range == null
                          ? 'Pick dates'
                          : '${DateFormat('dd MMM').format(range!.start)} – ${DateFormat('dd MMM yyyy').format(range!.end)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        range == null ? null : () => Navigator.pop(ctx, true),
                    child: const Text('Submit request'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true || range == null || !mounted) {
      reason.dispose();
      return;
    }
    setState(() => _applying = true);
    try {
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await ref.read(leaveRepositoryProvider).applyLeave(
            type: leaveType,
            startDate: iso(range!.start),
            endDate: iso(range!.end),
            reason: reason.text.trim(),
          );
      invalidateLeaveData(ref);
      if (mounted) ArkaSnack.success(context, 'Leave request submitted');
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    } finally {
      reason.dispose();
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _cancel(LeaveRequestRow row) async {
    final ok = await confirmArka(
      context,
      title: 'Cancel leave request?',
      message:
          '${DateFormat('dd MMM').format(row.startDate)} – ${DateFormat('dd MMM').format(row.endDate)} (${row.days}d)',
      confirmLabel: 'Cancel request',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(leaveRepositoryProvider).cancelMine(row.id);
      invalidateLeaveData(ref);
      if (mounted) ArkaSnack.success(context, 'Request cancelled');
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(myLeaveBalanceProvider);
    final requests = ref.watch(myLeaveRequestsProvider);

    return AppScaffold(
      title: 'Leave',
      subtitle: 'Apply and track your leave requests',
      floatingActionButton: _applying
          ? null
          : ArkaAddFab(
              icon: Icons.add_rounded,
              label: 'Apply',
              onPressed: _apply,
            ),
      child: RefreshIndicator(
        onRefresh: () async {
          invalidateLeaveData(ref);
          await ref.read(myLeaveRequestsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          children: [
            ArkaAsync<LeaveBalance>(
              value: balance,
              onRetry: () => ref.invalidate(myLeaveBalanceProvider),
              data: (b) => ArkaFormSection(
                icon: Icons.beach_access_outlined,
                title: 'Balance ${b.year}',
                children: [
                  if (!b.hasQuota)
                    const ArkaInlineAlert(
                      tone: ArkaAlertTone.warning,
                      message:
                          'HR has not set your leave quota for this year yet.',
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _StatChip('Total', '${b.totalDays}'),
                        _StatChip('Used', '${b.usedDays}'),
                        _StatChip('Pending', '${b.pendingDays}'),
                        _StatChip('Left', '${b.remainingDays}'),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const ArkaSectionTitle('My requests'),
            ArkaAsync<List<LeaveRequestRow>>(
              value: requests,
              onRetry: () => ref.invalidate(myLeaveRequestsProvider),
              data: (rows) {
                if (rows.isEmpty) {
                  return const ArkaEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No leave requests',
                    message: 'Tap Apply to request time off.',
                  );
                }
                return Column(
                  children: [
                    for (final r in rows) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${r.type} · ${r.days} day${r.days == 1 ? '' : 's'}',
                          style: context.tt.titleSmall,
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy').format(r.startDate)} – ${DateFormat('dd MMM yyyy').format(r.endDate)}\n${r.status}${r.reason == null || r.reason!.isEmpty ? '' : ' · ${r.reason}'}',
                        ),
                        isThreeLine: true,
                        trailing: r.status == 'PENDING'
                            ? TextButton(
                                onPressed: () => _cancel(r),
                                child: const Text('Cancel'),
                              )
                            : ArkaStatusChip(
                                r.status,
                                tone: switch (r.status) {
                                  'APPROVED' => ArkaTone.success,
                                  'REJECTED' => ArkaTone.danger,
                                  _ => ArkaTone.neutral,
                                },
                              ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value, style: context.tt.titleMedium),
          Text(label, style: context.tt.bodySmall),
        ],
      ),
    );
  }
}
