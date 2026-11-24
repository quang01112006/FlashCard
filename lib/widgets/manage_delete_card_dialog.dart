import 'package:flutter/material.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../models/flashcard.dart';
import '../services/manage_card_store.dart';
import 'code_text_view.dart';

class ManageDeleteCardDialog extends StatefulWidget {
  const ManageDeleteCardDialog({
    super.key,
    required this.card,
    required this.controller,
  });
  final Flashcard card;
  final CardController controller;

  @override
  State<ManageDeleteCardDialog> createState() => _ManageDeleteCardDialogState();
}

class _ManageDeleteCardDialogState extends State<ManageDeleteCardDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.controller.deleteCard(
        widget.card.id,
        expectedDeckId: widget.card.deckId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final strings = AppStrings(widget.controller.isEnglish);
        _error = error is CardOperationException
            ? strings.errorMessage(error.message)
            : (widget.controller.isEnglish
                ? 'Could not delete card. Please try again.'
                : 'Không thể xóa thẻ. Vui lòng thử lại.');
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = widget.controller.isEnglish;
    final translated = widget.card.frontEn;
    final question =
        isEnglish &&
            translated != null &&
            translated.trim().isNotEmpty
        ? translated
        : widget.card.front;
    return PopScope<bool>(
      canPop: !_deleting,
      child: AlertDialog(
        scrollable: true,
        title: Text(isEnglish ? 'Delete card?' : 'Xóa thẻ?'),
        content: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CodeTextView(
                text: question,
                baseStyle: AppTextStyles.body,
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 12),
              Text(isEnglish
                  ? 'This card will be removed from the deck and study queue.'
                  : 'Thẻ sẽ bị xóa khỏi bộ thẻ và danh sách ôn tập.'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: AppTextStyles.body.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(isEnglish ? 'Cancel' : 'Hủy'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size(48, 48),
            ),
            onPressed: _deleting ? null : _delete,
            child: Text(_deleting
                ? (isEnglish ? 'Deleting...' : 'Đang xóa...')
                : (isEnglish ? 'Delete card' : 'Xóa thẻ')),
          ),
        ],
      ),
    );
  }
}
