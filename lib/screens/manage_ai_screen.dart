import 'package:flutter/material.dart';

import '../widgets/manage_select_field.dart';

import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../models/flashcard.dart';
import '../services/ai_card_service.dart';
import '../services/manage_ai_strings.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_store.dart';
import '../widgets/code_text_view.dart';
import 'manage_card_editor_screen.dart';

class ManageAiScreen extends StatefulWidget {
  const ManageAiScreen({
    super.key,
    required this.deckId,
    this.service = const WorkerAiCardService(),
  });
  final String deckId;
  final AiCardService service;
  @override
  State<ManageAiScreen> createState() => _ManageAiScreenState();
}

class _ManageAiScreenState extends State<ManageAiScreen> {
  ManageAiStrings get _strings =>
      ManageAiStrings(context.read<CardController>().isEnglish);

  final _form = GlobalKey<FormState>();
  final _topic = TextEditingController();
  int _count = 5;
  String _level = 'Nhớ';
  bool _bilingual = false;
  bool _generating = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirming = false;
  String? _error;
  List<AiCardDraft>? _drafts;
  final Set<int> _selected = {};

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generating || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final results = await widget.service.generate(
        AiCardRequest(
          topic: _topic.text,
          count: _count,
          level: _level,
          bilingual: _bilingual,
        ),
      );
      if (!mounted) return;
      if (results.isEmpty ||
          results.length > 10 ||
          results.any((item) => !item.isValid)) {
        throw const FormatException('Dữ liệu nháp không hợp lệ.');
      }
      setState(() {
        _drafts = List.of(results);
        _selected
          ..clear()
          ..addAll(List.generate(results.length, (i) => i));
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiCardException
              ? error.message
              : 'Không thể tạo bản nháp. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _edit(int index) async {
    final draft = _drafts![index];
    final edited = await Navigator.push<Flashcard>(
      context,
      MaterialPageRoute(
        builder: (_) => ManageCardEditorScreen(
          draftOnly: true,
          deckId: widget.deckId,
          initialCard: draft.toCard(
            id: 'ai-preview-$index',
            deckId: widget.deckId,
          ),
        ),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _drafts![index] = AiCardDraft.fromCard(edited));
  }

  Future<void> _save() async {
    final controller = context.read<CardController>();
    if (_saving ||
        controller.isSaving ||
        _drafts == null ||
        _selected.isEmpty) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cards = [
        for (var i = 0; i < _drafts!.length; i++)
          if (_selected.contains(i))
            _drafts![i].toCard(
              id: controller.createCardId(),
              deckId: widget.deckId,
            ),
      ];
      await controller.importCards(cards);
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, cards.length);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is CardOperationException
              ? error.message
              : 'Không thể lưu thẻ. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _leave({bool reset = false}) async {
    if (_generating || _saving || _confirming) return;
    if (_drafts == null) {
      Navigator.pop(context);
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_strings.text('Bỏ bản nháp?')),
        content: Text(_strings.text('Các thẻ chưa lưu sẽ bị bỏ.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_strings.text('Tiếp tục xem')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_strings.text('Bỏ bản nháp')),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || discard != true) return;
    if (reset) {
      setState(() {
        _drafts = null;
        _selected.clear();
        _error = null;
      });
    } else {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) {
    final controller = context.watch<CardController>();
    final deck = controller.deckById(widget.deckId);
    final busy = _generating || _saving || controller.isSaving;
    return PopScope<int>(
      canPop: _allowPop || (!_generating && !_saving && _drafts == null),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _drafts == null
                ? _strings.text('Tạo thẻ AI')
                : _strings.text('Xem trước thẻ'),
          ),
          leading: BackButton(onPressed: busy ? null : _leave),
        ),
        body: SafeArea(
          child: _drafts == null
              ? _buildForm(
                  deck?.name ?? _strings.text('Bộ thẻ không còn tồn tại'),
                  busy,
                )
              : _buildPreview(busy),
        ),
        bottomNavigationBar: _drafts == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _strings.error(_error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ElevatedButton(
                        key: const ValueKey('manage_ai_save'),
                        onPressed: busy || _selected.isEmpty || deck == null
                            ? null
                            : _save,
                        child: Text(
                          _saving
                              ? _strings.text('Đang lưu...')
                              : _strings.save(_selected.length),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm(String deckName, bool busy) => Form(
    key: _form,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _strings.deck(deckName),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _strings.text(
              'Nội dung có thể chưa chính xác. Hãy kiểm tra và chỉnh sửa trước khi dùng để học.',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('manage_ai_topic'),
            controller: _topic,
            enabled: !busy,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: _strings.text('Chủ đề hoặc kiến thức'),
              hintText: _strings.text('Ví dụ: các kỹ thuật luộc trứng'),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? _strings.text('Vui lòng nhập chủ đề hoặc kiến thức.')
                : null,
          ),
          const SizedBox(height: 12),
          ManageSelectField<int>(
            isEnglish: _strings.isEnglish,
            key: const ValueKey('manage_ai_count'),
            initialValue: _count,
            decoration: InputDecoration(
              labelText: _strings.text('Số thẻ'),
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 1; i <= 10; i++)
                DropdownMenuItem(value: i, child: Text(_strings.count(i))),
            ],
            onChanged: busy ? null : (value) => setState(() => _count = value!),
          ),
          const SizedBox(height: 16),
          ManageSelectField<String>(
            isEnglish: _strings.isEnglish,
            key: const ValueKey('manage_ai_level'),
            initialValue: _level,
            decoration: InputDecoration(
              labelText: _strings.text('Mức độ'),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final level in ManageCardFilter.levels)
                DropdownMenuItem(
                  value: level,
                  child: Text(_strings.text(level)),
                ),
            ],
            onChanged: busy ? null : (value) => setState(() => _level = value!),
          ),
          SwitchListTile(
            key: const ValueKey('manage_ai_bilingual'),
            contentPadding: EdgeInsets.zero,
            title: Text(_strings.text('Tạo thêm bản tiếng Anh')),
            value: _bilingual,
            onChanged: busy
                ? null
                : (value) => setState(() => _bilingual = value),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _strings.error(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ElevatedButton(
            key: const ValueKey('manage_ai_generate'),
            onPressed:
                busy ||
                    context.read<CardController>().deckById(widget.deckId) ==
                        null
                ? null
                : _generate,
            child: Text(
              _generating
                  ? _strings.text('Đang tạo...')
                  : _strings.text('Tạo bản nháp'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPreview(bool busy) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _strings.deck(
                  context
                          .watch<CardController>()
                          .deckById(widget.deckId)
                          ?.name ??
                      _strings.text('Bộ thẻ không còn tồn tại'),
                ),
              ),
              Text(
                _strings.text(
                  'Hãy kiểm tra và chỉnh sửa nội dung AI trước khi lưu.',
                ),
              ),
              Text(_strings.selected(_selected.length, _drafts!.length)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy ? null : () => _leave(reset: true),
                  child: Text(_strings.text('Đổi yêu cầu')),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: _drafts!.length,
        itemBuilder: (context, index) {
          final draft = _drafts![index];
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ExpansionTile(
              key: PageStorageKey('manage_ai_draft_$index'),
              leading: Checkbox(
                key: ValueKey('manage_ai_select_$index'),
                value: _selected.contains(index),
                onChanged: busy
                    ? null
                    : (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(index);
                        } else {
                          _selected.remove(index);
                        }
                      }),
              ),
              title: Text(
                draft.front,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_strings.text(draft.level)),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              childrenPadding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  key: ValueKey('manage_ai_edit_$index'),
                  onPressed: busy ? null : () => _edit(index),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_strings.text('Chỉnh thẻ')),
                ),
                Text(_strings.text('Câu hỏi')),
                CodeTextView(
                  key: PageStorageKey('manage_ai_front_$index'),
                  text: draft.front,
                ),
                const SizedBox(height: 8),
                Text(_strings.text('Đáp án')),
                CodeTextView(
                  key: PageStorageKey('manage_ai_back_$index'),
                  text: draft.back,
                ),
                if (draft.frontEn != null) ...[
                  const SizedBox(height: 8),
                  Text(_strings.text('Câu hỏi tiếng Anh')),
                  CodeTextView(
                    key: PageStorageKey('manage_ai_front_en_$index'),
                    text: draft.frontEn!,
                  ),
                ],
                if (draft.backEn != null) ...[
                  const SizedBox(height: 8),
                  Text(_strings.text('Đáp án tiếng Anh')),
                  CodeTextView(
                    key: PageStorageKey('manage_ai_back_en_$index'),
                    text: draft.backEn!,
                  ),
                ],
              ],
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ],
  );
}
