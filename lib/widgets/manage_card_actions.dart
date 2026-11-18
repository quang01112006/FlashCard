import 'package:flutter/material.dart';

/// Các thao tác có cùng chiều rộng/chiều cao, nhãn được xuống dòng khi chữ lớn.
class ManageCardActions extends StatelessWidget {
  const ManageCardActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.onMove,
    this.showMove = false,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final bool showMove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final stacked =
          constraints.maxWidth < 270 ||
          MediaQuery.textScalerOf(context).scale(13) > 18;
      Widget action(
        String label,
        IconData icon,
        VoidCallback? callback,
        Color foreground,
      ) => Expanded(
        child: TextButton(
          onPressed: callback,
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
            side: BorderSide(
              color: callback == null
                  ? colors.onSurface.withValues(alpha: .12)
                  : foreground.withValues(alpha: .3),
            ),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontSize: 13),
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(height: 3),
                    Text(label, textAlign: TextAlign.center),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 4),
                    Flexible(child: Text(label, textAlign: TextAlign.center)),
                  ],
                ),
        ),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 16, color: colors.outlineVariant),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action('Sửa thẻ', Icons.edit_outlined, onEdit, colors.primary),
                if (showMove) ...[
                  const SizedBox(width: 4),
                  action(
                    'Chuyển bộ',
                    Icons.drive_file_move_outlined,
                    onMove,
                    colors.onSurfaceVariant,
                  ),
                ],
                const SizedBox(width: 4),
                action(
                  'Xóa thẻ',
                  Icons.delete_outline_rounded,
                  onDelete,
                  colors.error,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
