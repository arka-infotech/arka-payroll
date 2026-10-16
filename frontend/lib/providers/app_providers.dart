import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/network/api_client.dart';
import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/core/theme/theme_controller.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/auth/auth_state.dart';

// ── Infrastructure (overridden in main) ─────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('Override authRepositoryProvider in main'),
);

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (ref) => PayrollRepository(ref.watch(authRepositoryProvider)),
);

final authStateProvider = ChangeNotifierProvider<AuthState>(
  (ref) => throw UnimplementedError('Override authStateProvider in main'),
);

final themeControllerProvider = ChangeNotifierProvider<ThemeController>(
  (ref) => throw UnimplementedError('Override themeControllerProvider in main'),
);

/// Only network / server failures are worth retrying automatically.
Duration? arkaRetry(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  if (error is ApiException && error.statusCode < 500) return null;
  return Duration(seconds: 2 << retryCount);
}

/// Re-fetches the calling provider every [every] while a screen listens to
/// it. Auto-dispose providers stop refreshing once the screen is gone and
/// fetch fresh data when it comes back.
void autoRefresh(Ref ref, Duration every) {
  final timer = Timer(every, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

/// Call after any write so every screen shows fresh numbers.
void invalidatePayrollData(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(employeesProvider);
  ref.invalidate(periodSlipsProvider);
  ref.invalidate(payrollGridProvider);
  ref.invalidate(mySlipsProvider);
  ref.invalidate(adminUsersProvider);
}

// ── Pay period ──────────────────────────────────────────────────────────────

class PayPeriod {
  const PayPeriod(this.year, this.month);

  factory PayPeriod.now() {
    final n = DateTime.now();
    return PayPeriod(n.year, n.month);
  }

  final int year;
  final int month;

  PayPeriod get previous =>
      month == 1 ? PayPeriod(year - 1, 12) : PayPeriod(year, month - 1);
  PayPeriod get next =>
      month == 12 ? PayPeriod(year + 1, 1) : PayPeriod(year, month + 1);

  String get label => DateFormat('MMMM yyyy').format(DateTime(year, month));
  String get shortLabel => DateFormat('MMM yyyy').format(DateTime(year, month));
  bool get isCurrent {
    final n = DateTime.now();
    return n.year == year && n.month == month;
  }

  @override
  bool operator ==(Object other) =>
      other is PayPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class PayPeriodNotifier extends Notifier<PayPeriod> {
  @override
  PayPeriod build() => PayPeriod.now();

  void set(PayPeriod period) => state = period;
  void previous() => state = state.previous;
  void next() => state = state.next;
}

final payslipPeriodProvider =
    NotifierProvider<PayPeriodNotifier, PayPeriod>(PayPeriodNotifier.new);

final punchPeriodProvider =
    NotifierProvider<PayPeriodNotifier, PayPeriod>(PayPeriodNotifier.new);

// ── Dashboard ───────────────────────────────────────────────────────────────

class DashboardData {
  DashboardData({
    required this.activeEmployees,
    required this.pendingDrafts,
    required this.processedThisMonth,
    required this.slips,
    required this.fetchedAt,
  });

  final int activeEmployees;
  final int pendingDrafts;
  final int processedThisMonth;

  /// Slips for the current month, newest work first.
  final List<PeriodSlipRow> slips;
  final DateTime fetchedAt;

  int get toPunch =>
      (activeEmployees - processedThisMonth).clamp(0, activeEmployees);
  double get progress => activeEmployees == 0
      ? 0
      : (processedThisMonth / activeEmployees).clamp(0, 1);
  num get totalNet => slips.fold<num>(0, (s, r) => s + r.netPay);
}

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  autoRefresh(ref, const Duration(seconds: 30));
  final repo = ref.watch(payrollRepositoryProvider);
  final now = PayPeriod.now();
  final (stats, slips) = await (
    repo.fetchStats(),
    repo.fetchPeriodSlips(now.year, now.month),
  ).wait;
  return DashboardData(
    activeEmployees: parseApiNum(stats['activeEmployees']).toInt(),
    pendingDrafts: parseApiNum(stats['pendingSlips']).toInt(),
    processedThisMonth: parseApiNum(stats['processedThisMonth']).toInt(),
    slips: slips,
    fetchedAt: DateTime.now(),
  );
});

// ── People ──────────────────────────────────────────────────────────────────

final employeesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  autoRefresh(ref, const Duration(seconds: 45));
  return ref.watch(payrollRepositoryProvider).fetchUsers();
});

// ── Payslips / punch ────────────────────────────────────────────────────────

final periodSlipsProvider =
    FutureProvider.autoDispose<List<PeriodSlipRow>>((ref) async {
  final period = ref.watch(payslipPeriodProvider);
  autoRefresh(ref, const Duration(seconds: 45));
  return ref
      .watch(payrollRepositoryProvider)
      .fetchPeriodSlips(period.year, period.month);
});

final payrollGridProvider =
    FutureProvider.autoDispose<List<PayrollGridRow>>((ref) async {
  final period = ref.watch(punchPeriodProvider);
  autoRefresh(ref, const Duration(seconds: 60));
  return ref
      .watch(payrollRepositoryProvider)
      .fetchGrid(period.year, period.month);
});

final mySlipsProvider =
    FutureProvider.autoDispose<List<SlipSummary>>((ref) async {
  autoRefresh(ref, const Duration(seconds: 60));
  return ref.watch(payrollRepositoryProvider).fetchMySlips();
});

// ── Root console ────────────────────────────────────────────────────────────

final adminUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  autoRefresh(ref, const Duration(seconds: 20));
  final data = await ref.watch(authRepositoryProvider).api.get('/users')
      as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
});

final auditLogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  autoRefresh(ref, const Duration(seconds: 60));
  final data = await ref
      .watch(authRepositoryProvider)
      .api
      .get('/audit', query: {'limit': '100'}) as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
});
