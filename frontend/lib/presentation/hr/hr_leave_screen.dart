import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/leave/leave_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

/// HR: approve/reject leave requests.
class HrLeaveScreen extends ConsumerWidget {
  const HrLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingLeaveProvider);

    return AppScaffold(
      title: 'Leave approvals',
      subtitle: 'Review employee leave requests',
      child: ArkaAsync<List<LeaveRequestRow>>(
        value: pending,
        onRetry: () => ref.invalidate(pendingLeaveProvider),
        data: (rows) {
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                invalidateLeaveData(ref);
                await ref.read(pendingLeaveProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  ArkaEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'All caught up',
                    message: 'No pending leave requests.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              invalidateLeaveData(ref);
              await ref.read(pendingLeaveProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = rows[i];
                return ListTile(
                  title: Text(
                    r.employeeName?.isNotEmpty == true
                        ? r.employeeName!
                        : 'Employee',
                    style: context.tt.titleSmall,
                  ),
                  subtitle: Text(
                    '${r.type} · ${r.days}d\n'
                    '${DateFormat('dd MMM yyyy').format(r.startDate.toLocal())}'
                    ' – ${DateFormat('dd MMM yyyy').format(r.endDate.toLocal())}'
                    '${r.reason == null || r.reason!.isEmpty ? '' : '\n${r.reason}'}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reject',
                        onPressed: () => _review(context, ref, r, false),
                        icon: Icon(Icons.close_rounded,
                            color: context.cs.error),
                      ),
                      IconButton(
                        tooltip: 'Approve',
                        onPressed: () => _review(context, ref, r, true),
                        icon: Icon(Icons.check_circle_rounded,
                            color: context.cs.primary),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
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
}
