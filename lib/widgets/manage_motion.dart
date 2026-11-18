import 'package:flutter/material.dart';

/// Hiệu ứng ngắn, dùng chung trong tab Bộ thẻ; tôn trọng giảm chuyển động.
abstract final class ManageMotion {
  static bool reduce(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  static Duration duration(BuildContext context) =>
      reduce(context) ? Duration.zero : const Duration(milliseconds: 180);

  static AnimationStyle style(BuildContext context) => AnimationStyle(
    duration: duration(context),
    reverseDuration: reduce(context)
        ? Duration.zero
        : const Duration(milliseconds: 140),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
}

/// Phản hồi hữu hạn cho thao tác bất đồng bộ, không chạy animation liên tục.
class ManageActionLabel extends StatelessWidget {
  const ManageActionLabel({super.key, required this.busy, required this.label});
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AnimatedSize(
      duration: ManageMotion.duration(context),
      curve: Curves.easeOutCubic,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const Icon(Icons.hourglass_top_rounded, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}
