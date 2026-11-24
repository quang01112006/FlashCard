import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../services/csv_service.dart';
import '../services/manage_csv_strings.dart';
import '../widgets/manage_select_field.dart';
import 'manage_csv_import_screen.dart';

class ManageCsvMappingScreen extends StatefulWidget {
  const ManageCsvMappingScreen({
    super.key,
    required this.fileName,
    required this.table,
    this.topicCode,
    this.level,
    this.deckId,
    this.isEnglish = false,
  });

  final String fileName;
  final CsvTable table;
  final String? topicCode;
  final String? level;
  final String? deckId;
  final bool isEnglish;

  @override
  State<ManageCsvMappingScreen> createState() => _ManageCsvMappingScreenState();
}

class _ManageCsvMappingScreenState extends State<ManageCsvMappingScreen> {
  late bool _header = widget.table.suggestedHeader;
  late Map<String, int> _mapping = widget.table.suggest(_header);
  bool _busy = false;
  String? _error;

  static const _fieldKeys = [
    'front',
    'back',
    'topicCode',
    'level',
    'front_en',
    'back_en',
  ];

  bool get _isEnglish =>
      widget.isEnglish ||
      (mounted ? (context.read<CardController?>()?.isEnglish ?? false) : false);

  Future<void> _next() async {
    if (_busy) return;
    final csvStrings = ManageCsvStrings(_isEnglish);
    if (widget.table.columnCount > 0 &&
        (!_mapping.containsKey('front') ||
            !_mapping.containsKey('back') ||
            _mapping.values.toSet().length != _mapping.length)) {
      setState(
        () => _error = csvStrings.mappingRequiredError,
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
            isEnglish: _isEnglish,
          ),
        ),
      );
      if (!mounted) return;
      if (count != null) Navigator.pop(context, count);
    } catch (error) {
      if (mounted) {
        final csvStrings = ManageCsvStrings(_isEnglish);
        setState(
          () => _error = error is CsvFileException
              ? csvStrings.csvError(error.message)
              : csvStrings.readColumnsError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) {
    final isEnglish =
        context.watch<CardController?>()?.isEnglish ?? widget.isEnglish;
    final csvStrings = ManageCsvStrings(isEnglish);

    return PopScope<int>(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(csvStrings.mappingTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.fileName),
              CheckboxListTile(
                key: const ValueKey('manage_csv_has_header'),
                contentPadding: EdgeInsets.zero,
                title: Text(csvStrings.hasHeader),
                value: _header,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _header = value!;
                        _mapping = widget.table.suggest(_header);
                        _error = null;
                      }),
              ),
              Text(csvStrings.mappingHelp),
              const SizedBox(height: 16),
              for (final fieldKey in _fieldKeys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ManageSelectField<int>(
                    key: ValueKey('manage_csv_map_$fieldKey'),
                    initialValue: _mapping[fieldKey] ?? -1,
                    decoration: InputDecoration(
                      labelText:
                          '${csvStrings.fieldLabel(fieldKey)}${fieldKey == 'front' || fieldKey == 'back' ? ' *' : ''}',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: -1,
                        child: Text(csvStrings.noChoice),
                      ),
                      for (
                        var index = 0;
                        index < widget.table.columnCount;
                        index++
                      )
                        DropdownMenuItem(
                          value: index,
                          child: Text(
                            csvStrings.columnLabel(
                              index,
                              _header ? widget.table.sample.first[index] : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            if (value == -1) {
                              _mapping.remove(fieldKey);
                            } else {
                              _mapping[fieldKey] = value!;
                            }
                            _error = null;
                          }),
                  ),
                ),
              Text(csvStrings.sampleDataTitle),
              for (final row in widget.table.sample.skip(_header ? 1 : 0))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < row.length; index++)
                          Text(
                            csvStrings.sampleColumnLabel(index, row[index]),
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
                  child: Text(
                    _busy ? csvStrings.reading : csvStrings.previewCards,
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

CsvImportResult _parseSelection((String, bool, Map<String, int>) request) =>
    CsvService.parse(request.$1, hasHeader: request.$2, mapping: request.$3);
