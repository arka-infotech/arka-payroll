import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';

class LeaveTypeBalance {
  LeaveTypeBalance({
    required this.total,
    required this.used,
    required this.pending,
    required this.remaining,
  });

  final int total;
  final int used;
  final int pending;
  final int remaining;

  factory LeaveTypeBalance.fromJson(Map<String, dynamic> json) =>
      LeaveTypeBalance(
        total: parseApiNum(json['total'] ?? json['totalDays']).toInt(),
        used: parseApiNum(json['used'] ?? json['usedDays']).toInt(),
        pending: parseApiNum(json['pending'] ?? json['pendingDays']).toInt(),
        remaining: parseApiNum(json['remaining'] ?? json['remainingDays']).toInt(),
      );
}

class LeaveBalance {
  LeaveBalance({
    required this.year,
    required this.totalDays,
    required this.usedDays,
    required this.pendingDays,
    required this.remainingDays,
    required this.hasQuota,
    this.casual,
    this.earned,
    this.earnedNote,
  });

  final int year;
  final int totalDays;
  final int usedDays;
  final int pendingDays;
  final int remainingDays;
  final bool hasQuota;
  final LeaveTypeBalance? casual;
  final LeaveTypeBalance? earned;
  final String? earnedNote;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    final earnedMap = json['earned'] is Map<String, dynamic>
        ? json['earned'] as Map<String, dynamic>
        : null;
    return LeaveBalance(
      year: parseApiNum(json['year']).toInt(),
      totalDays: parseApiNum(json['totalDays']).toInt(),
      usedDays: parseApiNum(json['usedDays']).toInt(),
      pendingDays: parseApiNum(json['pendingDays']).toInt(),
      remainingDays: parseApiNum(json['remainingDays']).toInt(),
      hasQuota: json['hasQuota'] as bool? ?? false,
      casual: json['casual'] is Map<String, dynamic>
          ? LeaveTypeBalance.fromJson(json['casual'] as Map<String, dynamic>)
          : null,
      earned: earnedMap != null ? LeaveTypeBalance.fromJson(earnedMap) : null,
      earnedNote: earnedMap?['note'] as String?,
    );
  }
}

class LeaveRequestRow {
  LeaveRequestRow({
    required this.id,
    required this.userId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.reason,
    this.employeeName,
    this.employeeCode,
    this.reviewNote,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String status;
  final String? reason;
  final String? employeeName;
  final String? employeeCode;
  final String? reviewNote;

  factory LeaveRequestRow.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return LeaveRequestRow(
      id: json['id'] as String,
      userId: (json['userId'] ?? user?['id'] ?? '') as String,
      type: json['type'] as String? ?? 'CASUAL',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      days: parseApiNum(json['days']).toInt(),
      status: json['status'] as String? ?? 'PENDING',
      reason: json['reason'] as String?,
      employeeName: user == null
          ? null
          : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
      employeeCode: user?['employeeCode'] as String?,
      reviewNote: json['reviewNote'] as String?,
    );
  }
}

class HolidayRow {
  HolidayRow({
    required this.id,
    required this.date,
    required this.name,
    required this.isNational,
  });

  final String id;
  final DateTime date;
  final String name;
  final bool isNational;

  factory HolidayRow.fromJson(Map<String, dynamic> json) => HolidayRow(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        name: json['name'] as String? ?? 'Holiday',
        isNational: json['isNational'] as bool? ?? true,
      );
}

class CalendarPayload {
  CalendarPayload({
    required this.year,
    required this.month,
    required this.holidays,
    required this.leaves,
    required this.teamLeaves,
    this.balance,
  });

  final int year;
  final int month;
  final List<HolidayRow> holidays;
  final List<LeaveRequestRow> leaves;
  final List<LeaveRequestRow> teamLeaves;
  final LeaveBalance? balance;

  factory CalendarPayload.fromJson(Map<String, dynamic> json) =>
      CalendarPayload(
        year: parseApiNum(json['year']).toInt(),
        month: parseApiNum(json['month']).toInt(),
        holidays: [
          for (final h in (json['holidays'] as List? ?? []))
            HolidayRow.fromJson(h as Map<String, dynamic>),
        ],
        leaves: [
          for (final l in (json['leaves'] as List? ?? []))
            LeaveRequestRow.fromJson(l as Map<String, dynamic>),
        ],
        teamLeaves: [
          for (final l in (json['teamLeaves'] as List? ?? []))
            LeaveRequestRow.fromJson(l as Map<String, dynamic>),
        ],
        balance: json['balance'] is Map<String, dynamic>
            ? LeaveBalance.fromJson(json['balance'] as Map<String, dynamic>)
            : null,
      );
}

class LeaveRepository {
  LeaveRepository(this._auth);

  final AuthRepository _auth;

  Future<LeaveBalance> myBalance({int? year}) async {
    final q = year == null ? null : {'year': '$year'};
    final raw = await _auth.api.get('/leave/me/balance', query: q);
    return LeaveBalance.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<LeaveRequestRow>> myRequests() async {
    final raw = await _auth.api.get('/leave/me/requests') as List;
    return [
      for (final r in raw) LeaveRequestRow.fromJson(r as Map<String, dynamic>)
    ];
  }

  Future<LeaveRequestRow> applyLeave({
    required String type,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final raw = await _auth.api.post('/leave/me/requests', body: {
      'type': type,
      'startDate': startDate,
      'endDate': endDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return LeaveRequestRow.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> cancelMine(String id) async {
    await _auth.api.post('/leave/me/requests/$id/cancel');
  }

  Future<CalendarPayload> calendar({
    required int year,
    required int month,
    String? userId,
  }) async {
    final raw = await _auth.api.get('/leave/calendar', query: {
      'year': '$year',
      'month': '$month',
      if (userId != null) 'userId': userId,
    });
    return CalendarPayload.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<LeaveRequestRow>> pending() async {
    final raw = await _auth.api.get('/leave/pending') as List;
    return [
      for (final r in raw) LeaveRequestRow.fromJson(r as Map<String, dynamic>)
    ];
  }

  Future<List<LeaveRequestRow>> allRequests({String? status}) async {
    final raw = await _auth.api.get('/leave/requests', query: {
      if (status != null) 'status': status,
    }) as List;
    return [
      for (final r in raw) LeaveRequestRow.fromJson(r as Map<String, dynamic>)
    ];
  }

  Future<void> review({
    required String id,
    required String status,
    String? note,
  }) async {
    await _auth.api.patch('/leave/requests/$id/review', body: {
      'status': status,
      if (note != null && note.isNotEmpty) 'reviewNote': note,
    });
  }

  Future<LeaveBalance> getQuota(String userId, {int? year}) async {
    final raw = await _auth.api.get('/leave/quota/$userId', query: {
      if (year != null) 'year': '$year',
    });
    return LeaveBalance.fromJson(raw as Map<String, dynamic>);
  }

  Future<void> setQuota({
    required String userId,
    required int year,
    required int totalDays,
  }) async {
    await _auth.api.put('/leave/quota/$userId', body: {
      'year': year,
      'totalDays': totalDays,
    });
  }

  Future<List<HolidayRow>> holidays({int? year}) async {
    final raw = await _auth.api.get('/leave/holidays', query: {
      if (year != null) 'year': '$year',
    }) as List;
    return [
      for (final h in raw) HolidayRow.fromJson(h as Map<String, dynamic>)
    ];
  }
}
