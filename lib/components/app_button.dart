import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = onPressed != null && !isLoading;
    final foreground = variant == AppButtonVariant.primary
        ? tokens.onPrimary
        : variant == AppButtonVariant.danger
            ? tokens.error
            : tokens.primary;
    final background = variant == AppButtonVariant.primary
        ? tokens.primary
        : tokens.surface;

    final style = ButtonStyle(
      minimumSize: MaterialStateProperty.all<Size>(
        const Size(AppTokens.touchTarget, AppTokens.touchTarget),
      ),
      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
        const EdgeInsets.symmetric(horizontal: AppTokens.space6),
      ),
      foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
        return states.contains(MaterialState.disabled) ? tokens.textMuted : foreground;
      }),
      backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
        return states.contains(MaterialState.disabled) ? tokens.background : background;
      }),
      side: MaterialStateProperty.resolveWith<BorderSide?>((states) {
        return BorderSide(
          color: states.contains(MaterialState.disabled)
              ? tokens.outline
              : variant == AppButtonVariant.danger
                  ? tokens.error
                  : tokens.primary,
        );
      }),
      shape: MaterialStateProperty.all<OutlinedBorder>(
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusSm)),
        ),
      ),
    );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, en progreso' : label,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: isLoading
              ? SizedBox(
                  key: const ValueKey<String>('loading'),
                  width: AppTokens.space6,
                  height: AppTokens.space6,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                    semanticsLabel: 'Cargando',
                  ),
                )
              : Row(
                  key: const ValueKey<String>('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: AppTokens.space6),
                      const SizedBox(width: AppTokens.space2),
                    ],
                    Flexible(child: Text(label, textAlign: TextAlign.center)),
                  ],
                ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
