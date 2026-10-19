import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:arka_payroll/core/theme/arka_theme.dart';
import 'package:arka_payroll/presentation/widgets/arka_error_view.dart';
import 'package:arka_payroll/providers/app_providers.dart';

// ── Formatting ──────────────────────────────────────────────────────────────

class Fmt {
  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _inr0 =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String inr(num n) => _inr.format(n);
  static String inr0(num n) => _inr0.format(n);
  static String inrCompact(num n) =>
      n.abs() < 100000 ? _inr0.format(n) : _compact.format(n);

  static String titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static String ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 10) return 'just now';
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    return DateFormat('HH:mm').format(t);
  }
}

// ── Tones ───────────────────────────────────────────────────────────────────

enum ArkaTone { neutral, primary, success, warning, danger, info }

class ToneColors {
  const ToneColors(this.fg, this.bg);
  final Color fg;
  final Color bg;

  static ToneColors of(BuildContext context, ArkaTone tone) {
    final cs = context.cs;
    final p = context.palette;
    return switch (tone) {
      ArkaTone.neutral =>
        ToneColors(cs.onSurfaceVariant, cs.surfaceContainerHigh),
      ArkaTone.primary =>
        ToneColors(cs.onPrimaryContainer, cs.primaryContainer),
      ArkaTone.success => ToneColors(p.onSuccessContainer, p.successContainer),
      ArkaTone.warning => ToneColors(p.onWarningContainer, p.warningContainer),
      ArkaTone.danger => ToneColors(cs.onErrorContainer, cs.errorContainer),
      ArkaTone.info => ToneColors(p.onInfoContainer, p.infoContainer),
    };
  }

  /// Saturated accent for icons and dots.
  static Color accent(BuildContext context, ArkaTone tone) {
    final cs = context.cs;
    final p = context.palette;
    return switch (tone) {
      ArkaTone.neutral => cs.onSurfaceVariant,
      ArkaTone.primary => cs.primary,
      ArkaTone.success => p.success,
      ArkaTone.warning => p.warning,
      ArkaTone.danger => cs.error,
      ArkaTone.info => p.info,
    };
  }
}

/// Maps payroll statuses to a tone + label.
(ArkaTone, String) slipStatusTone(String status) => switch (status) {
      'DRAFT' => (ArkaTone.warning, 'Draft'),
      'LOCKED' => (ArkaTone.success, 'Locked'),
      'PAID' => (ArkaTone.success, 'Paid'),
      'PROCESSED' => (ArkaTone.info, 'Processed'),
      _ => (ArkaTone.neutral, Fmt.titleCase(status)),
    };

/// Maps payslip email outcome after lock.
/// When [expectEmail] is true (locked slip) and status is null, shows "Email not sent".
(ArkaTone, String)? slipEmailTone(String? status, {bool expectEmail = false}) =>
    switch (status) {
      'SENT' => (ArkaTone.success, 'Email sent'),
      'PENDING' => (ArkaTone.info, 'Email sending…'),
      'FAILED' => (ArkaTone.danger, 'Email failed'),
      'SKIPPED' => (ArkaTone.neutral, 'Email skipped'),
      _ => expectEmail ? (ArkaTone.warning, 'Email not sent') : null,
    };

// ── Small building blocks ───────────────────────────────────────────────────

class ArkaStatusChip extends StatelessWidget {
  const ArkaStatusChip(this.label,
      {super.key, this.tone = ArkaTone.neutral, this.icon, this.dot = false});

  final String label;
  final ArkaTone tone;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = ToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ToneColors.accent(context, tone),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.tt.labelMedium?.copyWith(
              color: c.fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ArkaAvatar extends StatelessWidget {
  const ArkaAvatar(this.name, {super.key, this.size = 40, this.online});

  final String name;
  final double size;

  /// Shows a presence dot when not null.
  final bool? online;

  static const _hues = [
    Color(0xFF14808F),
    Color(0xFF4F46E5),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF15803D),
    Color(0xFF0369A1),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    final base = _hues[name.hashCode.abs() % _hues.length];
    final dark = context.isDark;
    final fg = dark ? Color.lerp(base, Colors.white, 0.45)! : base;
    final bg = base.withValues(alpha: dark ? 0.22 : 0.12);
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.34)),
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: -0.2,
        ),
      ),
    );
    if (online == null) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: online! ? context.palette.success : context.cs.outline,
              shape: BoxShape.circle,
              border: Border.all(color: context.cs.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class ArkaIconBadge extends StatelessWidget {
  const ArkaIconBadge(this.icon,
      {super.key, this.tone = ArkaTone.info, this.size = 40});

  final IconData icon;
  final ArkaTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ToneColors.of(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child:
          Icon(icon, color: ToneColors.accent(context, tone), size: size * 0.5),
    );
  }
}

