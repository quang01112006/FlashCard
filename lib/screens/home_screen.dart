import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/card_controller.dart';
import '../core/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTopic = 'ALL';

  // Tạo danh sách K01 -> K20
  final List<String> _topics = [
    'ALL',
    ...List.generate(20, (i) => 'K${(i + 1).toString().padLeft(2, '0')}'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    final filteredCards = controller.getCardsByTopic(_selectedTopic);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'), // Tự ăn style AppBarTheme từ app_theme.dart
      ),
      body: controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thống kê nhanh (Card tự ăn CardTheme từ app_theme.dart)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(
                            'Cần ôn hôm nay',
                            '${controller.dueCount}',
                            AppColors.warning,
                          ),
                          _statItem(
                            'Tổng số thẻ',
                            '${controller.cards.length}',
                            AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Thanh lọc K01 - K20
                  const Text(
                    'Khối kiến thức (K01–K20)',
                    style: AppTextStyles.subHeading,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _topics.length,
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        final isSelected = _selectedTopic == topic;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              topic == 'ALL' ? 'Tất cả' : topic,
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? AppColors.surface
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.primaryLight,
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (_) =>
                                setState(() => _selectedTopic = topic),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Danh sách thẻ đã lọc
                  Expanded(
                    child: filteredCards.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có dữ liệu thẻ',
                              style: AppTextStyles.body,
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCards.length,
                            itemBuilder: (context, index) {
                              final card = filteredCards[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text(
                                      card.topicCode,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    card.front,
                                    style: AppTextStyles.body,
                                  ),
                                  subtitle: Text(
                                    card.back,
                                    style: AppTextStyles.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.heading.copyWith(color: valueColor),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}