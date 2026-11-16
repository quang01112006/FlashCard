import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/manage_card_filter.dart';

class ManageCardFiltersSheet extends StatefulWidget {
  const ManageCardFiltersSheet({super.key, required this.initialFilter});

  final ManageCardFilter initialFilter;

  @override
  State<ManageCardFiltersSheet> createState() => _ManageCardFiltersSheetState();
}

class _ManageCardFiltersSheetState extends State<ManageCardFiltersSheet> {
  late String? _topicCode = widget.initialFilter.topicCode;
  late String? _level = widget.initialFilter.level;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Lọc bộ thẻ', style: AppTextStyles.heading),
            const SizedBox(height: 20),
            _buildDropdown(
              fieldKey: 'manage_filter_topic',
              label: 'Khối kiến thức',
              allLabel: 'Tất cả khối',
              selected: _topicCode,
              options: ManageCardFilter.topicCodes,
              onChanged: (value) => setState(() => _topicCode = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              fieldKey: 'manage_filter_level',
              label: 'Mức độ',
              allLabel: 'Tất cả mức độ',
              selected: _level,
              options: ManageCardFilter.levels,
              onChanged: (value) => setState(() => _level = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .pop(ManageCardFilter(topicCode: _topicCode, level: _level)),
              child: const Text('Áp dụng'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() {
                _topicCode = null;
                _level = null;
              }),
              child: const Text('Đặt lại'),
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
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey(fieldKey),
          value: selected ?? '',
          isExpanded: true,
          itemHeight: null,
          style: AppTextStyles.body,
          items: [
            DropdownMenuItem(value: '', child: Text(allLabel)),
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) => onChanged(value == '' ? null : value),
        ),
      ),
    );
  }
}