/// Section label with optional trailing action.
class ArkaSectionTitle extends StatelessWidget {
  const ArkaSectionTitle(this.text, {super.key, this.subtitle, this.action});

  final String text;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: context.tt.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.tt.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Card with consistent padding and an optional tap.
class ArkaCard extends StatelessWidget {
  const ArkaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class ArkaStatTile extends StatelessWidget {
  const ArkaStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = ArkaTone.info,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final ArkaTone tone;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ArkaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ArkaIconBadge(icon, tone: tone, size: 36),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_outward_rounded,
                    size: 18, color: context.cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.headlineSmall?.copyWith(height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelMedium),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Grid that adapts its column count to the available width.
class ArkaAdaptiveGrid extends StatelessWidget {
  const ArkaAdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.maxColumns = 4,
    this.gap = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + gap) / (minItemWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: w, child: child)
          ],
        );
      },
    );
  }
}

class ArkaQuickAction extends StatelessWidget {
  const ArkaQuickAction({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.tone = ArkaTone.info,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final ArkaTone tone;

  @override
  Widget build(BuildContext context) {
    return ArkaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ArkaIconBadge(icon, tone: tone, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.tt.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: context.tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class ArkaEmptyState extends StatelessWidget {
  const ArkaEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 34, color: context.cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center, style: context.tt.titleMedium),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant, height: 1.45),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ).animate().fadeIn(duration: 260.ms),
    );
  }
}

// ── Loading skeletons ───────────────────────────────────────────────────────

class ArkaSkeleton extends StatelessWidget {
  const ArkaSkeleton(
      {super.key, this.height = 16, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
        duration: 1300.ms, color: context.cs.surface.withValues(alpha: 0.6));
  }
}

/// Placeholder list of card-shaped rows.
class ArkaSkeletonList extends StatelessWidget {
  const ArkaSkeletonList(
      {super.key, this.count = 5, this.itemHeight = 76, this.header = true});

  final int count;
  final double itemHeight;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (header) ...[
          const ArkaSkeleton(height: 52, radius: 14),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < count; i++) ...[
          ArkaSkeleton(height: itemHeight, radius: 18),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ── Async state ─────────────────────────────────────────────────────────────

/// Renders an [AsyncValue] with skeleton loading, friendly errors and a
/// "showing last data" pill when a background refresh fails.
class ArkaAsync<T> extends StatelessWidget {
  const ArkaAsync({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final child = data(value.requireValue);
      if (!value.hasError) return child;
      return Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
                child: ArkaStalePill(error: value.error!, onRetry: onRetry)),
          ),
        ],
      );
    }
    if (value.hasError) {
      return ArkaErrorView(error: value.error!, onRetry: onRetry);
    }
    return loading ?? const ArkaSkeletonList();
  }
}

class ArkaStalePill extends StatelessWidget {
  const ArkaStalePill({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = ToneColors.of(context, ArkaTone.warning);
    return Material(
      color: c.bg,
      elevation: 2,
      shadowColor: context.cs.shadow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: c.fg),
              const SizedBox(width: 8),
              Text(
                'Couldn’t refresh · showing last data',
                style: context.tt.labelMedium?.copyWith(color: c.fg),
              ),
              const SizedBox(width: 8),
              Text(
                'Retry',
                style: context.tt.labelMedium?.copyWith(
                    color: c.fg,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.3, end: 0);
  }
}

/// Pulsing dot + "updated x ago" so people know data refreshes itself.
class ArkaLiveIndicator extends StatefulWidget {
  const ArkaLiveIndicator(
      {super.key, required this.updatedAt, this.onDark = false});

  final DateTime updatedAt;
  final bool onDark;

  @override
  State<ArkaLiveIndicator> createState() => _ArkaLiveIndicatorState();
}

class _ArkaLiveIndicatorState extends State<ArkaLiveIndicator> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.onDark
        ? Colors.white.withValues(alpha: 0.8)
        : context.cs.onSurfaceVariant;
    final dot =
        widget.onDark ? const Color(0xFF6EE7B7) : context.palette.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 1, end: 0.35, duration: 900.ms),
        const SizedBox(width: 6),
        Text(
          'Live · updated ${Fmt.ago(widget.updatedAt)}',
          style: context.tt.labelMedium?.copyWith(color: fg),
        ),
      ],
    );
  }
}

