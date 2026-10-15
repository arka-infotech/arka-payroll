import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/data/payroll/payroll_repository.dart';
import 'package:arka_payroll/presentation/widgets/app_shell.dart';

class EmployeeSlipsScreen extends StatefulWidget {
  const EmployeeSlipsScreen({super.key});

  @override
  State<EmployeeSlipsScreen> createState() => _EmployeeSlipsScreenState();
}

class _EmployeeSlipsScreenState extends State<EmployeeSlipsScreen> {
  List<SlipSummary> _slips = [];
  bool _loading = true;
  String? _error;
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
      final slips = await context.read<PayrollRepository>().fetchMySlips();
      setState(() {
        _slips = slips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _period(SlipSummary s) {
    final name = DateFormat.MMMM().format(DateTime(s.year, s.month));
    return '$name ${s.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'My Salary Slips',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _slips.isEmpty
                    ? const Center(
                        child: Text(
                          'No salary slips yet.',
                          style: TextStyle(color: ArkaColors.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _slips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final s = _slips[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: ArkaColors.navy,
                                child: Icon(
                                  Icons.description_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(_period(s)),
                              subtitle: Text(
                                s.trackingReference,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _inr.format(s.netPay),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: ArkaColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => context.push('/slip/${s.id}'),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
