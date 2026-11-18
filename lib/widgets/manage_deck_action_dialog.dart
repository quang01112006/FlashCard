import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../models/card_deck.dart';
import '../models/flashcard.dart';
import '../services/manage_card_store.dart';

/// Khi có card: chuyển thẻ; khi không có card: xác nhận xóa cả bộ.
class ManageDeckActionDialog extends StatefulWidget {
  const ManageDeckActionDialog({super.key, required this.deck, this.card});
  final CardDeck deck;
  final Flashcard? card;
  @override
  State<ManageDeckActionDialog> createState() => _ManageDeckActionDialogState();
}

class _ManageDeckActionDialogState extends State<ManageDeckActionDialog> {
  String? _target;
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving) return;
    final controller = context.read<CardController>();
    if (controller.isSaving || controller.isLoading) return;
    if (widget.card != null && _target == null) {
      setState(() => _error = 'Vui lòng chọn bộ nhận.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.card == null) {
        await controller.deleteDeck(widget.deck.id);
      } else {
        await controller.moveCard(
          widget.card!.id,
          _target!,
          expectedDeckId: widget.deck.id,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is CardOperationException
              ? error.message
              : 'Không thể lưu thay đổi. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    final isEnglish = controller.isEnglish;
    final destinations = controller.decks
        .where((deck) => deck.id != widget.deck.id)
        .toList();
    final moving = widget.card != null;
    return PopScope<bool>(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          moving
              ? (isEnglish ? 'Move card' : 'Chuyển thẻ')
              : (isEnglish ? 'Delete deck?' : 'Xóa bộ thẻ?'),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                moving
                    ? (isEnglish
                        ? 'Card will be moved from "${widget.deck.name}". Content and review schedule are preserved.'
                        : 'Thẻ sẽ chuyển khỏi “${widget.deck.name}”. Nội dung và lịch ôn được giữ nguyên.')
                    : (isEnglish
                        ? 'Delete "${controller.deckById(widget.deck.id)?.name ?? widget.deck.name}" and all ${controller.cardsInDeck(widget.deck.id).length} cards inside. This action cannot be undone.'
                        : 'Xóa bộ “${controller.deckById(widget.deck.id)?.name ?? widget.deck.name}” cùng toàn bộ ${controller.cardsInDeck(widget.deck.id).length} câu hỏi bên trong. Không thể hoàn tác.'),
              ),
              if (moving) ...[
                const SizedBox(height: 16),
                if (destinations.isEmpty)
                  Text(
                    isEnglish
                        ? 'Please create another deck before moving.'
                        : 'Hãy tạo một bộ thẻ khác trước khi chuyển.',
                  )
                else
                  DropdownButtonFormField<String>(
                    key: const ValueKey('manage_move_destination'),
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: _target,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Destination deck' : 'Bộ nhận',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final deck in destinations)
                        DropdownMenuItem(
                          value: deck.id,
                          child: Text(deck.name),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (id) => setState(() => _target = id),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(isEnglish ? 'Cancel' : 'Hủy'),
          ),
          TextButton(
            key: const ValueKey('manage_deck_action_confirm'),
            onPressed:
                _saving ||
                    controller.isSaving ||
                    (moving && destinations.isEmpty)
                ? null
                : _save,
            child: Text(
              _saving
                  ? (isEnglish ? 'Saving...' : 'Đang lưu...')
                  : moving
                  ? (isEnglish ? 'Move card' : 'Chuyển thẻ')
                  : (isEnglish ? 'Delete deck and cards' : 'Xóa bộ và câu hỏi'),
            ),
          ),
        ],
      ),
    );
  }
}
