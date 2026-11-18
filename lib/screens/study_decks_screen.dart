import 'package:flutter/material.dart';

import '../widgets/manage_select_field.dart';

import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../l10n/app_strings.dart';
import 'study_screen.dart';

/// Mỗi bộ đã mở có một State phiên học riêng trong vòng đời tab.
class StudyDecksScreen extends StatefulWidget {
  const StudyDecksScreen({
    super.key,
    this.requestedDeckId,
    this.requestVersion = 0,
  });
  final String? requestedDeckId;
  final int requestVersion;
  @override
  State<StudyDecksScreen> createState() => _StudyDecksScreenState();
}

class _StudyDecksScreenState extends State<StudyDecksScreen> {
  String? _selected;
  bool _initialized = false;
  bool _deleted = false;
  final List<String> _visited = [];

  void _sync(CardController controller) {
    if (controller.isLoading) return;
    final ids = controller.decks.map((deck) => deck.id).toSet();
    _visited.removeWhere((id) => !ids.contains(id));
    if (_selected != null && !ids.contains(_selected)) {
      _selected = null;
      _deleted = true;
    }
    if (!_initialized && ids.isNotEmpty) {
      _selected = ids.contains(widget.requestedDeckId)
          ? widget.requestedDeckId
          : controller.decks.first.id;
      _initialized = true;
    }
    if (_selected != null && !_visited.contains(_selected)) {
      _visited.add(_selected!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context.watch<CardController>());
  }

  @override
  void didUpdateWidget(covariant StudyDecksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestVersion != oldWidget.requestVersion) {
      final controller = context.read<CardController>();
      if (controller.deckById(widget.requestedDeckId ?? '') != null) {
        _selected = widget.requestedDeckId;
        _initialized = true;
        _deleted = false;
      }
      _sync(controller);
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) =>
      Scaffold(body: _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final controller = context.watch<CardController>();
    final strings = AppStrings(controller.isEnglish);
    if (controller.isLoading && controller.decks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.loadError != null && controller.decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(controller.loadError!),
            TextButton(
              onPressed: () => controller.loadDefaultCards(forceReload: true),
              child: Text(strings.retry),
            ),
          ],
        ),
      );
    }
    if (controller.decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.noDecksToStudy, textAlign: TextAlign.center),
        ),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ManageSelectField<String>(
              searchableSheet: true,
              isEnglish: controller.isEnglish,
              subtitle: (id) => controller.isEnglish
                  ? '${controller.cardsInDeck(id).length} cards'
                  : '${controller.cardsInDeck(id).length} câu hỏi',
              key: const ValueKey('study_deck_picker'),
              initialValue: _selected,
              decoration: InputDecoration(
                labelText: strings.currentStudyingDeck,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final deck in controller.decks)
                  DropdownMenuItem(
                    value: deck.id,
                    child: Text(
                      deck.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: controller.isSaving || controller.isLoading
                  ? null
                  : (id) => setState(() {
                      _selected = id;
                      _initialized = true;
                      _deleted = false;
                      _sync(controller);
                    }),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_visited.isNotEmpty)
                  Offstage(
                    offstage: _selected == null,
                    child: IndexedStack(
                      index: _selected == null
                          ? 0
                          : _visited.indexOf(_selected!),
                      children: [
                        for (final id in _visited)
                          StudyScreen(
                            key: ValueKey('study_session_$id'),
                            deckId: id,
                          ),
                      ],
                    ),
                  ),
                if (_selected == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _deleted
                            ? strings.deckDeletedSelectOther
                            : strings.selectDeckToStudy,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
