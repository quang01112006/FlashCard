import 'package:flutter/material.dart';

import '../services/manage_card_filter.dart';

/// Giữ mã K01–K20 cũ, cho nhập trực tiếp tên/mã chủ đề mới.
class ManageTopicField extends StatelessWidget {
  const ManageTopicField({
    super.key,
    required this.value,
    required this.onChanged,
    this.topics = const [],
    this.enabled = true,
    this.label = 'Chủ đề',
  });
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> topics;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: value),
    optionsBuilder: (input) =>
        {...ManageCardFilter.topicCodes, ...topics, value}.where(
          (topic) =>
              topic.isNotEmpty &&
              topic.toLowerCase().contains(input.text.toLowerCase()),
        ),
    onSelected: onChanged,
    fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
      controller: controller,
      focusNode: focus,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Chọn gợi ý hoặc nhập tên chủ đề mới.',
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) => onChanged(text.trim()),
      validator: (text) =>
          text == null || text.trim().isEmpty ? 'Vui lòng nhập chủ đề.' : null,
    ),
  );
}
