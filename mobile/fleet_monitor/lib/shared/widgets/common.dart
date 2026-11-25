import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';

/// App bar from the design: 64 px, white, bottom border, optional back chevron.
class FleetAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FleetAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions = const [],
    this.titleStyle,
  });

  final String title;
  final bool showBack;
  final List<Widget> actions;
  final TextStyle? titleStyle;

  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.surface,
    child: SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppPalette.outlineVariant)),
        ),
        padding: EdgeInsets.only(
          left: showBack ? AppSpacing.xxs : AppSpacing.md,
          right: AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: titleStyle ?? AppText.titleLarge),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

/// Round initials avatar ("EK"). 36 px in the app bar, 64 px on the account screen.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppPalette.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      initialsOf(name),
      style: AppText.titleSmall.copyWith(
        color: AppPalette.onPrimary,
        fontSize: size > 40 ? 22 : 14,
        height: 1,
      ),
    ),
  );
}

/// Grey placeholder block for loading skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppPalette.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Centered icon + title + text + optional button: used for empty and error states.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(40, AppSpacing.lg, 40, 80),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, textAlign: TextAlign.center, style: AppText.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.labelLarge.copyWith(
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: AppPalette.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
      ],
    ),
  );
}

/// Secondary button: white, outlined, 48 px (Clear filters, Load more).
class OutlineAppButton extends StatelessWidget {
  const OutlineAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: busy ? null : onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, AppSpacing.tap),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      foregroundColor: AppPalette.primary,
      backgroundColor: AppPalette.surface,
      side: const BorderSide(color: AppPalette.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      textStyle: AppText.labelLarge,
    ),
    child: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label),
  );
}

/// Primary button: ink, 48 px (Retry) or taller for main actions.
class PrimaryAppButton extends StatelessWidget {
  const PrimaryAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppSpacing.tap,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, height),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: AppPalette.primary,
      foregroundColor: AppPalette.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          height > 48 ? AppRadius.card : AppRadius.input,
        ),
      ),
      textStyle: height > 48 ? AppText.titleSmall : AppText.labelLarge,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(label),
      ],
    ),
  );
}
