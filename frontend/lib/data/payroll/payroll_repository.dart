import 'package:arka_payroll/core/parse_api_num.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';

class PayrollGridRow {
  PayrollGridRow({
    required this.userId,
    required this.name,
    this.employeeCode,
    this.designation,
    this.pan,
    this.uan,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.email,
    required this.hasStructure,
    this.monthlyCtc,
    this.calendarDaysInMonth = 30,
    this.existingPayrollId,
    this.existingStatus,
    this.unpaidLeaveDays = 0,
    this.bonus = 0,
    this.specialAdjustment = 0,
    this.otherEarnings = 0,
    this.workingDaysInMonth = 30,
    this.slipNotes,
  });

  final String userId;
  final String name;
  final String? employeeCode;
  final String? designation;
  final String? pan;
  final String? uan;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? email;
  final bool hasStructure;
  final num? monthlyCtc;
  final int calendarDaysInMonth;
  final String? existingPayrollId;
  final String? existingStatus;

  int unpaidLeaveDays;
  double bonus;
  double specialAdjustment;
  double otherEarnings;
  int workingDaysInMonth;
  String? slipNotes;

  bool get isLocked =>
      existingStatus == 'LOCKED' || existingStatus == 'PAID';

  factory PayrollGridRow.fromJson(Map<String, dynamic> json) {
    final existing = json['existingPayroll'] as Map<String, dynamic>?;
    return PayrollGridRow(
      userId: json['userId'] as String,
      name: json['name'] as String,
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
      pan: json['pan'] as String?,
      uan: json['uan'] as String?,
      bankName: json['bankName'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      email: json['email'] as String?,
      hasStructure: json['hasStructure'] as bool? ?? false,
      monthlyCtc: json['monthlyCtc'] == null
          ? null
          : parseApiNum(json['monthlyCtc']),
      calendarDaysInMonth:
          parseApiNum(json['calendarDaysInMonth'], fallback: 30).toInt(),
      existingPayrollId: existing?['id'] as String?,
      existingStatus: existing?['status'] as String?,
      unpaidLeaveDays: parseApiNum(existing?['unpaidLeaveDays']).toInt(),
      bonus: parseApiNum(existing?['bonus']).toDouble(),
      specialAdjustment: parseApiNum(existing?['specialAdjustment']).toDouble(),
      otherEarnings: parseApiNum(existing?['otherEarnings']).toDouble(),
      workingDaysInMonth: existing?['workingDaysInMonth'] != null
          ? parseApiNum(existing?['workingDaysInMonth']).toInt()
          : parseApiNum(json['calendarDaysInMonth'], fallback: 30).toInt(),
      slipNotes: existing?['slipNotes'] as String?,
    );
  }
}

class PeriodSlipRow {
  PeriodSlipRow({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.trackingReference,
    required this.status,
    required this.netPay,
  });

  final String id;
  final String userId;
  final String employeeName;
  final String trackingReference;
  final String status;
  final num netPay;

  bool get isDraft => status == 'DRAFT';

  factory PeriodSlipRow.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = user == null
        ? 'Employee'
        : '${user['firstName']} ${user['lastName']}';
    return PeriodSlipRow(
      id: json['id'] as String,
      userId: (json['userId'] ?? user?['id'] ?? '') as String,
      employeeName: name,
      trackingReference: json['trackingReference'] as String,
      status: json['status'] as String,
      netPay: parseApiNum(json['netPay']),
    );
  }
}

class SlipSummary {
  SlipSummary({
    required this.id,
    required this.year,
    required this.month,
    required this.netPay,
    required this.trackingReference,
    required this.status,
    this.grossEarnings,
  });

  final String id;
  final int year;
  final int month;
  final num netPay;
  final String trackingReference;
  final String status;
  final num? grossEarnings;

  factory SlipSummary.fromJson(Map<String, dynamic> json) {
    return SlipSummary(
      id: json['id'] as String,
      year: parseApiNum(json['year']).toInt(),
      month: parseApiNum(json['month']).toInt(),
      netPay: parseApiNum(json['netPay']),
      trackingReference: json['trackingReference'] as String,
      status: json['status'] as String,
      grossEarnings: json['grossEarnings'] != null
          ? parseApiNum(json['grossEarnings'])
          : null,
    );
  }
}

class PayrollRepository {
  PayrollRepository(this._auth);
  final AuthRepository _auth;

