import 'package:flutter/material.dart';

import '../widgets/manage_select_field.dart';

import 'package:flutter/foundation.dart';

import '../services/csv_service.dart';
import 'manage_csv_import_screen.dart';

class ManageCsvMappingScreen extends StatefulWidget {
  const ManageCsvMappingScreen({
    super.key,
    required this.fileName,
    required this.table,
    this.topicCode,
    this.level,
    this.deckId,
  });
  final String fileName;
  final CsvTable table;
  final String? topicCode;
  final String? level;
  final String? deckId;
  @override
  State<ManageCsvMappingScreen> createState() => _ManageCsvMappingScreenState();
}

class _ManageCsvMappingScreenState extends State<ManageCsvMappingScreen> {
  late bool _header = widget.table.suggestedHeader;
  late Map<String, int> _mapping = widget.table.suggest(_header);
  bool _busy = false;
  String? _error;
  static const labels = {
    'front': 'Câu hỏi',
    'back': 'Đáp án',
    'topicCode': 'Chủ đề',
    'level': 'Mức độ',
    'front_en': 'Câu hỏi tiếng Anh',
    'back_en': 'Đáp án tiếng Anh',
  };
  Future<void> _next() async {
    if (_busy) return;
    if (widget.table.columnCount > 0 &&
        (!_mapping.containsKey('front') ||
            !_mapping.containsKey('back') ||
            _mapping.values.toSet().length != _mapping.length)) {
      setState(
        () => _error =
            'Chọn đủ câu hỏi, đáp án; mỗi cột chỉ dùng cho một trường.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final source = widget.table.source;
      final header = _header;
      final mapping = Map<String, int>.of(_mapping);
      final result = await compute(_parseSelection, (source, header, mapping));
      if (!mounted) return;
      final count = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => ManageCsvImportScreen(
            fileName: widget.fileName,
            result: result,
            topicCode: widget.topicCode,
            level: widget.level,
            deckId: widget.deckId,
          ),
        ),
      );
      if (!mounted) return;
      if (count != null) Navigator.pop(context, count);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CsvFileException
              ? error.message
              : 'Không đọc được các cột đã chọn.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) => PopScope<int>(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Ghép cột CSV')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.fileName),
            CheckboxListTile(
              key: const ValueKey('manage_csv_has_header'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Dòng đầu là tiêu đề'),
              value: _header,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _header = value!;
                      _mapping = widget.table.suggest(_header);
                      _error = null;
                    }),
            ),
            const Text(
              'Kiểm tra các cột được nhận diện. Chỉ câu hỏi và đáp án là bắt buộc; cột không chọn sẽ được bỏ qua.',
            ),
            const SizedBox(height: 16),
            for (final field in labels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ManageSelectField<int>(
                  key: ValueKey('manage_csv_map_${field.key}'),
                  initialValue: _mapping[field.key] ?? -1,
                  decoration: InputDecoration(
                    labelText:
                        '${field.value}${field.key == 'front' || field.key == 'back' ? ' *' : ''}',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Không chọn'),
                    ),
                    for (
                      var index = 0;
                      index < widget.table.columnCount;
                      index++
                    )
                      DropdownMenuItem(
                        value: index,
                        child: Text(
                          'Cột ${index + 1}${_header ? ': ${widget.table.sample.first[index]}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          if (value == -1) {
                            _mapping.remove(field.key);
                          } else {
                            _mapping[field.key] = value!;
                          }
                          _error = null;
                        }),
                ),
              ),
            const Text('Dữ liệu mẫu (nội dung gốc):'),
            for (final row in widget.table.sample.skip(_header ? 1 : 0))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < row.length; index++)
                        Text(
                          'Cột ${index + 1}: ${row[index]}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
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
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ElevatedButton(
                key: const ValueKey('manage_csv_mapping_next'),
                onPressed: _busy ? null : _next,
                child: Text(_busy ? 'Đang đọc...' : 'Xem trước thẻ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

CsvImportResult _parseSelection((String, bool, Map<String, int>) request) =>
    CsvService.parse(request.$1, hasHeader: request.$2, mapping: request.$3);
