import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/network/api_errors.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _filename;
  String? _title;
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
      final bundle = await context
          .read<PayrollRepository>()
          .fetchPdfBundle(widget.payrollId);
      setState(() {
        _bytes = Uint8List.fromList(bundle.bytes);
        _filename = bundle.filename;
        _title = bundle.filename.replaceAll('.pdf', '');
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _share() async {
    if (_bytes == null || _filename == null) return;
    await Printing.sharePdf(bytes: _bytes!, filename: _filename!);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title ?? 'Salary slip',
      actions: [
        IconButton(
          tooltip: 'Print',
          onPressed: _bytes == null
              ? null
              : () => Printing.layoutPdf(onLayout: (_) async => _bytes!),
          icon: const Icon(Icons.print_outlined),
        ),
        IconButton(
          tooltip: 'Download PDF',
          onPressed: _bytes == null ? null : _share,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PdfPreview(
                    build: (_) async => _bytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: true,
                    allowSharing: true,
                    pdfFileName: _filename ?? 'salary-slip.pdf',
                  ),
                ),
    );
  }
}
