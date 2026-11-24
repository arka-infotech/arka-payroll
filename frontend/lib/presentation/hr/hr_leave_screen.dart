import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/leave/leave_repository.dart';
import 'package:arka_payroll/presentation/employee/employee_leave_screen.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/shell/main_tab_shell.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

enum _LeaveFilter { pending, all, mine }

/// HR: approve/reject leave requests.
class HrLeaveScreen extends ConsumerStatefulWidget {
  const HrLeaveScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<HrLeaveScreen> createState() => _HrLeaveScreenState();
}

class _HrLeaveScreenState extends ConsumerState<HrLeaveScreen> {
  _LeaveFilter _filter = _LeaveFilter.pending;

  Future<void> _refresh() async {
    invalidateLeaveData(ref);
    if (_filter == _LeaveFilter.pending) {
      await ref.read(pendingLeaveProvider.future);
    } else if (_filter == _LeaveFilter.all) {
      await ref.read(allLeaveRequestsProvider.future);
    } else {
      await ref.read(myLeaveRequestsProvider.future);
    }
  }

  Future<void> _review(
    BuildContext context,
    LeaveRequestRow row,
    bool approve,
  ) async {
    final ok = await confirmArka(
      context,
      title: approve ? 'Approve leave?' : 'Reject leave?',
      message:
          '${row.employeeName ?? 'Employee'} · ${row.days} day(s) · ${row.type}',
      confirmLabel: approve ? 'Approve' : 'Reject',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(leaveRepositoryProvider).review(
            id: row.id,
            status: approve ? 'APPROVED' : 'REJECTED',
          );
      invalidateLeaveData(ref);
      if (context.mounted) {
        ArkaSnack.success(
            context, approve ? 'Leave approved' : 'Leave rejected');
      }
    } catch (e) {
      if (context.mounted) ArkaSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterBar = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<_LeaveFilter>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return context.cs.secondaryContainer;
            }
            return context.cs.surfaceContainerHighest;
          }),
        ),
        segments: const [
          ButtonSegment(
            value: _LeaveFilter.pending,
            label: Text('Pending'),
            icon: Icon(Icons.hourglass_top_rounded, size: 18),
          ),
          ButtonSegment(
            value: _LeaveFilter.all,
            label: Text('All'),
            icon: Icon(Icons.list_alt_rounded, size: 18),
          ),
          ButtonSegment(
            value: _LeaveFilter.mine,
            label: Text('Mine'),
            icon: Icon(Icons.person_outline_rounded, size: 18),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (s) => setState(() => _filter = s.first),
      ),
    );

    final Widget main;
    if (_filter == _LeaveFilter.mine) {
      main = const EmployeeLeaveScreen(bodyOnly: true);
    } else {
      final async = _filter == _LeaveFilter.pending
          ? ref.watch(pendingLeaveProvider)
          : ref.watch(allLeaveRequestsProvider);
      main = ArkaAsync<List<LeaveRequestRow>>(
        value: async,
        onRetry: () {
          if (_filter == _LeaveFilter.pending) {
            ref.invalidate(pendingLeaveProvider);
          } else {
            ref.invalidate(allLeaveRequestsProvider);
          }
        },
        data: (rows) {
          final list = _filter == _LeaveFilter.pending
              ? rows
              : (List<LeaveRequestRow>.from(rows)
                ..sort((a, b) => b.startDate.compareTo(a.startDate)));

          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  ArkaEmptyState(
                    icon: _filter == _LeaveFilter.pending
                        ? Icons.verified_outlined
                        : Icons.event_busy_outlined,
                    title: _filter == _LeaveFilter.pending
                        ? 'All caught up'
                        : 'No leave requests',
                    message: _filter == _LeaveFilter.pending
                        ? 'No pending leave requests.'
                        : 'Nothing on record yet.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _LeaveCard(row: list[i], onReview: _review),
            ),
          );
        },
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filterBar,
        Expanded(child: main),
      ],
    );

    if (widget.embedded) {
      return EmbeddedScaffold(
        title: 'Leave',
        subtitle: 'Approvals, team history, and your own leave',
        child: body,
      );
    }
    return AppScaffold(
      title: 'Leave',
      subtitle: 'Approvals, team history, and your own leave',
      child: body,
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.row, required this.onReview});

  final LeaveRequestRow row;
  final Future<void> Function(BuildContext, LeaveRequestRow, bool) onReview;

  @override
  Widget build(BuildContext context) {
    final name = row.employeeName?.isNotEmpty == true
        ? row.employeeName!
        : 'Employee';
    final range =
        '${DateFormat('dd MMM yyyy').format(row.startDate.toLocal())} – '
        '${DateFormat('dd MMM yyyy').format(row.endDate.toLocal())}';
    final pending = row.status == 'PENDING';

    final (tone, label) = switch (row.status) {
      'APPROVED' => (ArkaTone.success, 'Approved'),
      'REJECTED' => (ArkaTone.danger, 'Rejected'),
      'PENDING' => (ArkaTone.warning, 'Pending'),
      _ => (ArkaTone.neutral, row.status),
    };

    return Card(
      elevation: 0,
      color: context.cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArkaAvatar(name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.tt.titleMedium),
                      if (row.employeeCode != null &&
                          row.employeeCode!.isNotEmpty)
                        Text(row.employeeCode!,
                            style: context.tt.bodySmall),
                    ],
                  ),
                ),
                ArkaStatusChip(row.type, tone: ArkaTone.primary, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.date_range_rounded,
                    size: 18, color: context.cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$range · ${row.days} day${row.days == 1 ? '' : 's'}',
                      style: context.tt.bodyMedium),
                ),
                ArkaStatusChip(label, tone: tone, dot: true, compact: true),
              ],
            ),
            if (row.reason != null && row.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                row.reason!.trim(),
                style: context.tt.bodyMedium
                    ?.copyWith(color: context.cs.onSurfaceVariant),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onReview(context, row, false),
                      icon: Icon(Icons.close_rounded, color: context.cs.error),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onReview(context, row, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}