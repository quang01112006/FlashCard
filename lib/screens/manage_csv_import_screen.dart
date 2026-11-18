import 'package:flutter/material.dart';

import '../widgets/manage_select_field.dart';

import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../services/csv_service.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_store.dart';
import '../widgets/code_text_view.dart';
import '../widgets/manage_topic_field.dart';
import '../models/flashcard.dart';
import 'manage_card_editor_screen.dart';

class ManageCsvImportScreen extends StatefulWidget {
  const ManageCsvImportScreen({
    super.key,
    required this.fileName,
    required this.result,
    this.topicCode,
    this.level,
    this.deckId,
  });

  final String fileName;
  final CsvImportResult result;
  final String? topicCode;
  final String? level;
  final String? deckId;

  @override
  State<ManageCsvImportScreen> createState() => _ManageCsvImportScreenState();
}

class _ManageCsvImportScreenState extends State<ManageCsvImportScreen> {
  static final _codeBlocks = RegExp(r'```[\s\S]*?```');
  static final _inlineCode = RegExp(r'`([^`]+)`');
  static final _whitespace = RegExp(r'\s+');
  late String _topic =
      widget.topicCode ??
      (widget.deckId == null || widget.deckId == 'flutter-default'
          ? 'K01'
          : '');
  late String _level = widget.level ?? 'Nhớ';
  late final List<CsvCardDraft> _drafts = List.of(widget.result.cards);
  bool _saving = false;
  bool _allowPop = false;
  String? _error;

  Future<void> _import() async {
    final controller = context.read<CardController>();
    if (_saving || controller.isSaving || _drafts.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cards = _drafts
          .map(
            (draft) => draft
                .toCard(
                  id: controller.createCardId(),
                  defaultTopic: _topic,
                  defaultLevel: _level,
                )
                .copyWith(deckId: widget.deckId ?? 'flutter-default'),
          )
          .toList();
      await controller.importCards(cards);
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(cards.length);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is CardOperationException
            ? error.message
            : 'Không thể nhập thẻ. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _editDraft(int index) async {
    final original = _drafts[index];
    final draft = await Navigator.push<Flashcard>(
      context,
      MaterialPageRoute(
        builder: (_) => ManageCardEditorScreen(
          draftOnly: true,
          deckId: widget.deckId,
          initialCard: original.toCard(
            id: 'preview-$index',
            defaultTopic: _topic,
            defaultLevel: _level,
          ),
        ),
      ),
    );
    if (!mounted || draft == null) return;
    setState(() {
      _drafts[index] = CsvCardDraft(
        line: original.line,
        front: draft.front,
        back: draft.back,
        topicCode: draft.topicCode,
        level: draft.level,
        frontEn: draft.frontEn,
        backEn: draft.backEn,
      );
    });
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) {
    final result = CsvImportResult(
      cards: _drafts,
      errors: widget.result.errors,
      blankRows: widget.result.blankRows,
    );
    final controller = context.watch<CardController>();
    final busy = _saving || controller.isSaving;
    return PopScope<int>(
      canPop: _allowPop || !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Xem trước CSV')),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.fileName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text('${result.cards.length} thẻ hợp lệ'),
                          ),
                          Chip(label: Text('${result.errors.length} dòng lỗi')),
                          if (result.blankRows > 0)
                            Chip(label: Text('${result.blankRows} dòng trống')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chỉ các thẻ hợp lệ được thêm vào bộ hiện có, với tiến độ ôn mới. '
                        'Nhập lại cùng file sẽ tạo thêm bản sao.',
                      ),
                      if (result.needsTopic || result.needsLevel) ...[
                        const SizedBox(height: 16),
                        const Text('Bổ sung cho các ô còn thiếu trong file:'),
                        const SizedBox(height: 12),
                        if (result.needsTopic)
                          ManageTopicField(
                            key: const ValueKey('manage_csv_topic'),
                            value: _topic,
                            topics: widget.deckId == null
                                ? context.read<CardController>().allTopics
                                : context.read<CardController>().topicsInDeck(
                                    widget.deckId!,
                                  ),
                            required: false,
                            includeFlutterTopics:
                                widget.deckId == null ||
                                widget.deckId == 'flutter-default',
                            enabled: !busy,
                            label: 'Chủ đề mặc định',
                            onChanged: (value) =>
                                setState(() => _topic = value),
                          ),

                        if (result.needsTopic && result.needsLevel)
                          const SizedBox(height: 16),
                        if (result.needsLevel)
                          ManageSelectField<String>(
                            key: const ValueKey('manage_csv_level'),
                            initialValue: _level,
                            decoration: const InputDecoration(
                              labelText: 'Mức độ mặc định',
                              border: OutlineInputBorder(),
                            ),
                            items: ManageCardFilter.levels
                                .map(
                                  (level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level),
                                  ),
                                )
                                .toList(),
                            onChanged: busy
                                ? null
                                : (value) => setState(() => _level = value!),
                          ),
                      ],
                      if (result.cards.isEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Không có thẻ hợp lệ để nhập. Hãy kiểm tra file rồi chọn lại.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (result.errors.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Các dòng không được nhập',
                      style: AppTextStyles.subHeading,
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: result.errors.length,
                  itemBuilder: (context, index) {
                    final error = result.errors[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                      ),
                      title: Text('Dòng ${error.line}'),
                      subtitle: Text(error.message),
                    );
                  },
                ),
              ],
              if (result.cards.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Thẻ sẽ được nhập',
                      style: AppTextStyles.subHeading,
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: result.cards.length,
                  itemBuilder: (context, index) {
                    final card = result.cards[index];
                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ExpansionTile(
                        key: PageStorageKey('manage_csv_preview_$index'),
                        title: Text(
                          card.front
                              .replaceAll(_codeBlocks, '[Đoạn mã]')
                              .replaceAllMapped(
                                _inlineCode,
                                (match) => match.group(1)!,
                              )
                              .replaceAll(_whitespace, ' ')
                              .trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Dòng ${card.line} • ${card.topicCode ?? _topic} • ${card.level ?? _level}',
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          OutlinedButton.icon(
                            key: ValueKey('manage_csv_edit_$index'),
                            onPressed: busy ? null : () => _editDraft(index),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh thẻ trước khi nhập'),
                          ),
                          const Text(
                            'Câu hỏi',
                            style: AppTextStyles.subHeading,
                          ),
                          CodeTextView(
                            key: PageStorageKey('manage_csv_front_$index'),
                            text: card.front,
                          ),
                          const SizedBox(height: 8),
                          const Text('Đáp án', style: AppTextStyles.subHeading),
                          CodeTextView(
                            key: PageStorageKey('manage_csv_back_$index'),
                            text: card.back,
                          ),
                          if (card.frontEn != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Câu hỏi tiếng Anh',
                              style: AppTextStyles.subHeading,
                            ),
                            CodeTextView(
                              key: PageStorageKey('manage_csv_front_en_$index'),
                              text: card.frontEn!,
                            ),
                          ],
                          if (card.backEn != null) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Đáp án tiếng Anh',
                              style: AppTextStyles.subHeading,
                            ),
                            CodeTextView(
                              key: PageStorageKey('manage_csv_back_en_$index'),
                              text: card.backEn!,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('manage_csv_confirm_import'),
                    onPressed: busy || result.cards.isEmpty ? null : _import,
                    child: Text(
                      _saving
                          ? 'Đang nhập...'
                          : 'Nhập ${result.cards.length} thẻ hợp lệ',
                    ),
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
