import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../l10n/app_strings.dart';
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
    final strings = AppStrings(controller.isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.decksTitle),
        actions: [
          IconButton(
            tooltip: strings.createDeck,
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
                    child: Text(strings.retry),
                  ),
                ],
              ),
            )
          : controller.decks.isEmpty
          ? Center(child: Text(strings.noDecksYet))
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
                          '${strings.cardsCount(controller.cardsInDeck(deck.id).length)}${deck.description.isEmpty ? '' : '\n${deck.description}'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: strings.manageDeck,
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
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(strings.renameDeck),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(strings.deleteDeck),
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
                          label: Text(strings.studyThisDeck),
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
          final isEn = context.read<CardController>().isEnglish;
          _error = error is CardOperationException
              ? AppStrings(isEn).errorMessage(error.message)
              : (isEn ? 'Could not create deck.' : 'Không thể tạo bộ thẻ.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    final isEnglish = controller.isEnglish;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialDeck == null
                ? (isEnglish ? 'Create deck' : 'Tạo bộ thẻ')
                : (isEnglish ? 'Rename deck' : 'Đổi tên bộ thẻ'),
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
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Deck name' : 'Tên bộ thẻ',
                    hintText: isEnglish
                        ? 'e.g. Cooking, Science, English'
                        : 'Ví dụ: Nấu ăn, Khoa học, Tiếng Anh',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? (isEnglish ? 'Please enter deck name.' : 'Vui lòng nhập tên bộ thẻ.')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('manage_deck_description'),
                  controller: _description,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Description (optional)' : 'Mô tả (tùy chọn)',
                    border: const OutlineInputBorder(),
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
                        ? (isEnglish ? 'Saving...' : 'Đang lưu...')
                        : widget.initialDeck == null
                        ? (isEnglish ? 'Create deck' : 'Tạo bộ mới')
                        : (isEnglish ? 'Save changes' : 'Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
