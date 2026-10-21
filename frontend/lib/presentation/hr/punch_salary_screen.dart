import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

(ArkaTone, String) _rowStatus(PayrollGridRow r) {
  if (r.isLocked) return (ArkaTone.success, 'Locked');
  if (r.existingStatus == 'DRAFT') return (ArkaTone.warning, 'Draft');
  if (!r.hasStructure) return (ArkaTone.danger, 'No pay package');
  return (ArkaTone.info, 'Ready');
}

class PunchSalaryScreen extends ConsumerStatefulWidget {
  const PunchSalaryScreen(
      {super.key, this.initialUserId, this.initialYear, this.initialMonth});

  final String? initialUserId;
  final int? initialYear;
  final int? initialMonth;

  @override
  ConsumerState<PunchSalaryScreen> createState() => _PunchSalaryScreenState();
}

class _PunchSalaryScreenState extends ConsumerState<PunchSalaryScreen> {
  String? _selectedId;

  /// On narrow layouts, list is primary; true when editing one employee.
  bool _mobileEditing = false;

  /// Copy server values into the form on the next data load (after a period
  /// change or a save) — background refreshes never overwrite typing.
  bool _resync = true;
  bool _busy = false;

  /// A [String] for local validation, otherwise a thrown error.
  Object? _formError;
  String? _daysWarning;

