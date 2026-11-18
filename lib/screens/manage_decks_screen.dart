import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../models/card_deck.dart';
import '../services/manage_card_store.dart';
import '../widgets/manage_deck_action_dialog.dart';
import 'manage_cards_screen.dart';
import 'study_screen.dart';

class ManageDecksScreen extends StatelessWidget {
  const ManageDecksScreen({super.key, this.onStudyDeck});
  final ValueChanged<String>? onStudyDeck;
  void _study(BuildContext context, String id) {
    if (onStudyDeck != null) {
      onStudyDeck!(id);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudyScreen(deckId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Các bộ thẻ'),
        actions: [
          IconButton(
            tooltip: 'Tạo bộ thẻ',
            key: const ValueKey('manage_create_deck'),
            onPressed:
                controller.isLoading ||
                    controller.isSaving ||
                    controller.loadError != null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageCreateDeckScreen(),
                    ),
                  ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.loadError!),
                  TextButton(
                    onPressed: () =>
                        controller.loadDefaultCards(forceReload: true),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : controller.decks.isEmpty
          ? const Center(child: Text('Chưa có bộ thẻ. Nhấn + để tạo bộ mới.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: controller.decks.length,
              itemBuilder: (context, index) {
                final deck = controller.decks[index];
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        key: ValueKey('manage_deck_${deck.id}'),
                        leading: const Icon(
                          Icons.collections_bookmark_outlined,
                        ),
                        title: Text(deck.name),
                        subtitle: Text(
                          '${controller.cardsInDeck(deck.id).length} câu hỏi${deck.description.isEmpty ? '' : '\n${deck.description}'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Quản lý bộ thẻ',
                          enabled:
                              !controller.isSaving && !controller.isLoading,
                          onSelected: (action) async {
                            if (action == 'rename') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ManageCreateDeckScreen(initialDeck: deck),
                                ),
                              );
                            } else {
                              await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) =>
                                    ManageDeckActionDialog(deck: deck),
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Đổi tên / mô tả'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa bộ thẻ'),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ManageDeckContentsScreen(
                              deck: deck,
                              onStudyDeck: onStudyDeck,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: OutlinedButton.icon(
                          key: ValueKey('manage_study_deck_${deck.id}'),
                          onPressed: controller.isSaving || controller.isLoading
                              ? null
                              : () => _study(context, deck.id),
                          icon: const Icon(Icons.school_outlined),
                          label: const Text('Học bộ này'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class ManageCreateDeckScreen extends StatefulWidget {
  const ManageCreateDeckScreen({super.key, this.initialDeck});
  final CardDeck? initialDeck;
  @override
  State<ManageCreateDeckScreen> createState() => _ManageCreateDeckScreenState();
}

class _ManageCreateDeckScreenState extends State<ManageCreateDeckScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  @override
  void initState() {
    super.initState();
    _name.text = widget.initialDeck?.name ?? '';
    _description.text = widget.initialDeck?.description ?? '';
  }

  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = context.read<CardController>();
      if (widget.initialDeck == null) {
        await controller.createDeck(_name.text, description: _description.text);
      } else {
        await controller.renameDeck(
          widget.initialDeck!.id,
          _name.text,
          description: _description.text,
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is CardOperationException
              ? error.message
              : 'Không thể tạo bộ thẻ.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialDeck == null ? 'Tạo bộ thẻ' : 'Đổi tên bộ thẻ',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const ValueKey('manage_deck_name'),
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Tên bộ thẻ',
                  hintText: 'Ví dụ: Nấu ăn, Khoa học, Tiếng Anh',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tên bộ thẻ.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('manage_deck_description'),
                controller: _description,
                enabled: !_saving,
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? 'Đang lưu...'
                      : widget.initialDeck == null
                      ? 'Tạo bộ mới'
                      : 'Lưu thay đổi',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ManageDeckContentsScreen extends StatelessWidget {
  const ManageDeckContentsScreen({
    super.key,
    required this.deck,
    this.onStudyDeck,
  });
  final ValueChanged<String>? onStudyDeck;
  final CardDeck deck;
  @override
  Widget build(BuildContext context) {
    return ManageCardsScreen(deckId: deck.id, onStudyDeck: onStudyDeck);
  }
}
