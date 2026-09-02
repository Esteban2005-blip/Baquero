import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import '../note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onEdit,
    this.onDelete,
  });

  final Note note;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _dateLabel() {
    final date = note.createdDate.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Nota ${note.title}, creada el ${_dateLabel()}',
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space6),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: tokens.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    note.title,
                    style: textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Editar ${note.title}',
                    constraints: const BoxConstraints(
                      minWidth: AppTokens.touchTarget,
                      minHeight: AppTokens.touchTarget,
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Eliminar ${note.title}',
                    color: tokens.error,
                    constraints: const BoxConstraints(
                      minWidth: AppTokens.touchTarget,
                      minHeight: AppTokens.touchTarget,
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space3),
            Text(
              note.content,
              style: textTheme.bodyLarge?.copyWith(color: tokens.textMuted),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const SizedBox(height: AppTokens.space4),
            Row(
              children: <Widget>[
                Icon(Icons.calendar_today_outlined, size: AppTokens.space4, color: tokens.textMuted),
                const SizedBox(width: AppTokens.space2),
                Text(_dateLabel(), style: textTheme.labelMedium?.copyWith(color: tokens.textMuted)),
                if (note.authorEmail != null) ...<Widget>[
                  const SizedBox(width: AppTokens.space4),
                  Expanded(
                    child: Text(
                      note.authorEmail!,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(color: tokens.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
