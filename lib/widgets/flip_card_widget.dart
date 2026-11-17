import 'dart:math';
import 'package:flutter/material.dart';

/// Widget hỗ trợ hiệu ứng xoay lật 3D giữa mặt trước và mặt sau của thẻ
class FlipCardWidget extends StatefulWidget {
  final Widget front;
  final Widget back;
  final ValueChanged<bool>? onFlipChange; // Báo trạng thái: true = mặt sau, false = mặt trước

  const FlipCardWidget({
    super.key,
    required this.front,
    required this.back,
    this.onFlipChange,
  });

  @override
  State<FlipCardWidget> createState() => FlipCardWidgetState();
}

class FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  bool get isFront => _isFront;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lật thẻ qua lại (có thể gọi từ bên ngoài thông qua GlobalKey)
  void flip() {
    if (_controller.isAnimating) return;

    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
    widget.onFlipChange?.call(!_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          // Nếu góc xoay chưa quá 90 độ (0.5 * pi) thì hiện mặt trước, ngược lại hiện mặt sau
          final isUnderHalf = _animation.value <= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Tạo hiệu ứng thị sai (perspective 3D)
              ..rotateY(angle),
            child: isUnderHalf
                ? widget.front
                : Transform(
                    alignment: Alignment.center,
                    // Lật ngược lại 180 độ cho mặt sau để chữ không bị soi gương
                    transform: Matrix4.identity()..rotateY(pi),
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}
