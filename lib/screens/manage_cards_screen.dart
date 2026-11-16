import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../models/flashcard.dart';

class ManageCardsScreen extends StatelessWidget {
  const ManageCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Bộ thẻ')),
      body: SafeArea(child: _buildBody(controller)),
    );
  }

  Widget _buildBody(CardController controller) {
    if (controller.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: 'Đang tải bộ thẻ'),
            SizedBox(height: 16),
            Text('Đang tải bộ thẻ...', style: AppTextStyles.body),
          ],
        ),
      );
    }

    if (controller.loadError != null) {
      return _ManageCardsMessage(
        icon: Icons.error_outline,
        title: 'Chưa tải được bộ thẻ',
        message: controller.loadError!,
        actionLabel: 'Thử lại',
        onAction: controller.loadDefaultCards,
      );
    }

    final cards = controller.cards;
    if (cards.isEmpty) {
      return _ManageCardsMessage(
        icon: Icons.style_outlined,
        title: 'Chưa có thẻ nào',
        message: 'Bạn có thể tải lại để kiểm tra dữ liệu bộ thẻ.',
        actionLabel: 'Tải lại',
        onAction: controller.loadDefaultCards,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${cards.length} thẻ', style: AppTextStyles.subHeading),
              const SizedBox(height: 4),
              const Text(
                'Chạm vào thẻ để xem đáp án và giải thích.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('manage_cards_list'),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: cards.length,
            itemBuilder: (context, index) =>
                _ManageCardItem(card: cards[index]),
          ),
        ),
      ],
    );
  }
}

class _ManageCardItem extends StatelessWidget {
  const _ManageCardItem({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('manage_card_${card.id}'),
        tilePadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(card.front, style: AppTextStyles.body),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [
              card.id,
              card.topicCode,
              card.level,
            ].where((value) => value.isNotEmpty).join(' • '),
            style: AppTextStyles.caption,
          ),
        ),
        children: [
          const Divider(color: AppColors.border),
          const Text('Đáp án & giải thích', style: AppTextStyles.subHeading),
          const SizedBox(height: 8),
          SelectableText(
            card.back,
            key: PageStorageKey('manage_answer_${card.id}'),
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _ManageCardsMessage extends StatelessWidget {
  const _ManageCardsMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.subHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
