import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/flashcard.dart';
import '../services/csv_service.dart';
import '../services/ai_card_service.dart';
import '../services/manage_ai_strings.dart';
import '../services/manage_csv_files.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_search.dart';
import '../widgets/code_text_view.dart';
import '../widgets/manage_card_filters_sheet.dart';
import '../widgets/manage_delete_card_dialog.dart';
import 'manage_card_editor_screen.dart';
import 'manage_ai_screen.dart';
import 'manage_csv_mapping_screen.dart';
import '../widgets/manage_deck_action_dialog.dart';
import 'study_screen.dart';

enum _CsvAction { import, export, demoAi }

class ManageCardsScreen extends StatefulWidget {
  const ManageCardsScreen({
    super.key,
    this.csvFiles,
    this.deckId,
    this.onStudyDeck,
    this.aiService = const WorkerAiCardService(),
  });
  final ValueChanged<String>? onStudyDeck;
  final String? deckId;

  final ManageCsvFiles? csvFiles;
  final AiCardService aiService;

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();
  String _query = '';
  ManageCardFilter _filter = const ManageCardFilter();
  String? _recentCardId;
  bool _csvBusy = false;
  bool _csvProcessing = false;
  late final ManageCsvFiles _csvFiles =
      widget.csvFiles ?? NativeManageCsvFiles();

  List<Flashcard> _cards(CardController controller) => widget.deckId == null
      ? controller.cards
      : controller.cardsInDeck(widget.deckId!);