  Future<Map<String, dynamic>> fetchStats() async {
    return await _auth.api.get('/payroll/stats') as Map<String, dynamic>;
  }

  Future<List<PayrollGridRow>> fetchGrid(int year, int month) async {
    final data = await _auth.api.get(
      '/payroll/grid',
      query: {'year': '$year', 'month': '$month'},
    ) as List<dynamic>;
    return data
        .map((e) => PayrollGridRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> preview({
    required String userId,
    required int year,
    required int month,
    required int workingDaysInMonth,
    required int unpaidLeaveDays,
    required double bonus,
    required double specialAdjustment,
    required double otherEarnings,
    String? slipNotes,
  }) async {
    return await _auth.api.post('/payroll/preview', body: {
      'userId': userId,
      'year': year,
      'month': month,
      'workingDaysInMonth': workingDaysInMonth,
      'unpaidLeaveDays': unpaidLeaveDays,
      'bonus': bonus,
      'specialAdjustment': specialAdjustment,
      'otherEarnings': otherEarnings,
      if (slipNotes != null && slipNotes.trim().isNotEmpty)
        'slipNotes': slipNotes.trim(),
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveDraft({
    required String userId,
    required int year,
    required int month,
    required int workingDaysInMonth,
    required int unpaidLeaveDays,
    required double bonus,
    required double specialAdjustment,
    required double otherEarnings,
    String? slipNotes,
  }) async {
    return await _auth.api.post('/payroll/save-draft', body: {
      'userId': userId,
      'year': year,
      'month': month,
      'workingDaysInMonth': workingDaysInMonth,
      'unpaidLeaveDays': unpaidLeaveDays,
      'bonus': bonus,
      'specialAdjustment': specialAdjustment,
      'otherEarnings': otherEarnings,
      if (slipNotes != null && slipNotes.trim().isNotEmpty)
        'slipNotes': slipNotes.trim(),
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processOne({
    required String userId,
    required int year,
    required int month,
    required int workingDaysInMonth,
    required int unpaidLeaveDays,
    required double bonus,
    required double specialAdjustment,
    required double otherEarnings,
    String? slipNotes,
  }) async {
    return await _auth.api.post('/payroll/process', body: {
      'userId': userId,
      'year': year,
      'month': month,
      'workingDaysInMonth': workingDaysInMonth,
      'unpaidLeaveDays': unpaidLeaveDays,
      'bonus': bonus,
      'specialAdjustment': specialAdjustment,
      'otherEarnings': otherEarnings,
      if (slipNotes != null && slipNotes.trim().isNotEmpty)
        'slipNotes': slipNotes.trim(),
    }) as Map<String, dynamic>;
  }

  Future<List<PeriodSlipRow>> fetchPeriodSlips(int year, int month) async {
    final data = await _auth.api.get(
      '/payroll/period',
      query: {'year': '$year', 'month': '$month'},
    ) as List<dynamic>;
    return data
        .map((e) => PeriodSlipRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SlipSummary>> fetchMySlips() async {
    final data = await _auth.api.get('/payroll/my') as List<dynamic>;
    return data
        .map((e) => SlipSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<int>> fetchPdfBytes(String payrollId) {
    return _auth.api.getBytes('/payroll/$payrollId/pdf');
  }

  /// PDF bytes + official slip filename (`AIPS-YYYY-MM-CODE.pdf`).
  Future<({List<int> bytes, String filename})> fetchPdfBundle(
    String payrollId,
  ) async {
    final meta = await fetchSlip(payrollId);
    final ref = meta['trackingReference'] as String? ?? payrollId;
    final bytes = await fetchPdfBytes(payrollId);
    return (bytes: bytes, filename: '$ref.pdf');
  }

  Future<Map<String, dynamic>> saveSlipDocument(
    String payrollId,
    Map<String, dynamic> body,
  ) async {
    return await _auth.api.patch(
      '/payroll/$payrollId/document',
      body: body,
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchSlip(String payrollId) async {
    return await _auth.api.get('/payroll/$payrollId') as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final data = await _auth.api.get('/users') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchUser(String userId) async {
    return await _auth.api.get('/users/$userId') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async {
    return await _auth.api.post('/users', body: body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> body,
  ) async {
    return await _auth.api.patch(
      '/users/$userId',
      body: body,
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertSalaryStructure(
    String userId,
    Map<String, dynamic> body,
  ) async {
    return await _auth.api.put(
      '/users/$userId/salary-structure',
      body: body,
    ) as Map<String, dynamic>;
  }
}
