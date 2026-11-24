import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/leave/leave_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class EmployeeCalendarScreen extends ConsumerStatefulWidget {
  const EmployeeCalendarScreen({super.key});

  @override
  ConsumerState<EmployeeCalendarScreen> createState() =>
      _EmployeeCalendarScreenState();
}

class _EmployeeCalendarScreenState
    extends ConsumerState<EmployeeCalendarScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _year = n.year;
    _month = n.month;
  }

  void _shift(int delta) {
    setState(() {
      _month += delta;
      if (_month < 1) {
        _month = 12;
        _year--;
      } else if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(leaveCalendarProvider((_year, _month)));

    return AppScaffold(
      title: 'Calendar',
      subtitle: 'Holidays and your leave',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                    textAlign: TextAlign.center,
                    style: context.tt.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ArkaAsync<CalendarPayload>(
              value: cal,
              onRetry: () =>
                  ref.invalidate(leaveCalendarProvider((_year, _month))),
              data: (data) {
                final daysInMonth = DateTime(_year, _month + 1, 0).day;
                final firstWeekday =
                    DateTime(_year, _month, 1).weekday % 7; // Sun=0
                final holidayByDay = <int, List<HolidayRow>>{};
                for (final h in data.holidays) {
                  final d = h.date.toLocal();
                  if (d.year == _year && d.month == _month) {
                    holidayByDay.putIfAbsent(d.day, () => []).add(h);
                  }
                }
                final leaveByDay = <int, List<LeaveRequestRow>>{};
                void markLeave(LeaveRequestRow l) {
                  var cur = DateTime(l.startDate.year, l.startDate.month,
                      l.startDate.day);
                  final end = DateTime(
                      l.endDate.year, l.endDate.month, l.endDate.day);
                  while (!cur.isAfter(end)) {
                    if (cur.year == _year && cur.month == _month) {
                      leaveByDay.putIfAbsent(cur.day, () => []).add(l);
                    }
                    cur = cur.add(const Duration(days: 1));
                  }
                }

                for (final l in data.leaves) {
                  markLeave(l);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    Row(
                      children: [
                        _Legend(color: context.cs.tertiary, label: 'Holiday'),
                        const SizedBox(width: 12),
                        _Legend(
                            color: context.cs.primary, label: 'Approved leave'),
                        const SizedBox(width: 12),
                        _Legend(
                            color: context.palette.warning,
                            label: 'Pending leave'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: firstWeekday + daysInMonth,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemBuilder: (context, i) {
                        if (i < firstWeekday) return const SizedBox.shrink();
                        final day = i - firstWeekday + 1;
                        final hols = holidayByDay[day] ?? const [];
                        final leaves = leaveByDay[day] ?? const [];
                        Color? bg;
                        if (hols.isNotEmpty) {
                          bg = context.cs.tertiaryContainer;
                        } else if (leaves.any((l) => l.status == 'APPROVED')) {
                          bg = context.cs.primaryContainer;
                        } else if (leaves.any((l) => l.status == 'PENDING')) {
                          bg = context.palette.warningContainer;
                        }
                        return Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: context.cs.outlineVariant),
                          ),
                          child: Text(
                            '$day',
                            style: context.tt.bodyMedium?.copyWith(
                              fontWeight: hols.isNotEmpty || leaves.isNotEmpty
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const ArkaSectionTitle('This month'),
                    if (data.holidays.isEmpty && data.leaves.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No holidays or leave in this month.'),
                      ),
                    for (final h in data.holidays)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined,
                            color: context.cs.tertiary),
                        title: Text(h.name),
                        subtitle: Text(
                            DateFormat('EEE, dd MMM yyyy').format(h.date.toLocal())),
                      ),
                    for (final l in data.leaves)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.event_busy_outlined,
                          color: l.status == 'APPROVED'
                              ? context.cs.primary
                              : context.palette.warning,
                        ),
                        title: Text('${l.type} · ${l.status}'),
                        subtitle: Text(
                          '${DateFormat('dd MMM').format(l.startDate.toLocal())} – ${DateFormat('dd MMM').format(l.endDate.toLocal())} (${l.days}d)',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.tt.labelSmall),
      ],
    );
  }
}
