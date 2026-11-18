import 'package:flutter/material.dart';

import '../widgets/manage_select_field.dart';

import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../models/flashcard.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_ai_strings.dart';
import '../services/manage_card_store.dart';
import '../widgets/manage_topic_field.dart';

class ManageCardEditorScreen extends StatefulWidget {
  const ManageCardEditorScreen({
    super.key,
    this.initialCard,
    this.topicCode,
    this.level,
    this.draftOnly = false,
    this.deckId,
  });

  final Flashcard? initialCard;
  final String? topicCode;
  final String? level;
  final bool draftOnly;
  final String? deckId;

  @override
  State<ManageCardEditorScreen> createState() => _ManageCardEditorScreenState();
}

class _ManageCardEditorScreenState extends State<ManageCardEditorScreen> {
  ManageAiStrings get _strings =>
      ManageAiStrings(context.read<CardController>().isEnglish);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _frontEn;
  late final TextEditingController _backEn;
  late String _topicCode;
  late String _level;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    _front = TextEditingController(text: card?.front ?? '');
    _back = TextEditingController(text: card?.back ?? '');
    _frontEn = TextEditingController(text: card?.frontEn ?? '');
    _backEn = TextEditingController(text: card?.backEn ?? '');
    _topicCode =
        card?.topicCode ??
        widget.topicCode ??
        (widget.deckId == null || widget.deckId == 'flutter-default'
            ? 'K01'
            : '');
    _level = card?.level ?? widget.level ?? 'Nhớ';
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _frontEn.dispose();
    _backEn.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _requestLeave() async {
    if (_saving || _confirming) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_strings.text('Bỏ thay đổi?')),
        content: Text(_strings.text('Nội dung bạn vừa nhập chưa được lưu.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_strings.text('Tiếp tục nhập')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_strings.text('Bỏ thay đổi')),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || discard != true) return;
    _allowPop = true;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = context.read<CardController>();
      final initial = widget.initialCard;
      final draft = Flashcard(
        id: initial?.id ?? controller.createCardId(),
        deckId: initial?.deckId ?? widget.deckId ?? 'flutter-default',
        topicCode: _topicCode,
        level: _level,
        front: _front.text,
        back: _back.text,
        frontEn: _frontEn.text.trim().isEmpty ? null : _frontEn.text,
        backEn: _backEn.text.trim().isEmpty ? null : _backEn.text,
      );
      if (widget.draftOnly) {
        _allowPop = true;
        Navigator.of(context).pop(draft);
        return;
      }
      final saved = initial == null
          ? await controller.addCard(draft)
          : await controller.editCard(draft, expectedDeckId: widget.deckId);
      if (!mounted) return;
      _allowPop = true;
      Navigator.of(context).pop(saved.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is CardOperationException
            ? error.message
            : 'Không thể lưu thẻ. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) {
    context.watch<CardController>();
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialCard == null
                ? _strings.text('Thêm thẻ')
                : _strings.text('Sửa thẻ'),
          ),
          leading: BackButton(onPressed: _saving ? null : _requestLeave),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _contentField(
                          'manage_editor_front',
                          _strings.text('Câu hỏi'),
                          _front,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        _contentField(
                          'manage_editor_back',
                          _strings.text('Đáp án & giải thích'),
                          _back,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        ManageTopicField(
                          key: const ValueKey('manage_editor_topic'),
                          value: _topicCode,
                          topics: widget.deckId == null
                              ? context.read<CardController>().allTopics
                              : context.read<CardController>().topicsInDeck(
                                  widget.deckId!,
                                ),
                          required: false,
                          includeFlutterTopics:
                              widget.deckId == null ||
                              widget.deckId == 'flutter-default',
                          label: _strings.text('Nhóm trong bộ (tùy chọn)'),
                          helperText: _strings.text(
                            'Chọn gợi ý hoặc nhập tên chủ đề mới.',
                          ),
                          enabled: !_saving,
                          onChanged: (value) {
                            _topicCode = value;
                            _markDirty();
                          },
                        ),
                        const SizedBox(height: 16),
                        _choiceField(
                          'manage_editor_level',
                          _strings.text('Mức độ'),
                          _level,
                          ManageCardFilter.levels,
                          (value) => _level = value,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _strings.text('Tiếng Anh (tùy chọn)'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _contentField(
                          'manage_editor_front_en',
                          _strings.text('Câu hỏi tiếng Anh'),
                          _frontEn,
                        ),
                        const SizedBox(height: 16),
                        _contentField(
                          'manage_editor_back_en',
                          _strings.text('Đáp án tiếng Anh'),
                          _backEn,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _strings.error(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? _strings.text('Đang lưu...')
                          : _strings.text('Lưu thẻ'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentField(
    String key,
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_saving,
      minLines: 3,
      maxLines: null,
      autocorrect: false,
      keyboardType: TextInputType.multiline,
      style: Theme.of(context).textTheme.bodyLarge,
      onChanged: (_) => _markDirty(),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? _strings.requiredField(label)
          : null,
    );
  }

  Widget _choiceField(
    String key,
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return ManageSelectField<String>(
      isEnglish: _strings.isEnglish,
      key: ValueKey(key),
      initialValue: value,
      items: [
        for (final option in {...options, value})
          DropdownMenuItem(value: option, child: Text(_strings.text(option))),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: _saving
          ? null
          : (selected) {
              if (selected != null) {
                onChanged(selected);
                _markDirty();
              }
            },
      validator: (selected) =>
          options.contains(selected) ? null : _strings.invalidChoice(label),
    );
  }
}
