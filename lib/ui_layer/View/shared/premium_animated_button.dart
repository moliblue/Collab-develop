import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PremiumAnimatedButton extends StatefulWidget {
  const PremiumAnimatedButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Gradient? gradient;

  @override
  State<PremiumAnimatedButton> createState() => _PremiumAnimatedButtonState();
}

class _PremiumAnimatedButtonState extends State<PremiumAnimatedButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return AnimatedScale(
      scale: _pressed ? .965 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedOpacity(
        opacity: disabled ? .65 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.isOutlined
                ? null
                : widget.gradient ?? AppColors.blueGradient,
            color: widget.isOutlined ? Colors.white : null,
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            border: widget.isOutlined
                ? Border.all(color: AppColors.border)
                : null,
            boxShadow: widget.isOutlined
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _pressed ? .16 : .28,
                      ),
                      blurRadius: _pressed ? 8 : 14,
                      offset: Offset(0, _pressed ? 3 : 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.controlRadius),
              onTap: disabled ? null : widget.onPressed,
              onTapDown: disabled ? null : (_) => _setPressed(true),
              onTapCancel: disabled ? null : () => _setPressed(false),
              onTapUp: disabled ? null : (_) => _setPressed(false),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: widget.isLoading
                      ? CircularProgressIndicator(
                          key: const ValueKey('loading'),
                          strokeWidth: 2.4,
                          color: widget.isOutlined
                              ? AppColors.primary
                              : Colors.white,
                        )
                      : Padding(
                          key: const ValueKey('content'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.icon,
                                color: widget.isOutlined
                                    ? AppColors.primary
                                    : Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.isOutlined
                                        ? AppColors.primary
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
