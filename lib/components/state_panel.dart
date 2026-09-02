import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_button.dart';

enum StatePanelType { loading, empty, error }

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final StatePanelType type;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isError = type == StatePanelType.error;
    final icon = type == StatePanelType.empty
        ? Icons.note_add_outlined
        : type == StatePanelType.error
            ? Icons.cloud_off_outlined
            : null;

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.space8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: isError ? tokens.error : tokens.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (type == StatePanelType.loading)
              CircularProgressIndicator(
                color: tokens.primary,
                semanticsLabel: 'Cargando notas',
              )
            else
              Icon(icon, size: AppTokens.space12, color: isError ? tokens.error : tokens.primary),
            const SizedBox(height: AppTokens.space4),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.space2),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppTokens.space6),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: isError ? AppButtonVariant.danger : AppButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
