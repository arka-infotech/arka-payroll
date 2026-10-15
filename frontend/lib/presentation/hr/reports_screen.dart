import 'package:flutter/material.dart';
import 'package:arka_payroll/presentation/shell/app_scaffold.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reports',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payroll reports',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Export monthly registers, PT challan summaries, and Form-16 style '
                'statements will land here. Use Punch Salary for the current run '
                'and Pay History for employee-facing slips.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
