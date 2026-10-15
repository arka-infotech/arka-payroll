import 'package:arka_payroll/data/auth/auth_repository.dart';

class PayrollGridRow {
  PayrollGridRow({
    required this.userId,
    required this.name,
    this.employeeCode,
    this.designation,
    required this.hasStructure,
    this.monthlyCtc,
    this.existingPayrollId,
    this.unpaidLeaveDays = 0,
    this.bonus = 0,
    this.specialAdjustment = 0,
    this.otherEarnings = 0,
    this.workingDaysInMonth = 22,
  });

  final String userId;
  final String name;
  final String? employeeCode;
  final String? designation;
  final bool hasStructure;
  final num? monthlyCtc;
  final String? existingPayrollId;

  int unpaidLeaveDays;
  double bonus;
  double specialAdjustment;
  double otherEarnings;
  int workingDaysInMonth;

  factory PayrollGridRow.fromJson(Map<String, dynamic> json) {
    final existing = json['existingPayroll'] as Map<String, dynamic>?;
    return PayrollGridRow(
      userId: json['userId'] as String,
      name: json['name'] as String,
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
      hasStructure: json['hasStructure'] as bool? ?? false,
      monthlyCtc: json['monthlyCtc'] as num?,
      existingPayrollId: existing?['id'] as String?,
      unpaidLeaveDays: (existing?['unpaidLeaveDays'] as num?)?.toInt() ?? 0,
      bonus: (existing?['bonus'] as num?)?.toDouble() ?? 0,
      specialAdjustment: (existing?['specialAdjustment'] as num?)?.toDouble() ?? 0,
      otherEarnings: (existing?['otherEarnings'] as num?)?.toDouble() ?? 0,
      workingDaysInMonth: (existing?['workingDaysInMonth'] as num?)?.toInt() ?? 22,
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
  });

  final String id;
  final int year;
  final int month;
  final num netPay;
  final String trackingReference;
  final String status;

  factory SlipSummary.fromJson(Map<String, dynamic> json) {
    return SlipSummary(
      id: json['id'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      netPay: json['netPay'] as num,
      trackingReference: json['trackingReference'] as String,
      status: json['status'] as String,
    );
  }
}

class PayrollRepository {
  PayrollRepository(this._auth);

  final AuthRepository _auth;

  Future<List<PayrollGridRow>> fetchGrid(int year, int month) async {
    final data = await _auth.api.get(
      '/payroll/grid',
      query: {'year': '$year', 'month': '$month'},
    ) as List<dynamic>;
    return data
        .map((e) => PayrollGridRow.fromJson(e as Map<String, dynamic>))
        .toList();
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
    }) as Map<String, dynamic>;
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
}
