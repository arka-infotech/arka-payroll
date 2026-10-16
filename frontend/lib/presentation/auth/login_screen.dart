import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arka_payroll/core/config/app_config.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/widgets/aips_logo.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/presentation/widgets/arka_ui.dart';
import 'package:arka_payroll/providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider).login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final p = context.palette;

    final form = Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) ...[
              const Center(child: AipsLogo(height: 84)),
              const SizedBox(height: 20),
            ],
            Text('Welcome back', style: context.tt.headlineSmall),
            const SizedBox(height: 4),
            Text('Sign in to ${AppConfig.appTagline.toLowerCase()}',
                style: context.tt.bodyMedium
                    ?.copyWith(color: context.cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (auth.error != null) ...[
              ArkaInlineAlert(title: 'Couldn’t sign in', message: auth.error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Work email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 8 ? 'Minimum 8 characters' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: ArkaBusyLabel(
                  busy: auth.busy,
                  label: 'Sign in',
                  icon: Icons.arrow_forward_rounded),
            ),
            const SizedBox(height: 20),
            Text(
              AppConfig.companyName,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall,
            ),
          ],
        ),
      ),
    );

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        elevation: wide ? 0 : 12,
        shadowColor: Colors.black26,
        child: Padding(padding: const EdgeInsets.all(28), child: form),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);

    return Scaffold(
      body: Stack(
        children: [
          if (wide)
            Row(
              children: [
                Expanded(
                    child: _BrandPanel(start: p.heroStart, end: p.heroEnd)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32), child: card),
                  ),
                ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.heroStart, p.heroEnd],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20), child: card),
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Theme(
                data: Theme.of(context).copyWith(
                  iconButtonTheme: IconButtonThemeData(
                    style: IconButton.styleFrom(
                        foregroundColor:
                            wide ? context.cs.onSurfaceVariant : Colors.white),
                  ),
                ),
                child: const ArkaThemeToggle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.start, required this.end});

  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end]),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AipsLogo(height: 64, onDarkBackground: true),
          const Spacer(),
          Text(
            'Payroll that runs\nitself.',
            style: context.tt.headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 40, height: 1.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Punch salaries, lock months and share payslips — with live numbers for the whole team.',
            style: context.tt.bodyLarge
                ?.copyWith(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 32),
          for (final (icon, text) in [
            (Icons.bolt_rounded, 'Auto-refreshing dashboard'),
            (Icons.lock_rounded, 'Locked months for clean records'),
            (Icons.picture_as_pdf_rounded, 'One-tap PDF payslips'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(text,
                      style:
                          context.tt.bodyMedium?.copyWith(color: Colors.white)),
                ],
              ),
            ),
          const Spacer(),
          Text('© ${DateTime.now().year} ${AppConfig.companyName}',
              style: context.tt.bodySmall?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }
}
