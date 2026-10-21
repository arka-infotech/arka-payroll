import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/parse_api_num.dart';

/// Builds an A4 payslip PDF on-device from `/payroll/:id` JSON (no server Chrome).
class SlipPdfBuilder {
  /// Rupee sign needs a Unicode font (Helvetica shows gibberish).
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static Future<List<int>> build(Map<String, dynamic> slip) async {
    final doc = slip['slipDocument'] as Map<String, dynamic>?;
    final user = slip['user'] as Map<String, dynamic>? ?? {};
    final year = parseApiNum(slip['year']).toInt();
    final month = parseApiNum(slip['month']).toInt();
    final monthLabel =
        (doc?['payslipMonth'] as String?)?.trim().isNotEmpty == true
            ? (doc!['payslipMonth'] as String).trim()
            : '${_months[month]} $year';
    final periodRange =
        (doc?['payPeriod'] as String?)?.trim().isNotEmpty == true
            ? (doc!['payPeriod'] as String).trim()
            : _formatPeriodRange(year, month);

    final company = (doc?['companyName'] as String?)?.trim().isNotEmpty == true
        ? (doc!['companyName'] as String).trim()
        : AppConfig.companyName;
    final location = (doc?['location'] as String?)?.trim().isNotEmpty == true
        ? (doc!['location'] as String).trim()
        : AppConfig.companyAddress;

    final employeeName =
        (doc?['employeeName'] as String?)?.trim().isNotEmpty == true
            ? (doc!['employeeName'] as String).trim()
            : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final employeeCode =
        (doc?['employeeCode'] as String?)?.trim().isNotEmpty == true
            ? (doc!['employeeCode'] as String).trim()
            : (user['employeeCode'] as String?) ?? '-';

    final paidDays = doc?['paidDays'] != null
        ? parseApiNum(doc!['paidDays']).toInt()
        : parseApiNum(slip['daysPayable']).toInt();
    final lopDays = doc?['lopDays'] != null
        ? parseApiNum(doc!['lopDays']).toInt()
        : parseApiNum(slip['unpaidLeaveDays']).toInt();
    final payDate = _formatPayDate(doc?['payDate'] ?? slip['payDate']);
    final notes = ((doc?['notes'] as String?) ?? slip['slipNotes'] as String?)
            ?.trim() ??
        '';

    final defaults = _defaultLines(slip);
    final earnings = _lines(doc?['earnings']) ?? defaults.$1;
    final deductions = _lines(doc?['deductions']) ?? defaults.$2;
    final gross = earnings.fold<double>(0, (s, e) => s + e.$2);
    final totalDed = deductions.fold<double>(0, (s, e) => s + e.$2);
    final net = doc?['earnings'] is List && (doc!['earnings'] as List).isNotEmpty
        ? gross - totalDed
        : parseApiNum(slip['netPay']).toDouble();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load(AppConfig.payslipLogo);
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      try {
        final bytes = await rootBundle.load(AppConfig.logoLight);
        logo = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    // Noto Sans covers ₹ and other Unicode; default Helvetica does not.
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();
    final muted = PdfColor.fromInt(0xFF8B919A);
    final ink = PdfColor.fromInt(0xFF1A1D23);
    final line = PdfColor.fromInt(0xFFE6E8EE);
    final greenBg = PdfColor.fromInt(0xFFF3FBF6);
    final green = PdfColor.fromInt(0xFF1F9D55);
    final brand = PdfColor.fromInt(0xFF14808F);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 24, 32, 28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (ctx) {
          final rows = [
            for (var i = 0;
                i <
                    (earnings.length > deductions.length
                        ? earnings.length
                        : deductions.length);
                i++)
              _earnDedRow(
                i < earnings.length ? earnings[i] : null,
                i < deductions.length ? deductions[i] : null,
              ),
          ];

          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null) ...[
                    pw.Image(logo, width: 40, height: 40),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(company,
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: ink)),
                        pw.SizedBox(height: 2),
                        pw.Text(location,
                            maxLines: 2,
                            style: pw.TextStyle(fontSize: 8, color: muted)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Payslip For the Month',
                          style: pw.TextStyle(fontSize: 9, color: muted)),
                      pw.SizedBox(height: 2),
                      pw.Text(monthLabel,
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: ink)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EMPLOYEE SUMMARY',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: muted,
                                letterSpacing: 0.6)),
                        pw.SizedBox(height: 10),
                        _kv('Employee Name', employeeName),
                        _kv('Employee ID', employeeCode),
                        _kv('Pay Period', periodRange),
                        _kv('Pay Date', payDate),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Container(
                    width: 200,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: line),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          color: greenBg,
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                  width: 3,
                                  height: 32,
                                  color: green,
                                  margin: const pw.EdgeInsets.only(right: 8)),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(_inr.format(net),
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                          color: ink)),
                                  pw.Text('Total Net Pay',
                                      style: pw.TextStyle(
                                          fontSize: 9, color: muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: pw.Column(
                            children: [
                              _dayRow('Paid Days', '$paidDays'),
                              _dayRow('LOP Days', '$lopDays'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: line, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.2),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(2.2),
                  3: const pw.FlexColumnWidth(1.1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F7F9)),
                    children: [
                      _th('EARNINGS'),
                      _th('AMOUNT', right: true),
                      _th('DEDUCTIONS'),
                      _th('AMOUNT', right: true),
                    ],
                  ),
                  ...rows,
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F7F9)),
                    children: [
                      _td('Gross Earnings', bold: true),
                      _td(_inr.format(gross), right: true, bold: true),
                      _td('Total Deductions', bold: true),
                      _td(_inr.format(totalDed), right: true, bold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: line),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TOTAL NET PAYABLE',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('Gross Earnings - Total Deductions',
                                style:
                                    pw.TextStyle(fontSize: 8, color: muted)),
                          ],
                        ),
                      ),
                    ),
                    pw.Container(
                      color: greenBg,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: pw.Text(_inr.format(net),
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Amount In Words : ${_inrWords(net)}',
                    style: pw.TextStyle(fontSize: 9, color: muted)),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: line),
              if (notes.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                    child: pw.Text(notes,
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 8, color: muted))),
              ],
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('-- This is a system-generated document. --',
                    style: pw.TextStyle(fontSize: 8, color: muted)),
              ),
              pw.SizedBox(height: 36),
                ],
              ),
              pw.Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (logo != null) ...[
                      pw.Image(logo, width: 16, height: 16),
                      pw.SizedBox(width: 6),
                    ],
                    pw.Text('Powered by Arka Payroll',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: brand,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _th(String t, {bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(t,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF8B919A),
                letterSpacing: 0.4)),
      );

  static pw.Widget _td(String t, {bool right = false, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(t,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.TableRow _earnDedRow(
    (String, double)? e,
    (String, double)? d,
  ) {
    return pw.TableRow(children: [
      _td(e?.$1 ?? ''),
      _td(e != null ? _inr.format(e.$2) : '', right: true),
      _td(d?.$1 ?? ''),
      _td(d != null ? _inr.format(d.$2) : '', right: true),
    ]);
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 88,
              child: pw.Text(k,
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColor.fromInt(0xFF6B7280)))),
          pw.SizedBox(
              width: 12,
              child: pw.Text(':',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColor.fromInt(0xFF9AA1AB)))),
          pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static pw.Widget _dayRow(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(k,
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColor.fromInt(0xFF4B5563)))),
          pw.Text(':',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColor.fromInt(0xFF9AA1AB))),
          pw.SizedBox(width: 8),
          pw.SizedBox(
              width: 28,
              child: pw.Text(v,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static List<(String, double)>? _lines(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final out = <(String, double)>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final label = '${item['label'] ?? ''}'.trim();
      if (label.isEmpty) continue;
      out.add((label, parseApiNum(item['amount']).toDouble()));
    }
    return out.isEmpty ? null : out;
  }

  static (List<(String, double)>, List<(String, double)>) _defaultLines(
    Map<String, dynamic> slip,
  ) {
    final earn = <(String, double)>[
      ('Basic', parseApiNum(slip['basicEarned']).toDouble()),
      ('House Rent Allowance', parseApiNum(slip['hraEarned']).toDouble()),
      ('Travel allowance', parseApiNum(slip['conveyanceEarned']).toDouble()),
    ];
    final special = parseApiNum(slip['specialAllowanceEarned']).toDouble();
    final medical = parseApiNum(slip['medicalEarned']).toDouble();
    final bonus = parseApiNum(slip['bonus']).toDouble();
    final other = parseApiNum(slip['otherEarnings']).toDouble() +
        parseApiNum(slip['specialAdjustment']).toDouble();
    if (special != 0) earn.add(('Special Allowance', special));
    if (medical != 0) earn.add(('Other Allowance', medical));
    if (bonus != 0) earn.add(('Bonus', bonus));
    if (other != 0) earn.add(('Other Earnings', other));

    final ded = <(String, double)>[
      ('Income Tax', parseApiNum(slip['tds']).toDouble()),
      ('Provident Fund', parseApiNum(slip['epfEmployee']).toDouble()),
    ];
    final esic = parseApiNum(slip['esicEmployee']).toDouble();
    final pt = parseApiNum(slip['professionalTax']).toDouble();
    final otherDed = parseApiNum(slip['otherDeductions']).toDouble();
    if (esic != 0) ded.add(('ESIC', esic));
    if (pt != 0) ded.add(('Professional Tax', pt));
    if (otherDed != 0) ded.add(('Other Deductions', otherDed));
    return (earn, ded);
  }

  static String _formatPayDate(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    // Use the calendar date from the ISO prefix so TZ offsets do not shift the day.
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (m != null) return '${m[3]}/${m[2]}/${m[1]}';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('dd/MM/yyyy').format(date.toUtc());
  }

  /// e.g. 2026, 9 → "1 Sep 26 - 30 Sep 26"
  static String _formatPeriodRange(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    final short = DateFormat('MMM').format(DateTime(year, month));
    final yy = (year % 100).toString().padLeft(2, '0');
    return '1 $short $yy - $last $short $yy';
  }

  static String _inrWords(double amount) {
    final n = amount.abs().round();
    if (n == 0) return 'Indian Rupee Zero Only';
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];
    String two(int num) {
      if (num < 20) return ones[num];
      final ten = tens[num ~/ 10];
      final one = ones[num % 10];
      return one.isEmpty ? ten : '$ten-$one';
    }

    final parts = <String>[];
    final crore = n ~/ 10000000;
    final lakh = (n % 10000000) ~/ 100000;
    final thousand = (n % 100000) ~/ 1000;
    final hundred = (n % 1000) ~/ 100;
    final rest = n % 100;
    if (crore > 0) parts.add('${two(crore)} Crore');
    if (lakh > 0) parts.add('${two(lakh)} Lakh');
    if (thousand > 0) parts.add('${two(thousand)} Thousand');
    if (hundred > 0) parts.add('${ones[hundred]} Hundred');
    if (rest > 0) parts.add(two(rest));
    final paise =
        ((amount.abs() - amount.abs().floorToDouble()) * 100).round();
    final tail = paise > 0 ? ' and ${two(paise)} Paise' : '';
    return 'Indian Rupee ${parts.join(' ')}$tail Only';
  }
}
