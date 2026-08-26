import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = AppTokens.cardRadius,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A203548),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color ?? AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor ?? AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
      ),
    );
    if (onTap == null) return body;
    return Semantics(button: true, child: body);
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.primary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.05,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
    this.selectedColor = AppColors.primary,
  });
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? selectedColor : AppColors.textSecondary;
    if (onTap == null) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final constrained = constraints.hasBoundedWidth;
          final compact = constrained && constraints.maxWidth < 80;
          final labelWidget = Text(
            label,
            maxLines: 1,
            overflow: constrained ? TextOverflow.ellipsis : TextOverflow.clip,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          );
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? selectedColor.withValues(alpha: .1)
                  : AppColors.surface,
              border: Border.all(
                color: selected ? selectedColor : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: constrained ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                if (icon != null && !compact) ...<Widget>[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 5),
                ],
                if (constrained) Expanded(child: labelWidget) else labelWidget,
              ],
            ),
          );
        },
      );
    }
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap!(),
      avatar: icon == null ? null : Icon(icon, size: 14, color: foreground),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      selectedColor: selectedColor.withValues(alpha: .1),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? selectedColor : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
    borderColor: AppColors.borderStrong,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.softBlue,
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...<Widget>[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.initials, {
    super.key,
    this.radius = 20,
    this.color = AppColors.softBlue,
  });
  final String initials;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: color,
    child: Text(
      initials,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: radius * .48,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class ModalTitle extends StatelessWidget {
  const ModalTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onClose,
  });
  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      CircleAvatar(
        backgroundColor: AppColors.softBlue,
        child: Icon(icon, color: AppColors.primary, size: 19),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Close',
        onPressed: onClose ?? () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

Future<T?> showAppSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    );

class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.children,
    this.maxHeightFactor = .88,
  });
  final List<Widget> children;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
    ),
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    ),
  );
}
