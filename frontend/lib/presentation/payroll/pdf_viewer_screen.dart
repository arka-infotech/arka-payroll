import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/widgets/app_shell.dart';

/// Responsive PDF viewer + print layout for salary slips.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  List<int>? _bytes;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes =
          await context.read<PayrollRepository>().fetchPdfBytes(widget.payrollId);
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _print() async {
    if (_bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => _bytes!);
  }

  Future<void> _share() async {
    if (_bytes == null) return;
    await Printing.sharePdf(
      bytes: _bytes!,
      filename: 'salary-slip-${widget.payrollId}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Salary Slip',
      actions: [
        IconButton(
          tooltip: 'Print',
          onPressed: _bytes == null ? null : _print,
          icon: const Icon(Icons.print_outlined),
        ),
        IconButton(
          tooltip: 'Download / Share',
          onPressed: _bytes == null ? null : _share,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : PdfPreview(
                  build: (_) async => _bytes!,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  pdfFileName: 'salary-slip-${widget.payrollId}.pdf',
                ),
    );
  }
}
