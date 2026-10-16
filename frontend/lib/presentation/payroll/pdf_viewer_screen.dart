import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({super.key, required this.payrollId});

  final String payrollId;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _filename;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final bundle = await ref
          .read(payrollRepositoryProvider)
          .fetchPdfBundle(widget.payrollId);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bundle.bytes);
        _filename = bundle.filename;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _share() async {
    try {
      await Printing.sharePdf(bytes: _bytes!, filename: _filename!);
    } catch (e) {
      if (mounted) ArkaSnack.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;
    return AppScaffold(
      title: _filename?.replaceAll('.pdf', '') ?? 'Salary slip',
      subtitle: 'Preview, print or download',
      showNav: false,
      actions: [
        IconButton(
          tooltip: 'Print',
          onPressed: ready
              ? () => Printing.layoutPdf(onLayout: (_) async => _bytes!)
              : null,
          icon: const Icon(Icons.print_outlined),
        ),
        IconButton(
          tooltip: 'Download PDF',
          onPressed: ready ? _share : null,
          icon: const Icon(Icons.download_rounded),
        ),
      ],
      child: _error != null
          ? ArkaErrorView(error: _error!, onRetry: _load)
          : !ready
              ? const ArkaSkeleton(height: double.infinity, radius: 18)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
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