  Future<void> _moveCard(Flashcard card) async {
    final deck = context.read<CardController>().deckById(card.deckId);
    if (deck == null) return;
    final moved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManageDeckActionDialog(deck: deck, card: card),
    );
    if (mounted && moved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chuyển thẻ sang bộ khác.')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _recentCardId = null;
    });
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<ManageCardFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManageCardFiltersSheet(
        initialFilter: _filter,
        topics: widget.deckId == null
            ? context.read<CardController>().allTopics
            : context.read<CardController>().topicsInDeck(widget.deckId!),
        includeFlutterTopics:
            widget.deckId == null || widget.deckId == 'flutter-default',
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _filter = selected;
      _recentCardId = null;
    });
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  void _resetSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = const ManageCardFilter();
    });
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  Future<void> _openEditor([Flashcard? card]) async {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ManageCardEditorScreen(
          initialCard: card,
          deckId: widget.deckId,
          topicCode: _filter.topicCode,
          level: _filter.level,
        ),
      ),
    );
    if (!mounted || id == null) return;
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = const ManageCardFilter();
      _recentCardId = id;
    });
    if (_listController.hasClients) _listController.jumpTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(card == null ? 'Đã thêm thẻ mới.' : 'Đã lưu thay đổi.'),
      ),
    );
  }

  Future<void> _deleteCard(Flashcard card) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManageDeleteCardDialog(
        card: card,
        controller: context.read<CardController>(),
      ),
    );
    if (!mounted || deleted != true) return;
    if (_recentCardId == card.id) setState(() => _recentCardId = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã xóa thẻ.')));
  }

  Future<void> _handleCsv(_CsvAction action) async {
    final controller = context.read<CardController>();
    if (_csvBusy || controller.isSaving) return;
    if (action == _CsvAction.demoAi) {
      final deckId = widget.deckId;
      if (deckId == null || controller.deckById(deckId) == null) return;
      final count = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ManageAiScreen(deckId: deckId, service: widget.aiService),
        ),
      );
      if (!mounted || count == null) return;
      _recentCardId = null;
      _resetSearchAndFilters();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ManageAiStrings(controller.isEnglish).saved(count)),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _csvBusy = true;
      _csvProcessing = action == _CsvAction.import;
    });
    try {
      if (action == _CsvAction.import) {
        final file = await _csvFiles.pick();
        if (!mounted || file == null) return;
        final table = await compute(CsvService.inspectBytes, file.bytes);
        if (!mounted) return;
        setState(() => _csvProcessing = false);
        final count = await Navigator.of(context).push<int>(
          MaterialPageRoute(
            builder: (_) => ManageCsvMappingScreen(
              fileName: file.name,
              table: table,
              topicCode: _filter.topicCode,
              level: _filter.level,
              deckId: widget.deckId,
            ),
          ),
        );
        if (!mounted || count == null) return;
        _recentCardId = null;
        _resetSearchAndFilters();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đã nhập $count thẻ.')));
      } else {
        // Xuất toàn bộ bộ thẻ, kể cả khi danh sách đang tìm kiếm hoặc lọc.
        final cards = List<Flashcard>.of(_cards(controller));
        if (cards.isEmpty) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Xuất CSV'),
            content: Text(
              'Xuất toàn bộ ${cards.length} thẻ, gồm nội dung Việt–Anh, '
              'khối kiến thức và mức độ. Lịch ôn không được xuất.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Chọn nơi lưu'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        setState(() => _csvProcessing = true);
        final bytes = await compute(CsvService.exportBytes, cards);
        if (!mounted) return;
        final date = DateTime.now().toIso8601String().substring(0, 10);
        final saved = await _csvFiles.save(
          bytes,
          suggestedName: 'flashcards_$date.csv',
        );
        if (!mounted || saved == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất ${cards.length} thẻ ra file CSV.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is CsvFileException
                ? error.message
                : action == _CsvAction.import
                ? 'Không thể đọc file CSV. Vui lòng chọn lại file.'
                : 'Không thể lưu file CSV. Vui lòng thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _csvBusy = false;
          _csvProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    final isEnglish = controller.isEnglish;
    final strings = AppStrings(isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.deckId == null
              ? (isEnglish ? 'Decks' : 'Bộ thẻ')
              : strings.deckName(
            controller.deckById(widget.deckId!)?.name ??
                (isEnglish ? 'Deck no longer exists' : 'Bộ thẻ không còn tồn tại'),
          ),
        ),
        actions: [
          if (widget.deckId != null &&
              controller.deckById(widget.deckId!) != null)
            IconButton(
              key: const ValueKey('manage_study_this_deck'),
              tooltip: strings.studyThisDeck,
              icon: const Icon(Icons.school_outlined),
              onPressed: controller.isSaving || controller.isLoading || _csvBusy
                  ? null
                  : () {
                      if (widget.onStudyDeck != null) {
                        widget.onStudyDeck!(widget.deckId!);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudyScreen(deckId: widget.deckId!),
                          ),
                        );
                      }
                    },
            ),
          if (!controller.isLoading &&
              controller.loadError == null &&
              (widget.deckId == null ||
                  controller.deckById(widget.deckId!) != null))
            IconButton(
              key: const ValueKey('manage_add_card'),
              tooltip: isEnglish ? 'Add card' : 'Thêm thẻ',
              onPressed: controller.isSaving || _csvBusy
                  ? null
                  : () => _openEditor(),
              icon: const Icon(Icons.add),
            ),
          if (!controller.isLoading &&
              controller.loadError == null &&
              (widget.deckId == null ||
                  controller.deckById(widget.deckId!) != null))
            PopupMenuButton<_CsvAction>(
              key: const ValueKey('manage_csv_menu'),
              tooltip: isEnglish ? 'Import / export CSV' : 'Nhập / xuất CSV',
              enabled: !_csvBusy && !controller.isSaving,
              icon: const Icon(Icons.import_export),
              onSelected: _handleCsv,
              itemBuilder: (_) => [
                if (widget.deckId != null)
                  PopupMenuItem(
                    value: _CsvAction.demoAi,
                    child: Text(
                      ManageAiStrings(controller.isEnglish).text('Tạo thẻ AI'),
                    ),
                  ),
                PopupMenuItem(
                  value: _CsvAction.import,
                  child: Text(isEnglish ? 'Import CSV' : 'Nhập CSV'),
                ),
                PopupMenuItem(
                  value: _CsvAction.export,
                  enabled: _cards(controller).isNotEmpty,
                  child: Text(isEnglish ? 'Export CSV' : 'Xuất CSV'),
                ),
              ],
            ),
          if (_csvProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Đang xử lý CSV',
                ),
              ),
            ),
        ],
      ),
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
        onAction: () => controller.loadDefaultCards(forceReload: true),
      );
    }

    if (widget.deckId != null && controller.deckById(widget.deckId!) == null) {
      return const Center(
        child: Text('Bộ thẻ đã được xóa. Hãy quay lại danh sách bộ.'),
      );
    }
    final cards = _cards(controller);
    if (cards.isEmpty) {
      return _ManageCardsMessage(
        icon: Icons.style_outlined,
        title: 'Chưa có thẻ nào',
        message: 'Thêm thẻ mới để bắt đầu xây dựng bộ thẻ của bạn.',
        actionLabel: 'Thêm thẻ mới',
        onAction: controller.isSaving || _csvBusy ? () {} : () => _openEditor(),
      );
    }

    final results = ManageCardSearch.search(_filter.apply(cards), _query);
    final recentIndex = results.indexWhere((card) => card.id == _recentCardId);
    if (recentIndex > 0) results.insert(0, results.removeAt(recentIndex));
    final isSearching = _query.trim().isNotEmpty;
    final hasCriteria = isSearching || _filter.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.search,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              labelText: controller.isEnglish ? 'Search cards' : 'Tìm kiếm thẻ',
              hintText: controller.isEnglish
                  ? 'Question, answer, topic or card ID'
                  : 'Câu hỏi, đáp án, chủ đề hoặc mã thẻ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: controller.isEnglish ? 'Clear search' : 'Xóa từ khóa',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    hasCriteria
                        ? (controller.isEnglish
                            ? '${results.length} / ${cards.length} cards'
                            : '${results.length} / ${cards.length} thẻ')
                        : (controller.isEnglish
                            ? '${cards.length} cards'
                            : '${cards.length} thẻ'),
                    style: AppTextStyles.subHeading,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      _filter.isActive
                          ? (controller.isEnglish
                              ? 'Filter (${_filter.activeCount})'
                              : 'Bộ lọc (${_filter.activeCount})')
                          : (controller.isEnglish ? 'Filter' : 'Bộ lọc'),
                    ),
                  ),
                ],
              ),
              if (_filter.isActive) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    _filter.topicCode,
                    _filter.level,
                  ].whereType<String>().join(' • '),
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                controller.isEnglish
                    ? 'Tap card to view answer and explanation.'
                    : 'Chạm vào thẻ để xem đáp án và giải thích.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _ManageCardsMessage(
                  icon: Icons.search_off,
                  title: 'Không tìm thấy thẻ',
                  message: 'Thử đổi điều kiện hoặc xóa điều kiện để xem toàn bộ thẻ.',
                  actionLabel: _filter.isActive
                      ? (isSearching ? 'Xóa tìm kiếm và bộ lọc' : 'Xóa bộ lọc')
                      : 'Xóa tìm kiếm',
                  onAction: _resetSearchAndFilters,
                )
              : ListView.builder(
                  key: const PageStorageKey('manage_cards_list'),
                  controller: _listController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) => _ManageCardItem(
                    key: ValueKey(results[index].id),
                    card: results[index],
                    isEnglish: controller.isEnglish,
                    highlighted: results[index].id == _recentCardId,
                    onEdit: controller.isSaving || _csvBusy
                        ? null
                        : () => _openEditor(results[index]),
                    onMove:
                        widget.deckId != null &&
                            !controller.isSaving &&
                            !_csvBusy &&
                            controller.decks.length > 1
                        ? () => _moveCard(results[index])
                        : null,
                    onDelete: controller.isSaving || _csvBusy
                        ? null
                        : () => _deleteCard(results[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ManageCardItem extends StatelessWidget {
  const _ManageCardItem({
    super.key,
    required this.card,
    required this.isEnglish,
    required this.onEdit,
    required this.onDelete,
    this.highlighted = false,
    this.onMove,
  });

  final Flashcard card;
  final bool isEnglish;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool highlighted;
  final VoidCallback? onMove;

  String _textForLanguage(String vietnamese, String? english) {
    return isEnglish && english != null && english.trim().isNotEmpty
        ? english
        : vietnamese;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                width: 2,
              ),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('manage_card_${card.id}'),
        tilePadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: CodeTextView(
          key: PageStorageKey(
            'manage_front_${card.id}_${isEnglish ? 'en' : 'vi'}',
          ),
          text: _textForLanguage(card.front, card.frontEn),
          baseStyle: AppTextStyles.body,
          textAlign: TextAlign.left,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [
              card.topicCode,
              AppStrings(isEnglish).levelLabel(card.level),
            ].where((value) => value.isNotEmpty).join(' • '),
            style: AppTextStyles.caption,
          ),
        ),
        children: [
          const Divider(color: AppColors.border),
          Text(
            isEnglish ? 'Answer & explanation' : 'Đáp án & giải thích',
            style: AppTextStyles.subHeading,
          ),
          const SizedBox(height: 8),
          SelectionArea(
            child: CodeTextView(
              key: PageStorageKey(
                'manage_answer_${card.id}_${isEnglish ? 'en' : 'vi'}',
              ),
              text: _textForLanguage(card.back, card.backEn),
              baseStyle: AppTextStyles.body,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (onMove != null)
                TextButton.icon(
                  onPressed: onMove,
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: Text(isEnglish ? 'Move deck' : 'Chuyển bộ'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(isEnglish ? 'Edit card' : 'Sửa thẻ'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(isEnglish ? 'Delete card' : 'Xóa thẻ'),
              ),
            ],
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
