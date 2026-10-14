import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The standard rounded card used across the app.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color = Palette.surface,
    this.borderColor = Palette.border,
    this.gradient,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final Gradient? gradient;

  /// Optional coloured glow behind the panel (used for highlights).
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.md);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow!.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.lg, 4, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: Palette.textDim,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Shown when a list has nothing in it yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: Space.xl,
      horizontal: Space.lg,
    ),
    child: Column(
      children: [
        icon,
        const SizedBox(height: Space.md),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.xs),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (action case final action?) ...[
          const SizedBox(height: Space.md),
          action,
        ],
      ],
    ),
  );
}
