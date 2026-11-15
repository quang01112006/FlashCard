import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/card_controller.dart';
import '../core/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu dùng chung từ CardController (Global Store)
    final cardController = context.watch<CardController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.psychology_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Thẻ cần ôn hôm nay',
                style: AppTextStyles.caption.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (cardController.isLoading)
                const CircularProgressIndicator()
              else
                Text(
                  '${cardController.dueCount} thẻ',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 40,
                    color: AppColors.primary,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Tổng số thẻ trong hệ thống: ${cardController.cards.length}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chuyển sang Tab "Học thẻ" để bắt đầu!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu ôn tập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