// ── Inputs & forms ──────────────────────────────────────────────────────────

class ArkaSearchField extends StatelessWidget {
  const ArkaSearchField(
      {super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: context.cs.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Titled card grouping related form fields.
class ArkaFormSection extends StatelessWidget {
  const ArkaFormSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ArkaCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                ArkaIconBadge(icon!, tone: ArkaTone.info, size: 36),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.tt.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.03, end: 0);
  }
}

/// Lays fields side by side on wide layouts and stacks them on phones.
class ArkaFieldRow extends StatelessWidget {
  const ArkaFieldRow(
      {super.key,
      required this.children,
      this.breakpoint = 560,
      this.gap = 12});

  final List<Widget> children;
  final double breakpoint;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: children[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      },
    );
  }
}

/// Read-only field that opens a date picker; participates in [Form] validation.
class ArkaDateField extends StatelessWidget {
  const ArkaDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: value,
      validator: (_) => required && value == null ? 'Pick a date' : null,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPick,
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            suffixIcon: const Icon(Icons.calendar_month_rounded),
          ),
          child: Text(
            value == null ? '' : DateFormat('dd MMM yyyy').format(value!),
            style: context.tt.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Sticky footer for primary form actions.
class ArkaBottomBar extends StatelessWidget {
  const ArkaBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Phones get full-width thumb-friendly buttons; desktop keeps them
    // compact and right-aligned with the page content.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final h = wide ? 28.0 : 16.0;
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: wide ? 1240 : double.infinity),
            child: Padding(
              padding: EdgeInsets.fromLTRB(h, 12, h, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    if (wide)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 180),
                        child: children[i],
                      )
                    else
                      Expanded(child: children[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Button content that swaps to a spinner while [busy].
class ArkaBusyLabel extends StatelessWidget {
  const ArkaBusyLabel(
      {super.key,
      required this.busy,
      required this.label,
      this.icon,
      this.color});

  final bool busy;
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2.2, color: color ?? context.cs.onPrimary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ── Period picker ───────────────────────────────────────────────────────────

class ArkaMonthSwitcher extends StatelessWidget {
  const ArkaMonthSwitcher(
      {super.key, required this.period, required this.onChanged});

  final PayPeriod period;
  final ValueChanged<PayPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => onChanged(period.previous),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showArkaMonthPicker(context, period);
                if (picked != null) onChanged(picked);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(period.label,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall),
                  ),
                  if (period.isCurrent) ...[
                    const SizedBox(width: 8),
                    const ArkaStatusChip('Now', tone: ArkaTone.info),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => onChanged(period.next),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

Future<PayPeriod?> showArkaMonthPicker(
    BuildContext context, PayPeriod initial) {
  return showDialog<PayPeriod>(
    context: context,
    builder: (ctx) {
      var year = initial.year;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          title: Row(
            children: [
              IconButton(
                  onPressed: () => setState(() => year--),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text('$year', textAlign: TextAlign.center)),
              IconButton(
                  onPressed: () => setState(() => year++),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(builder: (ctx) {
                    final selected = initial.year == year && initial.month == m;
                    return selected
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero),
                            onPressed: () =>
                                Navigator.pop(ctx, PayPeriod(year, m)),
                            child: Text(
                                DateFormat.MMM().format(DateTime(2020, m))),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero),
                            onPressed: () =>
                                Navigator.pop(ctx, PayPeriod(year, m)),
                            child: Text(
                                DateFormat.MMM().format(DateTime(2020, m))),
                          );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, PayPeriod.now()),
              child: const Text('This month'),
            ),
          ],
        ),
      );
    },
  );
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

Future<bool> confirmArka(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final cs = context.cs;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: destructive ? cs.error : cs.primary),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: cs.error, foregroundColor: cs.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Shared sign-out action with confirmation.
class ArkaLogoutButton extends ConsumerWidget {
  const ArkaLogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      onPressed: () async {
        final ok = await confirmArka(
          context,
          title: 'Sign out?',
          message: 'You’ll need your email and password to sign back in.',
          confirmLabel: 'Sign out',
          icon: Icons.logout_rounded,
        );
        if (ok) await ref.read(authStateProvider).logout();
      },
      icon: const Icon(Icons.logout_rounded),
    );
  }
}

class ArkaThemeToggle extends ConsumerWidget {
  const ArkaThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      onPressed: ref.read(themeControllerProvider).toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => RotationTransition(turns: a, child: c),
        child: Icon(
          dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(dark),
        ),
      ),
    );
  }
}