  final _daysCtrl = TextEditingController();
  final _lopCtrl = TextEditingController(text: '0');
  final _bonusCtrl = TextEditingController(text: '0');
  final _otherCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialUserId;
    if (widget.initialUserId != null) _mobileEditing = true;
    final y = widget.initialYear;
    final m = widget.initialMonth;
    if (y != null && m != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(punchPeriodProvider.notifier).set(PayPeriod(y, m)),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_daysCtrl, _lopCtrl, _bonusCtrl, _otherCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  PayPeriod get _period => ref.read(punchPeriodProvider);

  void _applyRows(List<PayrollGridRow> rows) {
    if (!mounted || rows.isEmpty) return;
    final current = rows.where((r) => r.userId == _selectedId).firstOrNull;
    if (current == null) {
      // Wide: keep a selection for the detail pane. Narrow: list-only until tap.
      final wide = MediaQuery.sizeOf(context).width >= 1000;
      if (wide) {
        _loadForm(rows.first);
      } else {
        _selectedId = null;
        _mobileEditing = false;
        if (mounted) setState(() {});
      }
    } else if (_resync) {
      _loadForm(current);
    }
  }

  void _loadForm(PayrollGridRow s) {
    _resync = false;
    _selectedId = s.userId;
    _formError = null;
    _daysCtrl.text = '${s.workingDaysInMonth}';
    _lopCtrl.text = '${s.unpaidLeaveDays}';
    _bonusCtrl.text = s.bonus == 0 ? '0' : s.bonus.toStringAsFixed(0);
    _otherCtrl.text =
        s.otherEarnings == 0 ? '0' : s.otherEarnings.toStringAsFixed(0);
    _notesCtrl.text = s.slipNotes ?? '';
    _validateDays(s);
    if (mounted) setState(() {});
  }

  void _openEmployee(PayrollGridRow s, {required bool wide}) {
    _loadForm(s);
    if (!wide) {
      setState(() => _mobileEditing = true);
    }
  }

  void _closeMobileEditor() {
    setState(() {
      _mobileEditing = false;
      _formError = null;
    });
  }

  void _validateDays(PayrollGridRow s) {
    final days = int.tryParse(_daysCtrl.text) ?? 0;
    _daysWarning = days > s.calendarDaysInMonth
        ? 'Only ${s.calendarDaysInMonth} days in ${_period.label}'
        : null;
  }

  double? _lopEstimate(PayrollGridRow s) {
    if (s.monthlyCtc == null) return null;
    final days = int.tryParse(_daysCtrl.text) ?? 0;
    final lop = int.tryParse(_lopCtrl.text) ?? 0;
    if (days <= 0) return 0;
    return s.monthlyCtc!.toDouble() * lop / days;
  }

  int? _workingDays() {
    final d = int.tryParse(_daysCtrl.text.trim());
    return d == null || d <= 0 ? null : d;
  }

  void _changePeriod(PayPeriod p) {
    _resync = true;
    _mobileEditing = false;
    ref.read(punchPeriodProvider.notifier).set(p);
  }

  void _refreshAfterWrite() {
    _resync = true;
    invalidatePayrollData(ref);
  }

  Future<void> _saveDraft(PayrollGridRow s) async {
    final days = _workingDays();
    if (days == null) {
      setState(() => _formError = 'Enter how many days were worked.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await ref.read(payrollRepositoryProvider).saveDraft(
            userId: s.userId,
            year: _period.year,
            month: _period.month,
            workingDaysInMonth: days,
            unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
            bonus: double.tryParse(_bonusCtrl.text) ?? 0,
            specialAdjustment: 0,
            otherEarnings: double.tryParse(_otherCtrl.text) ?? 0,
            slipNotes: _notesCtrl.text,
          );
      if (!mounted) return;
      ArkaSnack.success(
          context, 'Draft saved for ${s.name} — editable until you lock it');
      _refreshAfterWrite();
    } catch (e) {
      if (mounted) setState(() => _formError = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(PayrollGridRow s) async {
    if (!s.hasStructure) {
      setState(() => _formError =
          '${s.name} has no pay package yet. Add one from their profile first.');
      return;
    }
    final days = _workingDays();
    if (days == null) {
      setState(() => _formError = 'Enter how many days were worked.');
      return;
    }
    if (_daysWarning != null) {
      setState(() => _formError = _daysWarning);
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final preview = await ref.read(payrollRepositoryProvider).preview(
            userId: s.userId,
            year: _period.year,
            month: _period.month,
            workingDaysInMonth: days,
            unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
            bonus: double.tryParse(_bonusCtrl.text) ?? 0,
            specialAdjustment: 0,
            otherEarnings: double.tryParse(_otherCtrl.text) ?? 0,
            slipNotes: _notesCtrl.text,
          );
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (_) => _PreviewSheet(
          preview: preview,
          locked: s.isLocked,
          name: s.name,
          period: _period,
        ),
      );
      if (confirmed == true) await _submit(s, days);
    } catch (e) {
      if (mounted) setState(() => _formError = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(PayrollGridRow s, int days) async {
    final notes = _notesCtrl.text.trim();
    try {
      // Re-locking a locked month just updates the existing slip.
      await ref.read(payrollRepositoryProvider).processOne(
            userId: s.userId,
            year: _period.year,
            month: _period.month,
            workingDaysInMonth: days,
            unpaidLeaveDays: int.tryParse(_lopCtrl.text) ?? 0,
            bonus: double.tryParse(_bonusCtrl.text) ?? 0,
            specialAdjustment: 0,
            otherEarnings: double.tryParse(_otherCtrl.text) ?? 0,
            slipNotes: notes.isEmpty ? null : notes,
          );
      if (!mounted) return;
      ArkaSnack.success(
        context,
        s.isLocked
            ? 'Slip updated for ${s.name} — email will retry in the background'
            : 'Salary locked for ${s.name} — check Dashboard for email status',
      );
      _refreshAfterWrite();
    } catch (e) {
      if (mounted) setState(() => _formError = e);
    }
  }

  Future<void> _downloadPdf(String payrollId) async {
    try {
      final bundle =
          await ref.read(payrollRepositoryProvider).fetchPdfBundle(payrollId);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(bundle.bytes), filename: bundle.filename);
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(punchPeriodProvider);
    final grid = ref.watch(payrollGridProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final rows = grid.value ?? const <PayrollGridRow>[];
    final selected = rows.where((r) => r.userId == _selectedId).firstOrNull;
    if (rows.isNotEmpty &&
        !grid.isLoading &&
        ((wide && selected == null) || _resync)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyRows(rows));
    }

    final showEditor = wide || (_mobileEditing && selected != null);

    return AppScaffold(
      title: 'Punch salary',
      subtitle: showEditor && selected != null && !wide
          ? selected.name
          : 'Attendance and variables for ${period.label}',
      bottomBar: !showEditor || selected == null
          ? null
          : ArkaBottomBar(
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _saveDraft(selected),
                  child: const ArkaBusyLabel(
                      busy: false,
                      label: 'Save draft',
                      icon: Icons.save_outlined),
                ),
                FilledButton(
                  onPressed: _busy || !selected.hasStructure
                      ? null
                      : () => _preview(selected),
                  child: ArkaBusyLabel(
                    busy: _busy,
                    label:
                        selected.isLocked ? 'Recalculate' : 'Calculate & lock',
                    icon: Icons.lock_outline_rounded,
                  ),
                ),
              ],
            ),
      child: ArkaAsync<List<PayrollGridRow>>(
        value: grid,
        onRetry: () => ref.invalidate(payrollGridProvider),
        data: (rows) {
          final header = _Header(
              period: period, rows: rows, onPeriod: _changePeriod, wide: wide);
          if (rows.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const Expanded(
                  child: ArkaEmptyState(
                    icon: Icons.group_off_outlined,
                    title: 'No one to pay yet',
                    message:
                        'Add employees with a pay package from People, then punch their salary here.',
                  ),
                ),
              ],
            );
          }

          // Narrow: full-screen editor after tapping a list row.
          if (!wide && _mobileEditing && selected != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconButton(
                    tooltip: 'Back to list',
                    onPressed: _closeMobileEditor,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: Text(selected.name, style: context.tt.titleMedium),
                  subtitle: Text(
                    [
                      selected.designation ?? 'Employee',
                      if (selected.employeeCode != null) selected.employeeCode!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ArkaStatusChip(
                    _rowStatus(selected).$2,
                    tone: _rowStatus(selected).$1,
                    dot: true,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: _form(selected, false),
                  ),
                ),
              ],
            );
          }

          final form =
              selected == null ? const <Widget>[] : _form(selected, wide);

          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 330,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: _EmployeeList(
                            rows: rows,
                            selectedId: _selectedId,
                            onSelect: (r) => _openEmployee(r, wide: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: form.isEmpty
                            ? const ArkaEmptyState(
                                icon: Icons.touch_app_outlined,
                                title: 'Select an employee',
                                message:
                                    'Choose someone from the list to set attendance or lock their slip.',
                              )
                            : ListView(
                                padding: const EdgeInsets.only(bottom: 24),
                                children: form,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Narrow: employee list is the main screen.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              const _GeneralHint(),
              const SizedBox(height: 10),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: _EmployeeList(
                    rows: rows,
                    selectedId: null,
                    onSelect: (r) => _openEmployee(r, wide: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Form blocks, each preceded by spacing so they slot into any list.
  List<Widget> _form(PayrollGridRow s, bool wide) {
    final lopEstimate = _lopEstimate(s);
    final ctc = s.monthlyCtc?.toDouble();
    final bonus = double.tryParse(_bonusCtrl.text) ?? 0;
    final other = double.tryParse(_otherCtrl.text) ?? 0;
    final amount = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
    ];
    final (tone, status) = _rowStatus(s);
    final error = _formError;

    final blocks = <Widget>[
      if (wide)
        ArkaCard(
          child: Row(
            children: [
              ArkaAvatar(s.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: context.tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      [
                        s.designation ?? 'No designation',
                        if (s.employeeCode != null) s.employeeCode!
                      ].join(' · '),
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ),
              ArkaStatusChip(status, tone: tone, dot: true),
              if (s.existingPayrollId != null) ...[
                const SizedBox(width: 12),
                IconButton.outlined(
                  tooltip: 'View slip',
                  onPressed: () => context.push('/slip/${s.existingPayrollId}'),
                  icon: const Icon(Icons.visibility_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Download PDF',
                  onPressed: () => _downloadPdf(s.existingPayrollId!),
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ],
          ),
        ),
      if (!wide && s.existingPayrollId != null)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/slip/${s.existingPayrollId}'),
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: const Text('View slip'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _downloadPdf(s.existingPayrollId!),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      if (error != null)
        error is String
            ? ArkaInlineAlert(
                message: error,
                tone: ArkaAlertTone.warning,
                onDismiss: () => setState(() => _formError = null),
              )
            : ArkaInlineAlert.fromError(error,
                onDismiss: () => setState(() => _formError = null)),
      if (!s.hasStructure)
        ArkaInlineAlert(
          tone: ArkaAlertTone.warning,
          title: 'No pay package',
          message:
              'Set ${s.name}’s monthly salary before you can calculate and lock this slip.',
          action: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final saved =
                    await context.push<bool>('/employees/${s.userId}/edit');
                if (saved == true && mounted) _refreshAfterWrite();
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Open profile'),
            ),
          ),
        ),
      if (s.isLocked)
        ArkaInlineAlert(
          tone: ArkaAlertTone.info,
          title: '${_period.label} is locked',
          message: 'Saving or locking again updates the existing slip.',
        ),
      ArkaFormSection(
        icon: Icons.event_available_rounded,
        title: 'Attendance',
        subtitle: '${s.calendarDaysInMonth} calendar days in ${_period.label}',
        trailing: TextButton(
          onPressed: () {
            _daysCtrl.text = '${s.calendarDaysInMonth}';
            _lopCtrl.text = '0';
            setState(() => _validateDays(s));
          },
          child: const Text('Full month'),
        ),
        children: [
          ArkaFieldRow(
            breakpoint: 420,
            children: [
              TextField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2)
                ],
                decoration: InputDecoration(
                    labelText: 'Days worked',
                    suffixText: 'days',
                    errorText: _daysWarning),
                onChanged: (_) => setState(() => _validateDays(s)),
              ),
              TextField(
                controller: _lopCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2)
                ],
                decoration: InputDecoration(
                  labelText: 'Unpaid leave (LOP)',
                  suffixText: 'days',
                  helperText: lopEstimate == null
                      ? null
                      : 'Deduction ≈ ${Fmt.inr(lopEstimate)}',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
      ArkaFormSection(
        icon: Icons.add_card_rounded,
        title: 'Additional earnings',
        subtitle: 'One-off amounts for this month only',
        children: [
          ArkaFieldRow(
            breakpoint: 420,
            children: [
              TextField(
                controller: _bonusCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amount,
                decoration: const InputDecoration(
                    labelText: 'Bonus / arrears', prefixText: '₹ '),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _otherCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amount,
                decoration: const InputDecoration(
                    labelText: 'Other earnings', prefixText: '₹ '),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ],
      ),
      ArkaFormSection(
        icon: Icons.sticky_note_2_outlined,
        title: 'Note on payslip',
        subtitle: 'Optional — printed at the bottom of the PDF',
        children: [
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
                hintText: 'e.g. Includes Diwali bonus, leave balance 4 days…'),
          ),
        ],
      ),
      if (ctc != null)
        _EstimateCard(
            monthly: ctc, lop: lopEstimate ?? 0, extras: bonus + other),
    ];

    return [
      for (var i = 0; i < blocks.length; i++) ...[
        if (i > 0 || !wide) const SizedBox(height: 14),
        blocks[i],
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.period,
      required this.rows,
      required this.onPeriod,
      required this.wide});

  final PayPeriod period;
  final List<PayrollGridRow> rows;
  final ValueChanged<PayPeriod> onPeriod;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    int count(String label) =>
        rows.where((r) => _rowStatus(r).$2 == label).length;
    final missing = count('No pay package');
    final chips = [
      ArkaStatusChip('${count('Locked')} locked',
          tone: ArkaTone.success, dot: true),
      ArkaStatusChip('${count('Draft')} drafts',
          tone: ArkaTone.warning, dot: true),
      ArkaStatusChip('${count('Ready')} ready', tone: ArkaTone.info, dot: true),
      if (missing > 0)
        ArkaStatusChip('$missing need pay package',
            tone: ArkaTone.danger, dot: true),
    ];
    final switcher = ArkaMonthSwitcher(period: period, onChanged: onPeriod);

    if (wide) {
      return Row(
        children: [
          SizedBox(width: 330, child: switcher),
          const SizedBox(width: 20),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        switcher,
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

class _EmployeeList extends StatefulWidget {
  const _EmployeeList({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    this.scrollController,
  });

  final List<PayrollGridRow> rows;
  final String? selectedId;
  final ValueChanged<PayrollGridRow> onSelect;
  final ScrollController? scrollController;

  @override
  State<_EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<_EmployeeList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.rows
        : widget.rows
            .where((r) =>
                '${r.name} ${r.employeeCode ?? ''} ${r.designation ?? ''}'
                    .toLowerCase()
                    .contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search employees',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const ArkaEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try another name or ID.')
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final (tone, label) = _rowStatus(r);
                    final sub = [
                      if (r.designation != null && r.designation!.isNotEmpty)
                        r.designation!,
                      if (r.employeeCode != null) r.employeeCode!,
                      '${r.workingDaysInMonth}d',
                      if (r.unpaidLeaveDays > 0) 'LOP ${r.unpaidLeaveDays}',
                    ].join(' · ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        selected: r.userId == widget.selectedId,
                        onTap: () => widget.onSelect(r),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        leading: ArkaAvatar(r.name, size: 40),
                        title: Text(r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleSmall),
                        subtitle: Text(sub.isEmpty ? '—' : sub,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ArkaStatusChip(label, tone: tone),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                color: context.cs.onSurfaceVariant),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GeneralHint extends StatelessWidget {
  const _GeneralHint();

  @override
  Widget build(BuildContext context) {
    return ArkaInlineAlert(
      tone: ArkaAlertTone.info,
      title: 'How punch works',
      message:
          'Each employee starts from their saved days and amounts for this month. Tap a person to customize attendance, bonus, notes, or lock their slip.',
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard(
      {required this.monthly, required this.lop, required this.extras});

  final double monthly;
  final double lop;
  final double extras;

  @override
  Widget build(BuildContext context) {
    final fg = context.cs.onSecondaryContainer;
    Widget line(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                  child: Text(k,
                      style: context.tt.bodyMedium?.copyWith(color: fg))),
              Text(
                v,
                style: (strong ? context.tt.titleMedium : context.tt.bodyMedium)
                    ?.copyWith(
                  color: fg,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick estimate',
              style: context.tt.titleSmall?.copyWith(color: fg)),
          const SizedBox(height: 8),
          line('Monthly package', Fmt.inr(monthly)),
          line('LOP deduction', '− ${Fmt.inr(lop)}'),
          line('Bonus & other', '+ ${Fmt.inr(extras)}'),
          Divider(color: fg.withValues(alpha: 0.2), height: 18),
          line('Estimated gross', Fmt.inr(monthly - lop + extras),
              strong: true),
          const SizedBox(height: 4),
          Text(
            'Exact tax and deductions appear in the preview before locking.',
            style: context.tt.bodySmall
                ?.copyWith(color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet(
      {required this.preview,
      required this.locked,
      required this.name,
      required this.period});

  final Map<String, dynamic> preview;
  final bool locked;
  final String name;
  final PayPeriod period;

  @override
  Widget build(BuildContext context) {
    final lop = parseApiNum(preview['lopDeductionEstimate']);
    final p = context.palette;

    final earnings = [
      ('Basic', preview['basicEarned']),
      ('HRA', preview['hraEarned']),
      ('Special allowance', preview['specialAllowanceEarned']),
      ('Travel / conveyance', preview['conveyanceEarned']),
      ('Other fixed', preview['medicalEarned']),
      ('Bonus', preview['bonus']),
      ('Other', preview['otherEarnings']),
    ];
    final deductions = [
      ('EPF', preview['epfEmployee']),
      ('ESIC', preview['esicEmployee']),
      ('Professional tax', preview['professionalTax']),
      ('TDS', preview['tds']),
    ];

    Widget table(String title, List<(String, dynamic)> rows, String totalLabel,
        dynamic total) {
      final shown = rows.where((r) => parseApiNum(r.$2) != 0).toList();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title.toUpperCase(), style: context.tt.labelSmall),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                Text('None', style: context.tt.bodySmall)
              else
                for (final (k, v) in shown)
                  _Line(label: k, value: parseApiNum(v)),
              const Divider(height: 20),
              _Line(label: totalLabel, value: parseApiNum(total), bold: true),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ArkaAvatar(name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.tt.titleLarge),
                    Text('Payroll preview · ${period.label}',
                        style: context.tt.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [p.heroStart, p.heroEnd]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NET PAY',
                    style: context.tt.labelSmall
                        ?.copyWith(color: Colors.white70, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(
                  Fmt.inr(parseApiNum(preview['netPay'])),
                  style:
                      context.tt.headlineMedium?.copyWith(color: Colors.white),
                ),
                if (lop > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Includes LOP deduction of ${Fmt.inr(lop)}',
                    style:
                        context.tt.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final e = table(
                  'Earnings', earnings, 'Gross', preview['grossEarnings']);
              final d = table('Deductions', deductions, 'Total deductions',
                  preview['totalDeductions']);
              if (c.maxWidth > 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: e),
                    const SizedBox(width: 12),
                    Expanded(child: d)
                  ],
                );
              }
              return Column(children: [e, const SizedBox(height: 12), d]);
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_rounded),
            label: Text(locked ? 'Update locked slip' : 'Confirm & lock slip'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back to edit'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final num value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.tt.titleSmall : context.tt.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: style?.copyWith(
                      color: bold ? null : context.cs.onSurfaceVariant))),
          Text(Fmt.inr(value), style: style),
        ],
      ),
    );
  }
}
