import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'manage_select_field.dart';
import '../controllers/card_controller.dart';
import '../l10n/app_strings.dart';

import '../services/manage_card_filter.dart';

class ManageCardFiltersSheet extends StatefulWidget {
  const ManageCardFiltersSheet({
    super.key,
    required this.initialFilter,
    this.topics = const [],
    this.includeFlutterTopics = true,
  });
  final List<String> topics;
  final bool includeFlutterTopics;

  final ManageCardFilter initialFilter;

  @override
  State<ManageCardFiltersSheet> createState() => _ManageCardFiltersSheetState();
}

class _ManageCardFiltersSheetState extends State<ManageCardFiltersSheet> {
  late String? _topicCode = widget.initialFilter.topicCode;
  late String? _level = widget.initialFilter.level;

  @override
  Widget build(BuildContext context) => _buildScreen(context);

  Widget _buildScreen(BuildContext context) {
    final isEnglish = context.watch<CardController>().isEnglish;
    final strings = AppStrings(isEnglish);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEnglish ? 'Filter cards' : 'Lọc bộ thẻ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _buildDropdown(
              fieldKey: 'manage_filter_topic',
              label: isEnglish ? 'Topic' : 'Chủ đề',
              allLabel: isEnglish ? 'All topics' : 'Tất cả chủ đề',
              selected: _topicCode,
              options: {
                if (widget.includeFlutterTopics) ...ManageCardFilter.topicCodes,
                ...widget.topics,
                ?_topicCode,
              }.toList()..sort(),
              onChanged: (value) => setState(() => _topicCode = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              fieldKey: 'manage_filter_level',
              label: isEnglish ? 'Level' : 'Mức độ',
              allLabel: isEnglish ? 'All levels' : 'Tất cả mức độ',
              selected: _level,
              options: ManageCardFilter.levels,
              displayLabel: (opt) => strings.levelLabel(opt),
              onChanged: (value) => setState(() => _level = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .pop(ManageCardFilter(topicCode: _topicCode, level: _level)),
              child: Text(isEnglish ? 'Apply' : 'Áp dụng'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() {
                _topicCode = null;
                _level = null;
              }),
              child: Text(isEnglish ? 'Reset' : 'Đặt lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String fieldKey,
    required String label,
    required String allLabel,
    required String? selected,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayLabel,
  }) {
    return ManageSelectField<String>(
      isEnglish: context.read<CardController>().isEnglish,
      key: ValueKey(fieldKey),
      initialValue: selected ?? '',
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(displayLabel?.call(option) ?? option),
          ),
      ],
      onChanged: (value) => onChanged(value == '' ? null : value),
    );
  }
}
